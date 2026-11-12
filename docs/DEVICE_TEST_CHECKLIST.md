# 真机整体测试清单

> 开发期间不做逐任务的真机验证。每个任务把"只经过自动化测试、还没在真机上验证"的项目追加到这里，全部开发完成后由用户用真机整体测一遍。
> 测试通过的项目打勾并写日期；不通过的记下现象，开任务修复。
> 不要在本文件中写入真实助记词、私钥、API Key 或完整的个人地址。

## 使用方法

1. 在装有 Flutter 3.47.9 的电脑上连接手机，执行 `cd app && flutter run --release`（iOS 需要 Mac 与 Xcode）。
2. 按下面的分节逐项操作。
3. 最后做 `SECURITY_DESIGN_v1.0.md` 第 8 节的全部项目和 `PRD_v1.0.md` 第 11 节的全部验收标准。

## 0. 构建

- [ ] Android 能构建并启动（任务 M0-10）
- [ ] iOS 能构建并启动（任务 M0-10）
- [ ] 四个 Tab 可切换，浅色与深色显示正常

（各任务在下面追加自己的小节。）

## 1. EVM 链数据（任务 M1-06、M1-17）

接口已对照 Alchemy 官方文档核对（主机名、Key 位置、参数、返回字段、限频），详见 `docs/EXTERNAL_APIS.md`。以下几项文档里读不到，只能用真实 Key 确认。

冒烟脚本：在 `packages/ow_chains` 目录执行 `OW_ALCHEMY_KEY=<Key> dart run tool/smoke_evm.dart <地址> [链id]`。

- [ ] 六条链各跑一次，代币余额都能取到（确认代币接口在每条链都可用，尤其是 BNB Chain）
- [ ] 脚本输出的余额与区块浏览器一致
- [ ] 找一个代币超过 100 种的地址，确认能翻页取全（响应里的翻页字段名文档未写明）
- [ ] 观察从未交互过的空投代币是否出现在结果里
- [ ] 免费额度用尽时界面显示什么（目前会与"Key 无效"显示成同一种错误）

## 2. 币种映射与价格（任务 M1-03、M1-04、M1-17）

价格接口已对照 CoinGecko 官方文档核对。合约地址主要取自 Uniswap 维护的代币列表（第三方），没有逐个对照发行方文档；合约地址错了会把假币当真币估值。

冒烟脚本：在 `packages/ow_pricing` 目录执行 `dart run tool/smoke_price.dart`（Key 可选，环境变量 `OW_COINGECKO_KEY`）。

- [ ] 复核 `packages/ow_pricing/SOURCES.md`：至少 USDT、USDC、DAI、WETH、WBTC 在各链的全部合约，对照发行方官方文档或区块浏览器的认证页
- [ ] 运行 `cd packages/ow_pricing && dart run tool/smoke_price.dart`，能打印 BTC、ETH、USDT 的价格
- [ ] 运行 `dart run tool/smoke_price.dart --catalog`，映射表中每个币种都能取到价格（重点看 POL、SNX、COMP）
- [ ] 对照 CoinGecko 官方文档复核 `docs/EXTERNAL_APIS.md` 的"CoinGecko（价格）"一节中标"未核对"的项

## 3. 存储与启动（任务 M0-13）

开发环境没有模拟器和真机，无法构建 iOS 与 Android。下面各项只经过桌面（Linux）上的自动化测试：SQLCipher 的加密与重开、启动流程的各分支、安全存储的前缀逻辑。`SecureSecretStore`（钥匙串、Keystore）和 `SqlCipherDatabaseOpener` 的原生部分**只能在设备上验证**。选型与理由见 `docs/ADR_006_SQLCipher接入.md`。

### 3.1 功能

- [ ] Android 能构建并启动，进入四个 Tab（确认 SQLCipher 预编译库被取到并链接；构建机需要能访问 GitHub Releases）
- [ ] iOS 能构建并启动，同上
- [ ] 首次启动没有错误页；杀掉进程再启动，应用正常进入（密钥被复用）
- [ ] 重启应用后数据仍在（M1 页面可用后：添加账户，杀进程，重启，账户还在）
- [ ] 从设备导出 `onewallet.db`（Android 调试构建用 `adb exec-out run-as <应用标识> cat files/onewallet.db`；iOS 用 Xcode 的 Download Container），用普通 `sqlite3` 命令行打开，执行 `.tables` 报 "file is not a database"；用十六进制查看，头部不是 `SQLite format 3`
- [ ] 卸载重装后旧数据不回来：重装后账户列表为空（Android 无残留；iOS 需确认首次启动清理了钥匙串中的 `ow.` 条目，并且数据库是新的）
- [ ] 数据库文件在、安全存储里的 `ow.db.key` 不在的情形（可用调试构建临时删除该键构造）：显示"无法打开本地数据"错误页，点"重试"不会重建数据库，数据库文件字节不变
- [ ] 设备重启后、首次解锁之前，若应用被后台唤起读取安全存储，不应崩溃；如果出现 `secureStorageFailed` 错误页，记下复现条件

