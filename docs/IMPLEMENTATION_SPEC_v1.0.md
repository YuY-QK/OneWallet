# 《OneWallet》实现规格

> 版本 v1.0 · 2026-11-10 · 状态：已确认
> 本文把 PRD 和 TECH_DESIGN 落到**具体的名字和签名**上，目的是让不同的执行者写出结构一致的代码。
> 这里出现的包名、文件路径、类型名、字段名、路由、表名都是约定，实现时照用。确实需要改动时，先改本文并在提交说明里写明原因。
> 本文没有规定的细节（私有函数、组件内部拆分等），执行者自行决定。

## 1. 通用约定

| 项 | 约定 |
|---|---|
| 标识符 | `String`，UUID v4。由应用层通过注入的 `IdGenerator` 生成，领域层不生成 |
| 时间 | `DateTime`，一律 UTC 存储，显示时转本地。当前时间通过注入的 `Clock` 获取，禁止在业务代码中直接调用 `DateTime.now()` |
| 金额与数量 | `Decimal`（`decimal` 包）。数据库中存为字符串。禁止 `double` |
| 失败 | 可预期失败返回 `Result<T>`（已在 `ow_domain`）。新增失败类型加到 `failure.dart` 的封闭集合里 |
| 敏感数据 | 用 `Sensitive`（已在 `ow_domain`）持有；跨函数传递时不转成 `String` |
| 状态管理 | Riverpod 只出现在 `app/`。`packages/` 中的类一律用构造函数注入依赖，不引用 Riverpod |
| 依赖装配 | 全部 Provider 定义在 `app/lib/bootstrap/providers.dart`（可按领域拆成同目录下多个文件） |
| 界面文案 | 全部在 `app/lib/l10n/app_zh.arb`。键名：`<页面或模块><含义>`，小驼峰，如 `overviewTotalAssets`、`failureRateLimited` |
| 测试文件 | 与被测文件同名加 `_test.dart`，放在该包的 `test/` 下并保持相同的子目录结构 |

`ow_domain` 允许的第三方依赖：`decimal`、`meta`。其余纯 Dart 包按需添加第三方依赖，但须遵守 DEV_GUIDELINES 第 10 节；`ow_vault` 另受白名单约束。

## 2. 领域模型（`packages/ow_domain/lib/src/`）

以下为公开类型与字段。全部不可变；可以用 `freezed`，也可以手写 `final` 字段加 `copyWith`，同一个包内保持一致。

### 2.1 `chain/`

```dart
enum ChainFamily { evm, bitcoin, solana, tron }            // 已存在

final class ChainInfo {
  final String id;                 // 见下表
  final ChainFamily family;
  final String name;               // 显示名
  final String nativeSymbol;       // ETH、BNB、BTC…
  final int nativeDecimals;
  final int? evmChainId;           // 仅 EVM
  final String explorerAddressUrl; // 含 {address} 占位符
}

abstract final class Chains {      // 内置链表，v1.0 固定 9 条
  static const List<ChainInfo> all;
  static ChainInfo byId(String id);         // 未知 id 抛 ArgumentError（程序缺陷）
  static ChainInfo? tryById(String id);     // 未知 id 返回 null，用于外部来源的数据
  static List<ChainInfo> ofFamily(ChainFamily family);
}
```

| `id` | 家族 | 原生币 | `evmChainId` |
|---|---|---|---|
| `ethereum` | evm | ETH | 1 |
| `bsc` | evm | BNB | 56 |
| `arbitrum` | evm | ETH | 42161 |
| `optimism` | evm | ETH | 10 |
| `base` | evm | ETH | 8453 |
| `polygon` | evm | POL | 137 |
| `bitcoin` | bitcoin | BTC | — |
| `solana` | solana | SOL | — |
| `tron` | tron | TRX | — |

`DerivationScheme` 已存在，不再重复。

