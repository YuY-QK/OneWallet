# 《OneWallet》技术设计文档

> 版本 v1.0 · 2026-11-10 · 状态：已确认（2026-11-10）
> 文中的库和服务商选择均为**建议方案**，具体版本在 M0 时按当时的最新稳定版确认。

## 1. 文档目的与范围

说明 OneWallet 如何实现 PRD v1.0，并保证后续能扩展到桌面端和平板。保险库的密码学细节和威胁模型在 `SECURITY_DESIGN_v1.0.md` 中单独说明。

## 2. 质量属性与非功能目标

| 属性 | 目标 |
|---|---|
| 安全 | 密钥只存本机；保险库代码无网络能力；详见 SECURITY_DESIGN |
| 多端可扩展 | 新增一个平台时，只需实现平台适配层并调整布局，业务代码零改动 |
| 可扩展 | 新增一条链或一家交易所只需新增一个适配器并注册，不改上层 |
| 离线 | 无网络时可查看缓存，保险库全功能可用 |
| 性能 | 冷启动到显示缓存不超过 2 秒；全量同步不超过 30 秒（20 地址加 4 交易所） |
| 隐私 | 无自有后端、无统计埋点、无第三方崩溃上报 |
| 可恢复 | 备份格式公开且带版本号，可脱离 app 解密 |
| 可测试 | 业务逻辑不依赖界面和平台，可在纯 Dart 环境运行单元测试 |

## 3. 总体架构

### 3.1 技术选型

| 项 | 选择 | 理由 |
|---|---|---|
| 框架 | Flutter（Dart） | 一套代码覆盖 iOS、Android、macOS、Windows、Linux；见 ADR_001 |
| 状态管理 | Riverpod | 依赖注入与状态合一，便于替换平台实现和测试 |
| 路由 | go_router | 声明式；支持嵌套导航，便于在窄屏与宽屏间切换导航外壳 |
| 本地数据库 | Drift + SQLCipher | 类型安全的 SQL；整库加密；全平台可用 |
| 密码学 | libsodium（经 Dart 绑定） | Argon2id、XChaCha20-Poly1305 的成熟实现；不自己实现算法 |
| 密钥派生（BIP39/32/44、SLIP-0010） | M0 评估后选定 | 候选与评估标准见 5.4 |
| 网络 | dio | 拦截器便于统一做签名、限频、脱敏日志 |
| 不可变模型 | freezed + json_serializable | 减少手写样板 |
| 多包管理 | Dart workspace（或 melos） | 用包边界强制隔离保险库 |
| 国际化 | flutter_localizations + ARB | v1.0 只有简体中文，但文案全部走资源文件 |

### 3.2 分层与多端策略

```
┌────────────────────────────────────────────────────────────┐
│ 表现层 app/                                                 │
│  页面、组件、响应式外壳（窄屏底部 Tab ／ 宽屏侧边栏）           │
├────────────────────────────────────────────────────────────┤
│ 应用层 packages/ow_application                              │
│  用例（UseCase）与控制器：同步资产、添加账户、入库密钥、导出备份  │
├────────────────────────────────────────────────────────────┤
│ 领域层 packages/ow_domain（纯 Dart，无任何 IO）               │
│  实体、值对象、仓储接口、平台能力接口、归一化与估值规则           │
├───────────────┬───────────────┬────────────────────────────┤
│ 数据层         │ 保险库          │ 平台适配层                  │
│ ow_data       │ ow_vault      │ ow_platform               │
│ 数据库、仓储实现 │ 加解密、派生    │ 硬件密钥、生物识别、防截屏、   │
│ ow_chains     │ 备份格式       │ 文件导出、扫码               │
│ ow_exchanges  │ （禁止联网）    │ （每个平台一份实现）          │
│ ow_pricing    │               │                            │
└───────────────┴───────────────┴────────────────────────────┘
```

**依赖方向**：上层依赖下层的接口，接口都定义在 `ow_domain`。`ow_data`、`ow_vault`、`ow_platform` 互不依赖。

**多端扩展的三条保证**

1. **业务逻辑与平台无关**：`ow_domain`、`ow_application`、`ow_vault`、`ow_chains`、`ow_exchanges`、`ow_pricing` 都是纯 Dart 包，不引用 Flutter，也不引用 `dart:io` 之外的平台 API。它们在任何 Flutter 支持的平台上都能直接运行，将来做命令行工具也能复用。
2. **平台能力走接口加能力声明**：所有平台差异收敛到 `ow_platform`。每项能力有一个接口和一个"是否支持"的查询，界面根据查询结果降级（PRD 7.3）。

