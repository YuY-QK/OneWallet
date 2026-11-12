import 'package:drift/drift.dart';

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
final class OwDatabase extends _$OwDatabase {
  OwDatabase(super.executor);

  /// 当前表结构版本。每次改表都要提升版本、写迁移并加迁移测试。
  static const int currentSchemaVersion = 2;

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
    },
    beforeOpen: (details) async {
      // 外键默认关闭，必须每次打开连接时开启，级联删除才会生效（R6）。
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