```dart
/// 地址校验与规范化。纯函数，不联网。实现放在 ow_domain，供界面即时校验。
/// 只看格式的操作是静态方法；用到校验和的操作是实例方法，校验和由构造函数注入。
final class AddressCodec {
  const AddressCodec({AddressChecksum? checksum});  // 为 null 时只做格式判断
  static ChainFamily? detectFamily(String input);   // 只看格式；识别不了返回 null
  ChainFamily? detect(String input);                // 按 EVM、Tron、Bitcoin、Solana 顺序返回第一个格式与校验和都通过的家族；未注入校验和时等同 detectFamily。界面一律用它
  bool isValid(String input, ChainFamily family);   // 格式通过后再调 checksum.verify
  static String normalize(String input, ChainFamily family); // EVM 转小写；Bitcoin 全大写 bech32 转小写；其余原样去空白
  String display(String normalized, ChainFamily family);     // EVM 转 EIP-55；未注入时原样
  static String shorten(String address);            // 前 6 后 4，中间为"…"
}

/// 校验和验证与 EIP-55 转换，由 ow_chains 实现。
abstract interface class AddressChecksum {
  bool verify(String address, ChainFamily family);  // 地址已通过格式判断并去除首尾空白
  String toEip55(String normalizedEvmAddress);
}
```

EIP-55 需要 Keccak-256，Base58Check 需要 SHA-256，Bech32 需要校验和。`ow_domain` 不引入密码学库，所以 `AddressCodec` 的**格式判断**（前缀、长度、字符集）在 `ow_domain`，**校验和验证与 EIP-55 转换**通过接口 `AddressChecksum` 注入，由 `ow_chains` 提供实现（`ow_chains` 可依赖 `blockchain_utils`，仅用于地址编解码）。注入走构造函数而不是全局可变状态，所以 `AddressCodec` 是可实例化的类，由 `app/lib/bootstrap/` 装配带校验和的实例。

格式判断规则（输入先去首尾空白）：

| 家族 | 格式 |
|---|---|
| EVM | `0x` 加 40 个十六进制字符（大小写不限） |
| Bitcoin | `1` 或 `3` 开头的 Base58 字符串，总长 26–35；或 `bc1q` 开头、小写 bech32 字符集、总长 42 或 62；或 `bc1p` 开头、小写 bech32 字符集、总长 62 |
| Solana | Base58 字符集，长度 32–44 |
| Tron | `T` 开头的 Base58 字符串，长度 34 |

`detectFamily` 按 EVM、Tron、Bitcoin、Solana 的顺序判断，因为 Tron 地址和 `1`、`3` 开头的 Bitcoin 地址同时满足 Solana 的格式。反过来，个别 Solana 地址（如系统程序地址，32 个 `1`）格式上也满足 Bitcoin，`detectFamily` 会误判；`detect` 用同样的顺序但要求校验和也通过，从而消除这类歧义（M1-02）。

Bitcoin 的 bech32 地址（`bc1q`、`bc1p`）接受全大写形式（BIP173 允许，常见于二维码），`normalize` 把它转为小写；大小写混用的不合法。`ChainAddressChecksum`（`ow_chains`）还检查：Base58 地址的版本字节（P2PKH `0x00`、P2SH `0x05`）、HRP 必须为 `bc`、`bc1q` 的见证版本为 0（Bech32，程序 20 或 32 字节）、`bc1p` 为 1（Bech32m，32 字节）；Tron 版本字节 `0x41`；Solana 解码后恰为 32 字节；EVM 全小写或全大写视为无校验和，大小写混合须通过 EIP-55。

### 2.2 `account/`

```dart
enum AccountType { wallet, exchange }
enum ExchangeId { binance, okx, bybit, bitget }
enum WalletSource { uniswap, metamask, okxWeb3, bitgetWallet, trustWallet, other }

final class BackupStatus {
  final bool offlineBackedUp;        // 用户标记有离线备份
  final DateTime? offlineVerifiedAt; // 上次核对日期
  final bool keyless;                // 无助记词钱包
}
enum BackupLevel { inVault, offlineOnly, inVaultAndOffline, keyless, none }

final class Account {
  final String id;
  final AccountType type;
  final String name;                 // 1–30 字
  final int colorIndex;              // 0–7，对应设计规范中的头像色
  final String note;
  final WalletSource? walletSource;  // 仅钱包
  final ExchangeId? exchange;        // 仅交易所
  final String? vaultItemId;         // 仅钱包；关联的密钥条目
  final BackupStatus backup;         // 仅钱包有意义
  final DateTime createdAt;

  BackupLevel get backupLevel;       // 由 vaultItemId 与 backup 推出（PRD R34、R35）
}

final class WatchAddress {
  final String id;
  final String accountId;
  final ChainFamily family;
  final String address;              // 规范化形式
  final Set<String> enabledChainIds; // EVM 可多条；其余固定一条
  final DerivationScheme? scheme;    // 由保险库派生时记录
  final int? derivationIndex;
  final String note;
}
```

