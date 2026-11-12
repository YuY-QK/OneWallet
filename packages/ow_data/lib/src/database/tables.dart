import 'package:drift/drift.dart';

// IMPLEMENTATION_SPEC 第 5 节的 10 张表。列名由 Drift 自动转为 snake_case。
// 金额、数量、价格一律是文本列（与 Decimal 往返），时间一律 UTC，
// 枚举存名称字符串；这些约定的编解码集中在 `mapping/` 下。

/// 账户。
@DataClassName('AccountRow')
class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  TextColumn get name => text()();
  IntColumn get colorIndex => integer()();
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get walletSource => text().nullable()();
  TextColumn get exchange => text().nullable()();
  TextColumn get vaultItemId => text().nullable()();
  BoolColumn get offlineBackedUp =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get offlineVerifiedAt => dateTime().nullable()();
  BoolColumn get keyless => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  /// 最近一次同步成功的结束时间（schemaVersion 2 加入）；从未成功为 null。
  /// 只由同步记录仓储在写入成功记录时更新，`Account` 实体不含此字段。
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 地址。(family, address) 唯一（PRD R2）；随账户级联删除（R6）。
@DataClassName('AddressRow')
@TableIndex(
  name: 'idx_addresses_family_address',
  columns: {#family, #address},
  unique: true,
)
class Addresses extends Table {
  TextColumn get id => text()();
  TextColumn get accountId =>
      text().references(Accounts, #id, onDelete: KeyAction.cascade)();
  TextColumn get family => text()();
  TextColumn get address => text()();

  /// JSON 字符串数组。
  TextColumn get enabledChainIds => text()();
  TextColumn get scheme => text().nullable()();
  IntColumn get derivationIndex => integer().nullable()();
  TextColumn get note => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 持仓。`TokenRef` 与 `HoldingLocation` 拆成多列存放，见 `mapping/holding_mapping.dart`。
@DataClassName('HoldingRow')
class Holdings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get accountId =>
      text().references(Accounts, #id, onDelete: KeyAction.cascade)();

  /// `onchain` 或 `exchange`。
  TextColumn get locationKind => text()();
  TextColumn get chainId => text().nullable()();
  TextColumn get addressId => text().nullable()();
  TextColumn get exchangeSub => text().nullable()();

  /// `native`、`contract` 或 `exchange`。
  TextColumn get tokenKind => text()();

  /// native/contract 为链 id；exchange 为交易所 id（规格未给交易所列，复用本列）。
  TextColumn get tokenChainId => text().nullable()();
  TextColumn get tokenContract => text().nullable()();
  TextColumn get tokenSymbol => text().nullable()();
  TextColumn get assetId => text().nullable()();
  TextColumn get displaySymbol => text()();
  TextColumn get amount => text()();
  DateTimeColumn get updatedAt => dateTime()();
}

/// 价格缓存，主键 (asset_id, quote)。
@DataClassName('PriceRow')
class Prices extends Table {
  TextColumn get assetId => text()();
  TextColumn get quote => text()();
  TextColumn get price => text()();
  TextColumn get change24hPercent => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {assetId, quote};
}

/// 每日快照，主键为 UTC 当天零点。
@DataClassName('SnapshotRow')
class Snapshots extends Table {
  DateTimeColumn get date => dateTime()();
  TextColumn get totalUsd => text()();
  BoolColumn get complete => boolean()();

  @override
  Set<Column<Object>> get primaryKey => {date};
}

/// 快照明细：`kind` 为 `account` 或 `asset`，`key` 为账户 id 或资产 id。
@DataClassName('SnapshotItemRow')
class SnapshotItems extends Table {
  DateTimeColumn get date =>
      dateTime().references(Snapshots, #date, onDelete: KeyAction.cascade)();
  TextColumn get kind => text()();
  TextColumn get key => text()();
  TextColumn get valueUsd => text()();

  @override
  Set<Column<Object>> get primaryKey => {date, kind, key};
}

/// 保险库条目的元数据（不含任何密钥材料）。
@DataClassName('VaultItemMetaRow')
class VaultItemsMeta extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get kind => text()();
  IntColumn get wordCount => integer().nullable()();
  TextColumn get family => text().nullable()();
  BoolColumn get hasPassphrase => boolean()();
  TextColumn get fingerprint => text().unique()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 同步记录，全表只保留最近 50 条；随账户级联删除（R6）。
@DataClassName('SyncRecordRow')
class SyncRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get accountId =>
      text().references(Accounts, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get finishedAt => dateTime().nullable()();
  TextColumn get status => text()();
  TextColumn get failureType => text().nullable()();
}

/// 键值设置。
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// 用户手动隐藏的代币（PRD R10）。
@DataClassName('TokenVisibilityRow')
class TokenVisibility extends Table {
  TextColumn get tokenKey => text()();
  BoolColumn get hidden => boolean()();

  @override
  Set<Column<Object>> get primaryKey => {tokenKey};
}

/// 价格源查到的币种（schemaVersion 2 加入）。内置映射表里的币种不入此表。
@DataClassName('AssetRow')
class Assets extends Table {
  TextColumn get id => text()();
  TextColumn get symbol => text()();
  TextColumn get name => text()();
  TextColumn get priceId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 合约到币种的对应（schemaVersion 2 加入）：同一合约不再重复向价格源查询。
/// 随币种级联删除。
@DataClassName('AssetContractRow')
class AssetContracts extends Table {
  TextColumn get chainId => text()();
  TextColumn get contract => text()();
  TextColumn get assetId =>
      text().references(Assets, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column<Object>> get primaryKey => {chainId, contract};
}
