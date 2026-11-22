import 'package:drift/drift.dart';
import 'package:ow_domain/ow_domain.dart';

import 'tables.dart';

part 'ow_database.g.dart';

/// OneWallet 的本地数据库。
///
/// 本类**不负责打开文件，也不处理加密**：连接由调用方传入。应用用 SQLCipher
/// 打开后注入，测试用 `NativeDatabase.memory()`。
@DriftDatabase(
  tables: [
    Accounts,
    Addresses,
    Holdings,
    Prices,
    Snapshots,
    SnapshotItems,
    VaultItemsMeta,
    SyncRecords,
    Settings,
    TokenVisibility,
    Assets,
    AssetContracts,
  ],
)
final class OwDatabase extends _$OwDatabase implements DatabaseCloser {
  OwDatabase(super.executor);

  /// 当前表结构版本。每次改表都要提升版本、写迁移并加迁移测试。
  static const int currentSchemaVersion = 3;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // 1 → 2（M1-18）：新增价格源币种两张表，accounts 加"最近成功同步时间"。
      if (from < 2) {
        await m.createTable(assets);
        await m.createTable(assetContracts);
        await m.addColumn(accounts, accounts.lastSyncedAt);
      }
      // 2 → 3（M1-15）：accounts 加 wallet_source_id 列，并按固定映射表回填已有数据。
      if (from < 3) {
        await m.addColumn(accounts, accounts.walletSourceId);
        await customStatement(
          "UPDATE accounts SET wallet_source_id = CASE wallet_source "
          "WHEN 'uniswap' THEN 'uniswap-wallet' "
          "WHEN 'metamask' THEN 'metamask' "
          "WHEN 'okxWeb3' THEN 'okx-web3-wallet' "
          "WHEN 'bitgetWallet' THEN 'bitget-wallet' "
          "WHEN 'trustWallet' THEN 'trust-wallet' "
          "ELSE NULL END "
          "WHERE wallet_source IS NOT NULL",
        );
      }
    },
    beforeOpen: (details) async {
      // 外键默认关闭，必须每次打开连接时开启，级联删除才会生效（R6）。
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  @override
  Future<void> close() async {
    // 【死锁根因与关闭设计说明】
    // Drift 原生 super.close() 会在调用 executor.close() 之前先 await streamQueries.close()。
    // 在 streamQueries.close() 内部，Drift 会循环等待所有 _pendingTimers（由流取消时 Timer.run
    // 延迟清理缓存生成）。
    // 在 Flutter 单测环境（testWidgets 的 FakeAsync）中，Timer.run 注册的是 FakeTimer；
    // 若在测试线程中 await closer.close()，由于事件循环被 await 挂起无法由 tester.pump() 推进，
    // FakeTimer 永远不会被触发完成，导致测试出现不可恢复的死锁（超时 10 分钟）。
    // 此外，WipeAllData 的核心需求是“关闭底层 SQLite/SQLCipher 物理连接并释放物理文件句柄”，
    // 以便紧接着安全删除 .db / -wal / -shm 物理文件。
    // 因此这里直接调用 await executor.close() 立即安全释放物理连接，跳过对未消费 FakeTimer 的死锁等待。
    await executor.close();
  }
}