### 2.3 `asset/`

```dart
final class Asset {                  // 标准币种
  final String id;                   // 大写符号，如 "USDT"；冲突时加后缀
  final String symbol;
  final String name;
  final String? priceId;             // 价格源中的标识（CoinGecko id）
}

/// 数据源返回的原始代币标识。
sealed class TokenRef {}
final class NativeToken extends TokenRef { final String chainId; }
final class ContractToken extends TokenRef { final String chainId; final String contract; }
final class ExchangeToken extends TokenRef { final ExchangeId exchange; final String symbol; }

enum ExchangeSubAccount { spot, funding, futures, margin, earn, other }

sealed class HoldingLocation {}
final class OnChainLocation extends HoldingLocation { final String chainId; final String addressId; }
final class ExchangeLocation extends HoldingLocation { final ExchangeSubAccount sub; }

/// 适配器的输出：尚未归一化。
final class RawHolding {
  final TokenRef token;
  final Decimal amount;
  final String? symbolHint;          // 数据源给出的符号，仅用于显示未识别代币
  final String? nameHint;
}

final class Holding {
  final String accountId;
  final HoldingLocation location;
  final TokenRef token;
  final String? assetId;             // 归一化成功时非空
  final String displaySymbol;
  final Decimal amount;
  final DateTime updatedAt;
}

enum Quote { usd, cny }

final class Price {
  final String assetId;
  final Quote quote;
  final Decimal price;
  final Decimal? change24hPercent;
  final DateTime updatedAt;
}
```

### 2.4 `portfolio/`（纯函数，PRD R7–R12）

```dart
final class ValuedHolding { final Holding holding; final Decimal? value; }
final class AssetSlice { final String assetId; final String displaySymbol; final Decimal amount; final Decimal value; } // 只含有估值的标准币种
final class AccountSlice { final String accountId; final Decimal value; }

final class PortfolioSummary {
  final Decimal total;
  final Decimal? change24h;          // 金额
  final Decimal? change24hPercent;
  final int unpricedCount;           // R9
  final int hiddenSmallCount;        // R11
  final List<AssetSlice> byAsset;    // 按估值降序
  final List<AccountSlice> byAccount;
  final Decimal onChainTotal;
  final Decimal exchangeTotal;
}

/// 某币种在一个账户、一个位置上的分布（P09）。
final class DistributionEntry {
  final String accountId;
  final HoldingLocation location;
  final Decimal amount;
  final Decimal? value;              // 币种无价格时为 null
  final Decimal share;               // 0–100；总估值为 0 或无价格时为 0
}

abstract final class PortfolioCalculator {
  static PortfolioSummary summarize({
    required List<Account> accounts,
    required List<Holding> holdings,
    required Map<String, Price> prices,   // 以 assetId 为键，当前计价货币
    required bool hideSmall,
    required Decimal smallThreshold,      // "1 USD 折合当前计价货币"的值，由调用方换算；估值低于它的币种在 hideSmall 时隐藏
    required Set<String> hiddenTokens,    // 用户手动隐藏的 tokenKey；这些持仓完全排除
  });

  /// 某币种在各账户、各位置的分布，按估值降序（无估值排最后，再按数量降序、账户 id 升序）。
  static List<DistributionEntry> distributionOf({
    required String assetId,
    required List<Holding> holdings,
    required Map<String, Price> prices,
    Set<String> hiddenTokens = const {},
  });
}

/// part 占 total 的百分数（0–100），保留 18 位小数；total 为 0 时返回 0。
Decimal shareOf(Decimal part, Decimal total);
```

`summarize` 的规则要点：

- 账户不在 `accounts` 中的持仓整体忽略，因此 `byAccount` 估值之和 = `total`；`onChainTotal`（按持仓位置）+ `exchangeTotal` = `total`。
- 无估值（assetId 为空或 `prices` 无该 assetId）的持仓不计入任何总额；`unpricedCount` 为这类**不同币种**数（assetId 为空的以 `tokenKey` 为准）；被手动隐藏的不计入。
- 同一 assetId 合并为一个 `AssetSlice`，`displaySymbol` 取第一条持仓的符号。`hideSmall` 只隐藏列表项，仍计入总额与账户汇总。
- 排序：`byAsset` 估值降序、assetId 升序；`byAccount` 含全部传入账户，估值降序、名称升序。
- 24 小时变化 = 当前数量 × 24 小时前价格估算，前值 = 估值 / (1 + 涨跌百分比 / 100)。缺百分比（或 ≤ −100%，避免除以零）的持仓按"无变化"计入；全部缺或前值合计为 0 时 `change24h`、`change24hPercent` 为 null。
- 除法在精确分数上进行，最终四舍五入（远离零）到 18 位小数。