### 3.2 系统备份

- [ ] Android：执行 `adb shell bmgr backupnow <应用标识>` 后检查，备份中不含应用数据；Android 12 及以上用设备迁移（"复制应用和数据"）验证 `dataExtractionRules` 的效果
- [ ] iOS：做一次 iCloud 或电脑备份并恢复到另一台设备，应用数据为空（`isExcludedFromBackup` 尚未实现，见 3.3；在它实现之前，预期结果是恢复后出现"密钥缺失"错误页，而不是静默重建）
- [ ] 钥匙串条目带 `ThisDeviceOnly`、不同步 iCloud 钥匙串：用另一台登录同一 Apple ID 的设备确认读不到

### 3.3 未编译、未验证的原生配置（逐项审阅）

这些改动没有经过任何一次 Android 或 iOS 构建：

- [ ] `app/android/app/src/main/AndroidManifest.xml`：新增 `INTERNET` 权限、`allowBackup="false"`、`fullBackupContent="false"`、`dataExtractionRules`、`usesCleartextTraffic="false"`
- [ ] `app/android/app/src/main/res/xml/data_extraction_rules.xml`：云备份与设备迁移的排除域是否全部有效（构建时 `aapt` 有无报错）
- [ ] `flutter_secure_storage` 11.2.0 在 Android 上的 `minSdk` 要求与当前工程是否冲突；构建期有无需要手工改的 Gradle 配置
- [ ] `flutter_secure_storage` 在 iOS 上的 `KeychainAccessibility.first_unlock_this_device` 与 `synchronizable: false` 实际写入的钥匙串属性（应为 `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`，`kSecAttrSynchronizable` 为否）
- [ ] `AndroidOptions(resetOnError: false)`：确认出错时抛异常而不是清空；换新的屏幕锁、恢复出厂等情形下的表现
- [ ] 根 `pubspec.yaml` 的 `hooks.user_defines.sqlite3.source: sqlcipher` 在 `flutter build apk`、`flutter build ios` 中生效（桌面的 `flutter test` 已确认生效）
- [ ] iOS 的 `isExcludedFromBackup` **尚未实现**，待 M0-11 的原生插件一并完成：数据库文件（`onewallet.db` 及其 `-wal`、`-shm`）和将来的保险库文件都要设置。完成后在这里补验证项
- [ ] `DevicePlatformCapabilities` 的静态值（`hardwareKeystore=false`、`biometrics=false`、`screenProtection`、`camera`）是占位，M0-11、M3-02 改为真实探测后复核

- [ ] 脚本能打印 BTC、ETH、USDT 的价格（同时确认 `precision=full` 参数被接受）
- [ ] 运行 `dart run tool/smoke_price.dart --catalog`，映射表中每个币种都能取到价格（重点看 POL、SNX、COMP；币种标识大部分未能核对）
- [ ] 持有一个不在内置表里的 Arbitrum、Optimism、Base 代币时能识别并估值（这三条链在 CoinGecko 的平台标识未能核对）
- [ ] 被限频时界面显示"请求过于频繁"而不是未知错误

## 4. 第三方目录的链接（任务 M1-14）

目录中多数链接只依据搜索结果摘要确认了域名，没有逐个打开页面。应用只展示已核对的条目。

- [ ] 在应用里逐个点开四家交易所的"如何创建 API Key"与"API Key 管理"链接，页面存在且是官方站点
- [ ] 点开五个来源钱包的"导出助记词或私钥"指引，页面存在且内容对应
- [ ] 九条链的"在区块浏览器中打开"都能跳到正确的地址页（重点看 Tron：地址页的网址格式有新旧两种写法）

## 5. Bitcoin、Solana、Tron 链数据（任务 M2-01 至 M2-03）

### 5.1 Bitcoin（mempool.space）

接口已对照官方文档与公共接口的真实响应核对（路径、字段名、四种地址类型），详见 `docs/EXTERNAL_APIS.md`"mempool.space（Bitcoin）"。