```dart
abstract interface class PlatformCapabilities {
  bool get hardwareKeystore;      // 硬件密钥
  bool get biometrics;            // 生物识别
  ScreenProtection get screenProtection; // block / detect / none
  bool get camera;                // 扫码
}

abstract interface class HardwareKeyStore {
  /// 用硬件密钥包裹一段数据；unwrap 时要求用户在场验证
  Future<Uint8List> wrap(String keyAlias, Uint8List plaintext);
  Future<Uint8List> unwrap(String keyAlias, Uint8List wrapped, {required String reason});
  Future<void> delete(String keyAlias);
}

abstract interface class SecretStore {       // 存 API Secret 等
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
}

abstract interface class ScreenGuard {       // 敏感页面保护
  Future<void> enable();
  Future<void> disable();
  Stream<bool> get captureActive;           // 是否正在录屏或投屏
}

abstract interface class FileExporter {      // 手机用分享面板，桌面用另存为
  Future<bool> export(String suggestedName, Uint8List bytes);
  Future<Uint8List?> pick(List<String> extensions);
}
```

3. **界面响应式**：页面内容与导航外壳分离。`AdaptiveScaffold` 按宽度断点（600、1024）选择底部 Tab、图标侧栏或文字侧栏；列表详情类页面用统一的 `ListDetailLayout`，窄屏时逐级进入，宽屏时并排显示。v1.0 只实现并测试窄屏分支，但页面从一开始就写在这两个组件之内。

**新增一个平台时要做的事**：在 `ow_platform` 中实现上述接口；在 `app/` 中补充该平台的工程配置；检查中屏和宽屏布局。其余代码不动。

### 3.3 目录结构

```
OneWallet/
├─ app/                          # Flutter 应用（唯一依赖 Flutter 界面的地方）
│  ├─ lib/
│  │  ├─ main.dart
│  │  ├─ bootstrap/              # 依赖装配、启动流程
│  │  ├─ router/
│  │  ├─ theme/
│  │  ├─ shell/                  # AdaptiveScaffold、ListDetailLayout
│  │  ├─ features/
│  │  │  ├─ lock/                # P00
│  │  │  ├─ onboarding/          # P01
│  │  │  ├─ overview/            # P02、P09
│  │  │  ├─ accounts/            # P03–P08、P10
│  │  │  ├─ backup_checklist/    # P11
│  │  │  ├─ vault/               # P12–P16
│  │  │  ├─ backup_file/         # P17
│  │  │  └─ settings/            # P18–P22
│  │  ├─ widgets/                # 通用组件
│  │  └─ l10n/
│  ├─ ios/  android/             # v1.0
│  └─ macos/ windows/ linux/     # 后续添加
├─ packages/
│  ├─ ow_domain/                 # 实体、接口、规则（纯 Dart）
│  ├─ ow_application/            # 用例
│  ├─ ow_data/                   # Drift 数据库、仓储实现
│  ├─ ow_chains/                 # 各链适配器
│  ├─ ow_exchanges/              # 各交易所适配器
│  ├─ ow_pricing/                # 价格与币种映射
│  ├─ ow_vault/                  # 保险库核心（禁止网络依赖）
│  └─ ow_platform/               # 平台适配（Flutter 插件，含 Swift、Kotlin）
├─ tools/
│  ├─ backup_decrypt/            # 独立的备份解密工具
│  └─ ci/                        # 依赖边界检查等脚本
└─ docs/
```

每个 feature 目录内部：`presentation/`（页面与组件）、`controllers/`（Riverpod 控制器，调用用例）。feature 之间不直接互相引用，共享内容下沉到 `widgets/` 或应用层。

## 4. 状态与数据模型

### 4.1 领域实体

```
Account            id, type(wallet|exchange), name, color, source, note,
                   exchange?(binance|okx|bybit|bitget), secretRef?, vaultItemId?,
                   backup: BackupStatus, createdAt
BackupStatus       inVault(由 vaultItemId 推出), offlineBackedUp, offlineVerifiedAt?,
                   keyless(无助记词钱包)
Address            id, accountId, chainFamily(evm|bitcoin|solana|tron),
                   address, enabledChains[], derivationPath?, note
Asset              id(标准币种，如 "USDT"), symbol, name, iconRef, priceId
AssetMapping       source(chainId+contract 或 exchange+symbol) -> assetId
Holding            accountId, location(链 id 或交易所子账户), assetId 或 rawTokenRef,
                   amount(Decimal), updatedAt
Price              assetId, quote(USD|CNY), price, change24h, updatedAt
Snapshot           date, totalUsd, complete(bool), byAccount{...}, byAsset{...}
VaultItemMeta      id, name, kind(mnemonic|privateKey), wordCount?, chainFamily?,
                   hasPassphrase, fingerprint(用于查重), createdAt
SyncRecord         accountId, startedAt, finishedAt, status, errorCode?
```