### 2.5 其他

```dart
final class Snapshot {
  final DateTime date;               // UTC 当天零点
  final Decimal totalUsd;
  final bool complete;               // R16
  final Map<String, Decimal> byAccountUsd;
  final Map<String, Decimal> byAssetUsd;
}

enum SyncStatus { success, failed, running }
final class SyncRecord {
  final String accountId;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final SyncStatus status;
  final String? failureType;         // Failure 的类型名
}

enum VaultItemKind { mnemonic, privateKey }
final class VaultItemMeta {
  final String id;
  final String name;
  final VaultItemKind kind;
  final int? wordCount;              // 仅助记词
  final ChainFamily? family;         // 仅私钥
  final bool hasPassphrase;
  final String fingerprint;          // 十六进制，查重用
  final DateTime createdAt;
}

final class ExchangeCredentials {
  final Sensitive apiKey;
  final Sensitive apiSecret;
  final Sensitive? passphrase;       // OKX、Bitget
}
final class DepositAddress { final String symbol; final String network; final String address; final String? memo; }
enum KeyPermission { readOnly, canTrade, canWithdraw, unknown }
final class CredentialCheck { final KeyPermission permission; }

final class AppSettings {
  final Quote quote;                 // 默认 usd
  final bool hideSmall;              // 默认 true
  final bool hideAmounts;            // 默认 false
  final ThemePreference theme;       // system | light | dark
  final AutoLock autoLock;           // immediately | after1Min | after5Min
  final bool appBiometrics;
  final bool vaultBiometrics;
  final DateTime? lastBackupExportedAt;
  final DateTime? vaultChangedAt;    // 用于"有未备份的更改"
}
```

## 3. 接口（定义在 `ow_domain`）

### 3.1 仓储

```dart
abstract interface class AccountRepository {
  Stream<List<Account>> watchAll();
  Future<Account?> byId(String id);
  Future<void> upsert(Account account);
  Future<void> delete(String id);          // 级联删除地址、持仓、同步记录（R6）
}
abstract interface class AddressRepository {
  Stream<List<WatchAddress>> watchAll();
  Future<List<WatchAddress>> byAccount(String accountId);
  Future<WatchAddress?> find(ChainFamily family, String normalizedAddress); // R2
  Future<void> upsert(WatchAddress address);
  Future<void> delete(String id);
}
abstract interface class HoldingRepository {
  Stream<List<Holding>> watchAll();
  Future<void> replaceForAccount(String accountId, List<Holding> holdings); // 单事务
}
abstract interface class PriceRepository {
  Stream<Map<String, Price>> watch(Quote quote);
  Future<void> upsertAll(List<Price> prices);
}
abstract interface class SnapshotRepository {
  Future<List<Snapshot>> range(DateTime from, DateTime to);
  Future<void> upsert(Snapshot snapshot);                                   // 以 date 为键
}
abstract interface class SyncRecordRepository {
  Stream<List<SyncRecord>> watchLatestPerAccount();
  Future<void> add(SyncRecord record);                                      // 只保留最近 50 条
}
abstract interface class VaultMetaRepository {
  Stream<List<VaultItemMeta>> watchAll();
  Future<VaultItemMeta?> byFingerprint(String fingerprint);
  Future<void> upsert(VaultItemMeta meta);
  Future<void> delete(String id);
}
abstract interface class SettingsRepository {
  Stream<AppSettings> watch();
  Future<void> update(AppSettings Function(AppSettings) change);
}
// tokenKey 的格式：链上代币 "<chainId>:<合约规范化形式>"，原生币 "<chainId>:native"，
// 交易所币种 "<exchange 枚举名>:<符号大写>"。由 TokenRef 的扩展 getter `tokenKey` 统一生成。
abstract interface class TokenVisibilityRepository {                        // R10
  Future<Set<String>> hidden();
  Future<void> setHidden(String tokenKey, bool hidden);
}
abstract interface class CredentialRepository {                             // 基于 SecretStore
  Future<void> save(String accountId, ExchangeCredentials c);
  Future<ExchangeCredentials?> load(String accountId);
  Future<void> delete(String accountId);
}
```