冒烟脚本：在 `packages/ow_chains` 目录执行 `dart run tool/smoke_btc.dart <地址> [自定义实例]`（无需 Key）。

- [ ] 用自己的 P2PKH、P2SH、bech32、bech32m 地址各跑一次（没有的类型跳过），余额与区块浏览器显示的**已确认**余额一致
- [ ] 地址有未确认的转入或转出时，本应用只显示已确认部分（这是有意的口径，与浏览器网页的"含未确认"总额可能不同）
- [ ] 公共实例的限频具体数值文档未给：连续同步十几个地址，确认不会频繁出现"请求过于频繁"
- [ ] 配置一个自建的 mempool 或 Esplora 兼容实例作为自定义节点（含路径前缀的情形），余额能取到

### 5.2 Solana（Helius 与官方公共节点）

接口参数与返回结构已对照 Helius 文档核对；**Solana 官方文档（solana.com）当时对非浏览器客户端返回 429，未能读取**。详见 `docs/EXTERNAL_APIS.md`"Solana RPC"。

冒烟脚本：在 `packages/ow_chains` 目录执行 `OW_HELIUS_KEY=<Key> dart run tool/smoke_sol.dart <地址>`；不设 `OW_HELIUS_KEY` 时走官方公共 RPC（Key 可缺省）。

- [ ] 用一个持有 SOL、USDC、至少一种其他代币的地址跑一次，余额与 Solscan 一致（代币只显示缩略 mint，符号由币种目录识别）
- [ ] 用一个同一代币有多个代币账户的地址，确认数量是各账户之和
- [ ] 用一个持有 Token-2022 代币（如 PYUSD）的地址，确认能取到
- [ ] 用一个持有 NFT 的地址，确认 NFT 不出现在结果里
- [ ] **官方公共节点（未能核对）**：不设 Key 直接跑一次，确认主机名 `api.mainnet-beta.solana.com` 可用；记录它对 `getTokenAccountsByOwner` 的限频与使用限制，反复运行几次观察是否被限频或拒绝
- [ ] **Helius**：设 Key 跑一次，确认 Key 放在 `api-key` 查询参数可用；运行时打开日志，确认日志中 Key 只保留前 4 位
- [ ] 一个代币账户数量上千的大钱包，确认响应没有超时（v1 不分页，`getTokenAccountsByOwnerV2` 未使用）
- [ ] 质押在验证者上的 SOL 不计入余额（有意的口径），与 Solscan 的"总价值"对照时留意这一差异

### 5.3 Tron（TronGrid）

接口已对照 TronGrid 官方文档（含 OpenAPI 定义）核对；**未能访问 `api.trongrid.io`，没有真实响应验证**。详见 `docs/EXTERNAL_APIS.md`"TronGrid（Tron）"。

冒烟脚本：在 `packages/ow_chains` 目录执行 `OW_TRONGRID_KEY=<Key> dart run tool/smoke_tron.dart <地址>`（Key 可缺省）。

- [ ] 用一个持有 TRX 和 USDT 的地址跑一次，TRX 与 USDT 余额和 Tronscan 一致
- [ ] **质押口径（未能核对）**：用一个有 Stake 2.0 质押的地址，TRX 数量 = 可用 + 质押（含解锁等待中）；再用一个**把资源委托给他人**的地址，确认委托出去的 TRX 没有重复计入，也没有漏掉（`frozenV2` 是否已扣除委托部分文档未写明）
- [ ] 用一个仍有 Stake 1.0 冻结余额的老地址，确认差异：本应用不计 Stake 1.0 的质押，需要告知用户或补充实现
- [ ] 有未领取投票奖励的地址，确认奖励（`allowance`）不计入余额（有意的口径）
- [ ] 持有不在内置表中的 TRC-20（任选一个小币）：能通过合约信息接口取到 decimals 并换算正确；取不到时被跳过而不是报错
- [ ] 持有超过 200 种 TRC-20 的地址（可选）：确认 `fingerprint` 翻页能取全
- [ ] 未激活的新地址：显示零余额，不报错（空数组之外是否有其他响应形式未能核对）
- [ ] **无 Key** 直接跑一次，记录是否被拒绝或限频（官方只说"可能严格限频或拒绝"）；设 Key 后再跑一次，日志中 Key 只保留前 4 位
- [ ] 连续同步多个 Tron 地址，确认默认的每秒 3 次不会触发 429（具体限额文档未给）