- 金额一律用任意精度十进制类型，禁止用 `double`。
- `VaultItemMeta` 不含任何密钥内容，存在主数据库；密文存在保险库文件。`fingerprint` 是密钥内容的带密钥哈希（HMAC，密钥来自保险库主密钥），用于查重而不泄露内容。

### 4.2 数据库表

`accounts`、`addresses`、`assets`、`asset_mappings`、`holdings`、`prices`、`snapshots`、`snapshot_items`、`vault_items_meta`、`sync_records`、`settings`、`token_visibility`。

- 数据库迁移使用 Drift 的版本化迁移，每次变更附带迁移测试。
- `addresses` 上对 `(chainFamily, address 规范化形式)` 建唯一索引（PRD R2）。EVM 地址以小写存储，显示时转 EIP-55。

### 4.3 界面状态

- 每个页面一个控制器，状态为不可变对象，统一用 `AsyncValue` 表达加载、数据、错误。
- 全局状态：锁定状态、隐藏金额开关、计价货币、同步进度。
- 锁定状态为"已锁定"时，路由层强制重定向到 P00，且数据库连接关闭。

## 5. 核心逻辑与算法

### 5.1 适配器接口

```dart
abstract interface class ChainAdapter {
  ChainFamily get family;
  List<ChainInfo> get chains;                 // EVM 适配器返回六条链
  bool isValidAddress(String input);
  String normalize(String address);
  Future<List<RawHolding>> fetchHoldings(String address, ChainInfo chain);
  Future<bool> hasActivity(String address, ChainInfo chain);  // P16 检测余额
}

abstract interface class ExchangeAdapter {
  ExchangeId get id;
  List<CredentialField> get credentialFields; // key、secret、passphrase
  Future<CredentialCheck> verify(ExchangeCredentials c); // 连通性与权限
  Future<List<RawHolding>> fetchHoldings(ExchangeCredentials c);
  Future<List<DepositAddress>> fetchDepositAddresses(ExchangeCredentials c);
}

abstract interface class PriceSource {
  Future<Map<AssetId, Price>> fetchPrices(Set<AssetId> assets, Quote quote);
}
```

适配器通过注册表集中登记；上层只面向接口和注册表。新增链或交易所的步骤写在 `DEV_GUIDELINES` 第 9 节。

### 5.2 同步流程

```
SyncAll
 ├─ 为每个账户创建独立任务（并发上限 4；同一服务商的请求串行并限速）
 │    钱包账户：对每个 地址×链 调 ChainAdapter.fetchHoldings
 │    交易所账户：ExchangeAdapter.fetchHoldings
 ├─ RawHolding → 归一化（查 AssetMapping）→ Holding
 ├─ 单个账户成功：在一个事务内替换该账户的全部 Holding
 │  单个账户失败：保留旧数据，写 SyncRecord
 ├─ 汇总所需币种 → PriceSource.fetchPrices
 └─ 写当日 Snapshot（PRD R16）
```

- 重试：对限频（HTTP 429）和网络错误做指数退避，最多 3 次。
- 取消：离开前台时取消未完成的请求。

### 5.3 归一化与估值

- 内置映射表 `asset_mappings.json`：主流币种在各链的合约地址、各交易所的符号别名。
- 查找顺序：内置映射 → 价格服务按合约地址查询 → 未识别（PRD R8、R10）。
- 估值、占比、24 小时变化的计算都是 `ow_domain` 中的纯函数，带单元测试。

### 5.4 地址派生

- 标准：BIP39（助记词到种子）、BIP32（secp256k1 分层派生，用于 EVM、Bitcoin、Tron）、SLIP-0010（ed25519，用于 Solana）、BIP44/49/84/86（路径约定）。
- 地址编码：EVM 为 Keccak-256 加 EIP-55；Bitcoin 为 Base58Check、Bech32、Bech32m；Tron 为 Base58Check（前缀 0x41）；Solana 为公钥的 Base58。
- **库的选择在 M0 决定**。候选：(a) Trust Wallet Core 的原生库经 FFI 调用；(b) 维护活跃的纯 Dart 库组合。评估标准：是否有审计或被广泛使用、维护状况、全平台可用性（含桌面端）、依赖数量。无论选哪种，都必须通过全部官方测试向量，并与至少三款主流钱包的真实派生结果对照。
- 派生在独立的 isolate 中执行，结束后清除种子和私钥，只把地址返回主 isolate。