### 3.2 数据源适配器

```dart
abstract interface class ChainAdapter {
  ChainFamily get family;
  Future<Result<List<RawHolding>>> fetchHoldings(String address, ChainInfo chain);
  Future<Result<bool>> hasActivity(String address, ChainInfo chain);        // P16
}
abstract interface class ExchangeAdapter {
  ExchangeId get id;
  bool get needsPassphrase;
  Future<Result<CredentialCheck>> verify(ExchangeCredentials c);
  Future<Result<List<(ExchangeSubAccount, RawHolding)>>> fetchHoldings(ExchangeCredentials c);
  Future<Result<List<DepositAddress>>> fetchDepositAddresses(ExchangeCredentials c);
}
abstract interface class PriceSource {
  Future<Result<List<Price>>> fetchPrices(Set<Asset> assets, Quote quote);
  Future<Result<Map<ContractToken, Asset>>> lookupContracts(Set<ContractToken> tokens);
}
abstract interface class AssetCatalog {                                     // 内置映射表
  Asset? resolve(TokenRef token);
  Asset? byId(String assetId);
}
abstract interface class AdapterRegistry {
  ChainAdapter chain(ChainFamily family);
  ExchangeAdapter exchange(ExchangeId id);
}
```

### 3.3 其他

```dart
abstract interface class IdGenerator { String newId(); }
abstract interface class Clock { DateTime nowUtc(); }
abstract interface class DataSourceConfig {          // P20；Key 存 SecretStore
  Future<String?> apiKey(String providerId);
  Future<Uri?> customEndpoint(String chainId);
}
```

平台能力接口（`PlatformCapabilities`、`HardwareKeyStore`、`SecretStore`、`ScreenGuard`、`FileExporter`）已存在。M3 另加：

```dart
abstract interface class BiometricAuth {
  Future<bool> isAvailable();
  Future<Result<void>> authenticate({required String reason});
}
abstract interface class DeviceIntegrity { Future<bool> looksCompromised(); }
```

## 4. 应用层用例（`packages/ow_application/lib/src/`）

每个用例一个类，一个公开方法 `call(...)`，构造函数注入依赖。有可预期失败的用例返回 `Future<Result<T>>`；两个例外：`SyncAllAccounts` 没有整体失败的路径，返回 `Future<SyncAllResult>`（各账户的失败在结果对象里）；`Watch*` 用例返回 `Stream`。

同步的约定（M1-07）：
- 取消不算失败：被取消的账户返回 `Ok(SyncAccountOutcome.cancelled())`，不写持仓、不写同步记录；取消后不拉价格。
- 一个账户内的"地址 × 链"逐个查询，任一失败则整个账户失败并保留旧数据。
- 每个账户每次同步只在结束时写一条 `SyncRecord`；`failureType` 用 `failureTypeName(Failure)` 生成稳定的名称（不用 `runtimeType`，混淆后会变）。
- `AddWalletAccount`、`AddAddressesToAccount` 不触发同步，由调用它们的控制器在成功后调用 `SyncAccount`。
- 装配时给 `SyncAccount`、`SyncAllAccounts` 传入默认的 `RetryPolicy()`（真实等待）；测试传入假延时。

| 里程碑 | 用例 | 对应 |
|---|---|---|
| M1 | `AddWalletAccount`、`AddAddressesToAccount`、`SyncAccount`、`SyncAllAccounts`、`WatchPortfolio`（返回 `Stream<PortfolioSummary>`） | P05、P02、R13–R17 |
| M2 | `AddExchangeAccount`、`ReplaceExchangeCredentials`、`WatchAssetDistribution` | P06、P08、P09 |
| M3 | `SetUpPin`、`VerifyPin`、`ChangePin`、`RenameAccount`、`DeleteAccount`、`UpdateBackupStatus`、`WatchBackupChecklist`、`SearchAddresses`、`RecordDailySnapshot`、`WipeAllData` | P00、P01、P03、P10、P11、R18–R21、R34–R38 |
| M4 | `CreateVault`、`ImportVaultItem`、`RevealVaultItem`、`DeleteVaultItem`、`DeriveAddresses`、`AttachDerivedAddresses`、`ChangeMasterPassword`、`SetVaultBiometrics` | P12–P16、R22–R33 |
| M5 | `ExportBackup`、`PreviewBackup`、`RestoreBackup` | P17、R39–R43 |

