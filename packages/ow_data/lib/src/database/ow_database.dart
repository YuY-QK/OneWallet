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
final class OwDatabase extends _$OwDatabase implements DatabaseWiper {
  OwDatabase(super.executor);

  /// 清空所有表中的数据（P18 WipeAllData）。
  @override
  Future<void> wipe() async {
    await transaction(() async {
      await customStatement('PRAGMA foreign_keys = OFF');
      for (final table in allTables) {
        await delete(table).go();
      }
      await customStatement('PRAGMA foreign_keys = ON');
    });
  }

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
}