## 6. 持久化、网络与外部集成

### 6.1 本地存储

| 内容 | 位置 | 保护 |
|---|---|---|
| 主数据库 | 应用私有目录，SQLCipher | 数据库密钥随机生成，存入系统安全存储，应用解锁后读取 |
| 保险库文件 | 应用私有目录，独立文件 | 见 SECURITY_DESIGN |
| API Key 与 Secret | 系统安全存储（Keychain、Keystore） | 仅本设备，不随系统备份 |
| 普通偏好 | 主数据库 `settings` 表 | — |

iOS 上对数据库和保险库文件设置"排除出 iCloud 与 iTunes 备份"；Android 上在清单中关闭自动备份并排除相关目录。

### 6.2 外部服务（建议方案，均可在 P20 更换）

| 用途 | 建议服务 | 是否需要 Key | 备注 |
|---|---|---|---|
| EVM 余额与代币发现 | Alchemy（或同类索引服务） | 需要，免费档 | 代币发现依赖索引服务；纯 RPC 只能查已知代币 |
| Bitcoin | mempool.space 或 Blockstream 的 Esplora 接口 | 不需要 | 可自定义实例地址 |
| Solana | 官方公共 RPC 或 Helius | 公共节点不需要 | 公共节点限频较严 |
| Tron | TronGrid | 建议配置 | — |
| 价格与币种信息 | CoinGecko | 免费档可不配 | 限频较严，需本地缓存 |
| 交易所 | Binance、OKX、Bybit、Bitget 官方 REST API | 用户的只读 Key | 直接用 Dart 实现签名（HMAC-SHA256） |

- 各服务的具体接口路径、限频和免费额度在对应里程碑开工时按官方文档核对，不在本文固定。
- 交易所适配器只实现读取类接口。代码中不出现任何下单、划转、提现接口的路径（由 CI 检查，见 DEV_GUIDELINES）。
- 手机 IP 不固定，无法使用 IP 白名单。部分交易所对未绑定 IP 的 Key 有有效期限制，需正确识别"Key 已失效"并引导更换（PRD P08）。

### 6.3 网络层

- 统一的 HTTP 客户端工厂，按服务商配置基础地址、超时、限速器、重试。
- 日志拦截器对请求头和参数做脱敏：API Key 只保留前 4 位，签名与 Secret 完全不记录。
- 只允许 HTTPS。
- `ow_vault` 包不依赖任何网络库；`ow_platform` 中的保险库相关代码同样不联网。

## 7. 安全与隐私

详见 `SECURITY_DESIGN_v1.0.md`。本文只列与架构相关的要点：

1. 保险库是独立的包，其依赖清单受 CI 白名单约束。
2. 看板的联网代码路径只能拿到地址，拿不到密钥：派生在保险库内完成，对外只输出地址。
3. 应用锁定时，数据库关闭、内存中的敏感状态清空。
4. 没有统计、广告、崩溃上报等第三方 SDK。

## 8. 测试策略

| 层级 | 内容 | 工具 |
|---|---|---|
| 单元测试 | 领域规则、归一化、估值、地址校验、派生（官方测试向量）、加解密往返、备份格式 | `dart test` |
| 适配器测试 | 用录制的响应样本测试解析；签名算法用各交易所文档中的示例验证 | `dart test` + 样本文件 |
| 数据库测试 | 仓储读写、迁移 | Drift 内存数据库 |
| 组件测试 | 关键页面的状态渲染（空、加载、错误） | `flutter test` |
| 集成测试 | 首次引导、添加地址到总览、入库到派生、导出到恢复 | `integration_test` |
| 真机专项 | 硬件密钥、生物识别变更、防截屏、系统备份排除、换机 | 手工清单（SECURITY_DESIGN 第 8 节） |
| 互操作测试 | App 导出的备份文件由独立解密工具解开，结果一致 | CI 脚本 |

覆盖率要求：`ow_domain`、`ow_vault` 不低于 90%；其他包不低于 70%。

## 9. 未决问题

| 编号 | 问题 | 何时决定 |
|---|---|---|
| T1 | 地址派生库的选择 | M0 |
| T2 | 硬件密钥插件自己写还是用现成的 Flutter 插件 | M0；倾向自己写最小实现，见 ADR_003 |
| T3 | EVM 数据服务最终选哪家 | M1 |
| T4 | 桌面端保险库的硬件支持程度（各系统差异大） | 做桌面端时 |
| T5 | 独立解密工具用什么语言 | M5；倾向 Python 单文件脚本加 Dart 命令行两种 |