`SyncAllAccounts` 的并发、重试、限速规则见 TECH_DESIGN 5.2；重试与限速实现为可复用的 `RetryPolicy` 和 `RateLimiter`：`RetryPolicy` 在 `ow_application/lib/src/sync/`，`RateLimiter` 在 `ow_net`。

## 5. 数据库（`packages/ow_data`）

`ow_data` 是纯 Dart 包：用 Drift 定义表和仓储实现，**不负责打开数据库文件**。数据库连接（`QueryExecutor`）由 `app/lib/bootstrap/` 用 SQLCipher 打开后注入；测试用内存数据库。

| 表 | 列（主键加粗） |
|---|---|
| `accounts` | **id**, type, name, color_index, note, wallet_source, exchange, vault_item_id, offline_backed_up, offline_verified_at, keyless, created_at |
| `addresses` | **id**, account_id→accounts, family, address, enabled_chain_ids（JSON 数组）, scheme, derivation_index, note；唯一索引 (family, address) |
| `holdings` | **id**（自增）, account_id→accounts, location_kind, chain_id, address_id, exchange_sub, token_kind, token_chain_id, token_contract, token_symbol, asset_id, display_symbol, amount（文本）, updated_at |
| `prices` | **asset_id**, **quote**, price（文本）, change_24h_percent（文本）, updated_at |
| `snapshots` | **date**, total_usd（文本）, complete |
| `snapshot_items` | **date**, **kind**（account｜asset）, **key**, value_usd（文本） |
| `vault_items_meta` | **id**, name, kind, word_count, family, has_passphrase, fingerprint（唯一）, created_at |
| `sync_records` | **id**（自增）, account_id, started_at, finished_at, status, failure_type |
| `settings` | **key**, value（文本） |
| `token_visibility` | **token_key**, hidden |

- 外键开启级联删除：`addresses.account_id`、`holdings.account_id`、`sync_records.account_id` 都指向 `accounts` 并级联。`holdings.address_id` 不设外键，删除地址时由仓储在同一事务内删除它的持仓；删除账户时由仓储清理 `snapshot_items` 中该账户的明细。
- 交易所币种（`token_kind` 为 exchange）的交易所 id 存在 `token_chain_id` 列，符号存在 `token_symbol` 列。
- 时间以 ISO-8601 文本存储（UTC，保留毫秒）。
- 所有 upsert 用 `INSERT … ON CONFLICT DO UPDATE`，不用 `INSERT OR REPLACE`（后者会先删父行并触发级联删除）。
- 读取时遇到无法解码的行（未知枚举名、未知链 id、损坏的金额）：列表类读取跳过该行，按键读取返回 null，不崩溃。
- `sync_records` 全表只保留最近 50 条。每次全量同步会为每个账户各写一条，所以每个账户最近一次的状态始终在内。
- 生成的 `ow_database.g.dart` 纳入版本控制；改表后运行 `cd packages/ow_data && dart run build_runner build`。
- 数据库 `schemaVersion` 从 1 开始；每次改表都写迁移并加迁移测试。
- 文件名 `onewallet.db`，位于应用支持目录。

## 6. 保险库（`packages/ow_vault`）

格式与算法以 SECURITY_DESIGN 第 3–5 节为准。本包不导入 `dart:io`，文件读写和密码学原语都通过接口注入。

