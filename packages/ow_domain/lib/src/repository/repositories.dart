import '../account/account.dart';
import '../account/watch_address.dart';
import '../asset/holding.dart';
import '../asset/price.dart';
import '../chain/chain_family.dart';
import '../exchange/exchange_credentials.dart';
import '../settings/app_settings.dart';
import '../snapshot/snapshot.dart';
import '../sync/sync_record.dart';
import '../vault/vault_item_meta.dart';

// 仓储接口。实现在 `ow_data`（CredentialRepository 基于 SecretStore）。
// 仓储只负责持久化；存储层故障属于程序缺陷，以异常抛出，不返回 Result。

/// 账户。
abstract interface class AccountRepository {
  /// 全部账户；任何变化都会推送新的完整列表。
  Stream<List<Account>> watchAll();

  /// 不存在时返回 null。
  Future<Account?> byId(String id);

  /// 按 id 新增或整体替换。
  Future<void> upsert(Account account);

  /// 删除账户，并级联删除其地址、持仓、同步记录（R6）。
  /// 不删除保险库条目；不存在时什么也不做。
  Future<void> delete(String id);
}

/// 观察地址。
abstract interface class AddressRepository {
  Stream<List<WatchAddress>> watchAll();

  Future<List<WatchAddress>> byAccount(String accountId);

  /// 按家族与规范化地址查找，用于全局唯一检查（R2）。不存在时返回 null。
  Future<WatchAddress?> find(ChainFamily family, String normalizedAddress);

  /// 按 id 新增或整体替换。违反 (family, address) 唯一约束时抛出异常，
  /// 调用方应先用 [find] 检查。
  Future<void> upsert(WatchAddress address);

  /// 删除地址及其持仓；不存在时什么也不做。
  Future<void> delete(String id);
}

/// 持仓缓存。
abstract interface class HoldingRepository {
  Stream<List<Holding>> watchAll();

  /// 在单个事务中用 [holdings] 替换该账户的全部持仓；中途失败时保持原状。
  Future<void> replaceForAccount(String accountId, List<Holding> holdings);
}

/// 价格缓存。
abstract interface class PriceRepository {
  /// 指定计价货币的全部价格，以标准币种 id 为键。
  Stream<Map<String, Price>> watch(Quote quote);

  /// 以 (assetId, quote) 为键新增或替换。
  Future<void> upsertAll(List<Price> prices);
}

/// 每日净值快照。
abstract interface class SnapshotRepository {
  /// 日期在 [from] 与 [to] 之间（含两端）的快照，按日期升序。
  Future<List<Snapshot>> range(DateTime from, DateTime to);

  /// 以 date 为键新增或替换。
  Future<void> upsert(Snapshot snapshot);
}

/// 同步记录。
abstract interface class SyncRecordRepository {
  /// 每个账户最近的一条记录。
  Stream<List<SyncRecord>> watchLatestPerAccount();

  /// 追加一条记录；总数只保留最近 50 条。
  Future<void> add(SyncRecord record);
}

/// 保险库条目元数据。
abstract interface class VaultMetaRepository {
  Stream<List<VaultItemMeta>> watchAll();

  /// 按指纹查重；不存在时返回 null。
  Future<VaultItemMeta?> byFingerprint(String fingerprint);

  /// 按 id 新增或整体替换。
  Future<void> upsert(VaultItemMeta meta);

  /// 不存在时什么也不做。
  Future<void> delete(String id);
}

/// 应用设置。
abstract interface class SettingsRepository {
  /// 当前设置；从未保存过时推送 `AppSettings()` 的默认值。
  Stream<AppSettings> watch();

  /// 以 [change] 对当前设置做读改写并保存。
  Future<void> update(AppSettings Function(AppSettings) change);
}

/// 用户手动设置的代币显隐（R10）。
abstract interface class TokenVisibilityRepository {
  /// 被设为隐藏的代币键。
  Future<Set<String>> hidden();

  Future<void> setHidden(String tokenKey, bool hidden);
}

/// 交易所凭据，存于 `SecretStore`，不进数据库。
abstract interface class CredentialRepository {
  Future<void> save(String accountId, ExchangeCredentials c);

  /// 不存在时返回 null。
  Future<ExchangeCredentials?> load(String accountId);

  /// 不存在时什么也不做。
  Future<void> delete(String accountId);
}