```dart
/// 密码学原语。唯一实现基于 libsodium（`sodium` 包），放在本包 `src/crypto/sodium_crypto.dart`。
abstract interface class VaultCrypto {
  Uint8List randomBytes(int length);
  Future<Uint8List> argon2id(Sensitive password, Uint8List salt, KdfParams params); // 输出 32 字节
  Uint8List aeadEncrypt(Uint8List key, Uint8List nonce, Uint8List plaintext, Uint8List aad);
  Result<Uint8List> aeadDecrypt(Uint8List key, Uint8List nonce, Uint8List ciphertext, Uint8List aad);
  Uint8List deriveSubkey(Uint8List masterKey, String context8, int subkeyId);
  Uint8List keyedHash(Uint8List key, Uint8List message, int outputLength);
}

abstract interface class VaultStorage {       // 由 app 提供基于文件的实现，含原子写入
  Future<Uint8List?> read();
  Future<void> writeAtomic(Uint8List bytes);
  Future<void> delete();
}

final class KdfParams { final int memKib; final int iterations; final int parallelism; }

/// 已解锁的保险库会话。用完必须 [close]，会清除内存中的主密钥。
abstract interface class VaultSession {
  Sensitive exportMasterKey();                // 仅用于生成硬件包裹
  Future<Result<VaultItemSecret>> readItem(String id);
  Future<Result<String>> addItem(String id, VaultItemSecret secret); // 返回指纹
  Future<Result<void>> deleteItem(String id);
  String fingerprintOf(VaultItemSecret secret);
  Future<Result<void>> changePassword(Sensitive newPassword);
  void close();
}

final class Vault {
  Vault({required VaultCrypto crypto, required VaultStorage storage, required KdfParams defaultParams});
  Future<bool> exists();
  Future<Result<VaultSession>> create(Sensitive password);
  Future<Result<VaultSession>> unlockWithPassword(Sensitive password);
  Future<Result<VaultSession>> unlockWithMasterKey(Sensitive masterKey); // 硬件解包后调用
}

sealed class VaultItemSecret {}
final class MnemonicSecret extends VaultItemSecret { final Sensitive mnemonic; final Sensitive? passphrase; }
final class PrivateKeySecret extends VaultItemSecret { final ChainFamily family; final Sensitive key; }

/// 加密备份文件（.owbak）的编解码。
abstract final class BackupCodec {
  static Future<Uint8List> encode(BackupPayload payload, Sensitive password, VaultCrypto crypto, KdfParams params);
  static Future<Result<BackupPayload>> decode(Uint8List file, Sensitive password, VaultCrypto crypto);
}
```

硬件包裹的流程在应用层：`CreateVault` 或 `SetVaultBiometrics` 取 `exportMasterKey()` 交给 `HardwareKeyStore.wrap`；`RevealVaultItem` 先尝试 `HardwareKeyStore.unwrap` 再 `unlockWithMasterKey`，失败则要求主密码。

## 7. 应用（`app/lib/`）

### 7.1 路由

| 页面 | 路径 | 路由名 |
|---|---|---|
| P00 解锁 | `/lock` | `lock` |
| P01 首次引导 | `/onboarding` | `onboarding` |
| P02 总览 | `/overview` | `overview` |
| P03 账户列表 | `/accounts` | `accounts` |
| P04 添加账户 | `/accounts/add` | `accountAdd` |
| P05 添加钱包账户 | `/accounts/add/wallet`（可带 `?accountId=`） | `walletAdd` |
| P06 添加交易所账户 | `/accounts/add/exchange`（可带 `?accountId=`） | `exchangeAdd` |
| P07 钱包账户详情 | `/accounts/wallet/:id` | `walletDetail` |
| P08 交易所账户详情 | `/accounts/exchange/:id` | `exchangeDetail` |
| P09 币种详情 | `/overview/asset/:assetId` | `assetDetail` |
| P10 地址簿 | `/accounts/addresses` | `addressBook` |
| P11 备份清单 | `/vault/checklist` | `backupChecklist` |
| P12 保险库首页 | `/vault` | `vault` |
| P13 设置主密码 | `/vault/setup` | `vaultSetup` |
| P14 导入密钥 | `/vault/import`（可带 `?accountId=`） | `vaultImport` |
| P15 密钥详情 | `/vault/item/:id` | `vaultItem` |
| P16 派生地址 | `/vault/item/:id/derive` | `vaultDerive` |
| P17 加密备份 | `/settings/backup`、`/settings/backup/export`、`/settings/backup/restore` | `backup`、`backupExport`、`backupRestore` |
| P18 设置 | `/settings` | `settings` |
| P19 安全设置 | `/settings/security` | `settingsSecurity` |
| P20 数据源 | `/settings/sources` | `settingsSources` |
| P21 同步状态 | `/settings/sync` | `settingsSync` |
| P22 关于与帮助 | `/settings/about` | `settingsAbout` |

- 路由参数只允许 id，不传对象，更不传任何密钥类数据。
- 锁定时所有路径重定向到 `/lock`；未完成引导时重定向到 `/onboarding`。

### 7.2 目录与命名

```
app/lib/features/<feature>/
  presentation/<name>_page.dart        // 页面，类名 <Name>Page
  presentation/widgets/…               // 仅本 feature 使用的组件
  controllers/<name>_controller.dart   // Riverpod Notifier，类名 <Name>Controller
```

通用组件放 `app/lib/widgets/`，统一以 `Ow` 开头：`OwCard`、`OwListGroup`、`OwRow`、`OwAvatar`、`OwPill`、`OwNotice`、`OwSegmented`、`OwShareBar`、`OwAmountText`、`OwAddressText`、`OwPrimaryButton`、`OwSecondaryButton`、`OwDangerButton`、`OwMnemonicGrid`、`OwVeil`、`OwNetWorthChart`。规格见 UI_DESIGN_SYSTEM 第 5 节，样子以 `docs/prototype.html` 为准。

### 7.3 显示规则

| 内容 | 规则 |
|---|---|
| 估值 | 货币符号加两位小数，千分位分隔：`$128,450.32`、`¥921,330.10` |
| 数量 | 最多 8 位有效数字，去掉尾随零；小于 `0.00000001` 显示 `<0.00000001` |
| 百分比 | 一位或两位小数，带正负号 |
| 地址 | 列表中缩略为前 6 后 4；详情面板显示完整 |
| 隐藏金额 | 开启后所有估值与数量显示 `****` |
| 相对时间 | 1 分钟内"刚刚"；1 小时内"N 分钟前"；当天"HH:mm"；更早"MM-DD HH:mm" |

格式化函数集中在 `app/lib/widgets/formatters.dart`，带单元测试。

已实现的函数与细则（M0-08）：

| 函数 | 细则 |
|---|---|
| `formatFiat` | 负号在货币符号前：`-$12.50` |
| `formatQuantity` | 超出 8 位有效数字的部分**截断**（向零取整），不四舍五入，避免把持仓显示得比实际多；不加千分位；小于 1 的数前导零不算有效数字 |
| `formatPercent` | 入参是已乘 100 的数值（`1.234` 表示 1.234%）；四舍五入后为零时显示不带符号的 `0.00%` |
| `shortenAddress` | 前 6 位加 `…` 加后 4 位 |
| `maskIfHidden` | 隐藏金额时返回 `****`；各格式化函数也有 `hidden` 参数 |
| `formatRelativeTime` | "现在"由参数传入；"当天"按本地时区判断 |

### 7.4 失败到文案

每种 `Failure` 在 ARB 中有一条 `failure<类型>` 文案，由 `app/lib/widgets/failure_text.dart` 统一映射。页面不得自己拼错误信息。

## 8. 外部接口的核对规则

各数据服务和交易所的接口路径、参数、限频、返回结构**必须在实现该适配器时对照官方文档核对**，并把核对结果写进 `docs/EXTERNAL_APIS.md`（每个适配器一节：文档链接、用到的接口、鉴权方式、限频、字段映射、核对日期）。没有这份记录的适配器不得合并。

下表是**起点**，凭记忆整理，可能已过时，只用于帮助定位文档：

| 来源 | 可能用到的接口 |
|---|---|
| EVM（Alchemy） | JSON-RPC `eth_getBalance`、`alchemy_getTokenBalances`、`alchemy_getTokenMetadata` |
| Bitcoin（Esplora） | `GET /api/address/{address}` |
| Solana RPC | `getBalance`、`getTokenAccountsByOwner` |
| Tron（TronGrid） | `GET /v1/accounts/{address}` |
| CoinGecko | `/api/v3/simple/price`、`/api/v3/simple/token_price/{platform}` |
| Binance | 现货账户信息、用户资产、API Key 权限查询、充值地址查询 |
| OKX | 交易账户余额、资金账户余额、充值地址 |
| Bybit | 钱包余额、资金账户余额、API Key 信息 |
| Bitget | 现货资产、合约账户、API Key 信息 |

规则：

- 只允许调用读取类接口。`tools/ci/check_deps.dart` 会扫描 `ow_exchanges` 中含有 `order`、`withdraw`、`transfer` 等字样的路径；确属只读但被误拦的接口，加入脚本中的 `readOnlyPathAllowlist` 并在旁边注释说明用途和文档链接。
- 适配器的自动化测试只用录制样本（`test/fixtures/`），样本取自官方文档示例或脱敏后的真实响应。
- 需要真实 Key 的冒烟测试放在 `tools/smoke/`，从环境变量读取 Key，由用户在自己的机器上手动运行。仓库和 CI 中不出现任何真实 Key。
