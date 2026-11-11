# OneWallet 任务清单

> 这是执行用的任务表。里程碑的背景与门禁见 `DEVELOPMENT_PLAN_v1.0.md`；怎么做见 `EXECUTION_GUIDE.md`。
> 每个任务完成后，执行者把状态改为 `[x]`，并在行尾写上完成日期。被卡住时改为 `[!]` 并写明原因。

## 读法

**状态**：`[ ]` 未开始　`[~]` 进行中　`[x]` 完成　`[!]` 受阻

**环境标签**

| 标签 | 含义 |
|---|---|
| 〔离线〕 | 任何装了 Flutter 的环境都能完成并验收，不需要设备、不需要密钥 |
| 〔设备〕 | 需要模拟器或真机才能验收（原生代码、构建、平台行为） |
| 〔真机〕 | 必须是实体手机（硬件密钥、生物识别、性能） |
| 〔用户〕 | 需要用户提供东西或亲手操作（API Key、核对余额、测试钱包） |

**真机验收统一后置（2026-11-11 用户决定）**：开发期间不做逐任务的真机验证。带〔设备〕〔真机〕标签的任务，把代码和自动化测试做完即可标 `[x]`，并把还没在真机上验证的项目追加到 `docs/DEVICE_TEST_CHECKLIST.md`。全部开发完成后，由用户用真机按该清单整体测一遍。

- 这不改变"不得把未验证的东西说成已验证"：汇报和清单里要写明哪些只经过了自动化测试。
- 原生代码（Swift、Kotlin）在没有设备的环境里无法编译验证，必须在清单中单独标出"未编译"。
- 〔用户〕标签的事项（真实 API Key、余额核对、测试钱包对照）同样记入清单，不阻塞开发。

**依赖**：列出的任务必须先完成。没有列依赖的任务，只依赖同一里程碑中排在它前面的任务。

**每个任务的通用验收**（不再逐条重复）：`tools/check.sh` 全部通过；新逻辑有测试；文案在 ARB；相关文档已同步。

---

## M0 工程基础与技术验证

- [x] **M0-01** 工作区与各包骨架 〔离线〕 2026-11-10
- [x] **M0-02** 静态检查、格式化、CI 配置、`tools/check.sh` 〔离线〕 2026-11-10
- [x] **M0-03** 依赖边界检查脚本 〔离线〕 2026-11-10
- [x] **M0-04** 响应式外壳与四个空 Tab 〔离线〕 2026-11-10
- [x] **M0-05** 颜色令牌与浅深主题 〔离线〕 2026-11-10
- [x] **M0-06** 技术验证一：地址派生（ADR_004） 〔离线〕 2026-11-10

- [x] **M0-07** 打包字体 〔离线〕 2026-11-11
  - 做什么：把 IBM Plex Sans（400、500、600）和 IBM Plex Mono（400、500、600）放入 `app/assets/fonts/`，在 `pubspec.yaml` 注册；主题中正文用 Plex Sans 并以系统中文字体为后备，新增 `OwTextStyles.mono`（等宽数字）。
  - 依据：UI_DESIGN_SYSTEM 第 3 节。字体为 SIL OFL 许可，把许可文件一并放入。
  - 验收：组件测试断言 `OwAmountText` 使用等宽字体族。

- [x] **M0-08** 通用组件库 〔离线〕 2026-11-11
  - 做什么：实现 IMPLEMENTATION_SPEC 7.2 列出的 `Ow*` 组件（`OwMnemonicGrid`、`OwVeil`、`OwNetWorthChart` 除外，分别留到 M4 和 M3），以及 `formatters.dart`、`failure_text.dart`。
  - 依据：UI_DESIGN_SYSTEM 第 4、5 节；`docs/prototype.html`；IMPLEMENTATION_SPEC 7.3、7.4。
  - 验收：每个组件有浅色和深色下的组件测试；`formatters` 的单元测试覆盖 7.3 表中每一行，包括极小值、零、隐藏金额。

- [x] **M0-09** 领域模型与接口 〔离线〕 2026-11-11
  - 做什么：按 IMPLEMENTATION_SPEC 第 2、3 节在 `ow_domain` 中补全全部类型和接口（已存在的不动）。加入 `decimal` 依赖。实现 `Chains` 内置链表、`AddressCodec` 的格式判断部分、`Account.backupLevel`。
  - 验收：`Chains.all` 恰好 9 条且与规格表一致；`backupLevel` 对 R34、R35 的每种组合有测试；`AddressCodec.detectFamily` 对每个家族的合法与非法样例有测试。

- [ ] **M0-10** 空壳在模拟器或真机上启动 〔设备〕〔用户〕
  - 做什么：在 iOS 和 Android 上执行 `cd app && flutter run`，确认四个 Tab 可切换、浅深色正常。把应用显示名设为 OneWallet；Android 的 `applicationId` 与 iOS 的 Bundle Identifier 向用户确认后设置（当前为 `app.onewallet.onewallet`）。
  - 验收：两个平台各一张截图，存入 `docs/evidence/M0-10/`。

- [ ] **M0-11** 技术验证二：硬件密钥插件 〔真机〕
  - 做什么：在 `ow_platform` 中实现 `HardwareKeyStore` 的 iOS（Swift）与 Android（Kotlin）最小实现，以及 `PlatformCapabilities`。
  - 依据：SECURITY_DESIGN 6.1；ADR_003。只用系统自带的安全框架。
  - 验收：在两台真机上逐项验证并把结果写入 `docs/evidence/M0-11.md`：包裹与解包成功；解包时出现系统生物识别；新增一枚指纹或面容后旧包裹失效；关闭锁屏密码后不可用；卸载重装后的行为。结论回填 SECURITY_DESIGN 6.1 与第 11 节 S4。

- [ ] **M0-12** 技术验证三：libsodium 接入与 Argon2id 定标 〔真机〕
  - 做什么：确认 `sodium` 包在 iOS、Android 以及运行单元测试的主机上的接入方式；写一个只在调试构建中可见的测速页，测量 Argon2id 在内存 32、64、128、256 MiB，迭代 2、3、4 下的耗时。
  - 验收：两台真机的耗时表写入 `docs/evidence/M0-12.md`；选定保险库与备份文件的参数（目标：保险库解锁 1–2 秒），回填 SECURITY_DESIGN 第 4 节和第 11 节 S1；把 `sodium` 加入 `check_deps.dart` 的保险库白名单并写 ADR_005。

- [ ] **M0-13** 数据库与安全存储打通 〔设备〕
  - 做什么：`ow_platform` 实现 `SecretStore`（iOS 钥匙串、Android Keystore 保护的存储，均设为仅本设备）；`app/lib/bootstrap/` 中生成随机数据库密钥存入 `SecretStore`，用 SQLCipher 打开 `onewallet.db` 并注入 `ow_data`；两个平台都把数据库和保险库文件排除出系统备份。SQLCipher 的具体接入包在本任务中确认并记入 ADR_006。
  - 依据：TECH_DESIGN 6.1；IMPLEMENTATION_SPEC 第 5 节。
  - 验收：从设备导出的数据库文件无法用普通 SQLite 工具打开；重启应用后数据仍在；证据写入 `docs/evidence/M0-13.md`。

M0 门禁（已按上面的决定调整）：M0-11、M0-12 的代码完成后即可开始 M4，真机结论在整体测试时补。在真机定标之前，Argon2id 使用 SECURITY_DESIGN 第 11 节 S1 的默认参数。

---

## M1 核心循环

目标：添加一个 EVM 地址，在总览看到资产。

- [ ] **M1-01** 数据库表与仓储（账户、地址、持仓、价格、设置、同步记录） 〔离线〕
  - 做什么：在 `ow_data` 用 Drift 建 IMPLEMENTATION_SPEC 第 5 节中 M1 需要的表，实现 3.1 中对应的仓储。
  - 依赖：M0-09。
  - 验收：仓储测试用内存数据库，覆盖：地址唯一约束（R2）；删除账户的级联（R6）；`replaceForAccount` 的事务性（中途失败不留下半截数据）；金额以字符串往返后精度不变。

- [ ] **M1-02** 地址校验和与 EVM 地址编解码 〔离线〕
  - 做什么：`ow_chains` 实现 `AddressChecksum`（EIP-55、Base58Check、Bech32 与 Bech32m），接入 `AddressCodec`。
  - 依据：PRD R4。
  - 另外两项（M0-09 审查时发现）：一、给 `AddressCodec` 增加实例方法 `detect(input)`：按 EVM、Tron、Bitcoin、Solana 的顺序，返回第一个**格式与校验和都通过**的家族，用来消除 `T`、`1`、`3` 开头的 Solana 地址被误判的歧义；界面一律用它而不是静态的 `detectFamily`。二、Bitcoin 的 bech32 地址接受全大写形式（BIP173 允许），`normalize` 把它转为小写；大小写混用的拒绝。
  - 验收：EIP-55 用 EIP 文档中的测试地址；全小写 EVM 地址被接受；校验和错误的各类地址被拒绝；Bitcoin 四种前缀、Solana、Tron 各有合法与非法样例。

- [ ] **M1-03** 内置币种映射表与 `AssetCatalog` 〔离线〕
  - 做什么：`ow_pricing` 内置 `asset_mappings.json`：9 条链的原生币，以及 USDT、USDC、DAI、WETH、WBTC 等不少于 30 个主流代币在各链的合约地址与价格源标识。实现 `AssetCatalog`。
  - 依据：PRD R8；TECH_DESIGN 5.3。合约地址逐个对照各项目官方文档或区块浏览器的认证页面，并在 JSON 旁的 `SOURCES.md` 记录出处。
  - 验收：同一币种的多链合约解析到同一个 `Asset`；未知合约返回 null；JSON 加载有结构校验测试。

- [ ] **M1-04** 价格源 〔离线〕＋〔用户〕冒烟
  - 做什么：`ow_pricing` 实现基于 CoinGecko 的 `PriceSource`（按标识查价、按合约查代币）。带本地缓存时效（5 分钟内不重复请求）。
  - 依据：IMPLEMENTATION_SPEC 第 8 节（先写 `EXTERNAL_APIS.md` 的对应小节）。
  - 验收：用录制样本测试解析、限频映射为 `RateLimitedFailure`、网络错误映射；`tools/smoke/price.dart` 可手动运行。

- [x] **M1-05** 网络基础设施 〔离线〕 2026-11-11
  - 做什么：在一个新的纯 Dart 包 `ow_net` 中提供 HTTP 客户端工厂（超时、仅 HTTPS、脱敏日志拦截器）、`RateLimiter`、统一的 HTTP 状态到 `Failure` 的映射。把 `ow_net` 加入工作区和 `check_deps.dart` 的规则（`ow_chains`、`ow_exchanges`、`ow_pricing` 可依赖它；`ow_vault` 不可）。同步更新 TECH_DESIGN 3.2、3.3 与 DEV_GUIDELINES 第 2 节的表。
  - 验收：日志拦截器测试断言输出中不含完整 API Key、签名、Secret；`http://` 地址被拒绝。

- [ ] **M1-06** EVM 链适配器 〔离线〕＋〔用户〕冒烟
  - 做什么：`ow_chains` 实现 EVM 的 `ChainAdapter`：原生币余额、代币余额与元数据。先支持 `ethereum`，再用配置扩到其余 5 条链。数据服务按 TECH_DESIGN 6.2 的建议，Key 从 `DataSourceConfig` 读取。
  - 依赖：M1-05。
  - 验收：录制样本测试覆盖：正常、零余额、大量代币、十六进制大数换算为 `Decimal`、缺 Key 时返回明确的失败；`tools/smoke/evm.dart <地址>` 可手动运行并打印持仓。

- [ ] **M1-07** 同步用例 〔离线〕
  - 做什么：`ow_application` 实现 `SyncAccount`、`SyncAllAccounts`、`RetryPolicy`；归一化（`RawHolding` → `Holding`）；同步后拉取价格。
  - 依据：PRD R13、R15、R17；TECH_DESIGN 5.2。
  - 验收：用假的适配器测试：部分账户失败时其余正常且失败者保留旧数据并写 `SyncRecord`；限频时按 1、2、4 秒退避最多 3 次（用假时钟）；并发不超过 4；未识别代币 `assetId` 为空。

- [ ] **M1-08** `PortfolioCalculator` 〔离线〕
  - 依据：PRD R7–R12；IMPLEMENTATION_SPEC 2.4。
  - 验收：单元测试覆盖：多链同币合并；无价格的币不计入总额并计数；小额隐藏开关；手动隐藏；按账户与按类型汇总之和等于总额；空输入。

- [ ] **M1-09** 添加钱包账户（P04、P05 的 EVM 部分） 〔离线〕
  - 做什么：`AddWalletAccount`、`AddAddressesToAccount` 用例；P04、P05 页面与控制器。
  - 验收：组件测试覆盖 P05 的三种状态（初始、校验错误、保存中）与重复地址提示；保存后触发该账户同步。

- [ ] **M1-10** 总览基础版（P02） 〔离线〕
  - 做什么：`WatchPortfolio`；P02 的总资产卡片、分布切换与列表、底部统计行、五种页面状态、下拉刷新、隐藏金额。净值曲线和提醒卡片留到 M3。
  - 验收：组件测试覆盖空、加载（有缓存与无缓存）、部分失败、全部失败、离线五种状态。

- [ ] **M1-11** 钱包账户详情基础版（P07） 〔离线〕
  - 做什么：摘要卡片、资产与地址两个分段、地址操作面板（完整地址、二维码、复制地址、在浏览器中打开、删除地址）。备份状态与密钥关联留到 M3、M4。
  - 说明：复制**公开地址**允许使用剪贴板；红线禁止的是密钥类数据。

- [ ] **M1-12** 数据源设置（P20 的 EVM 与价格部分） 〔离线〕
  - 做什么：`DataSourceConfig` 的实现（Key 存 `SecretStore`；M0-13 未完成时先用内存实现并在代码中标注 `TODO(M0-13)`）；P20 页面：填写 Key、测试连接、隐私说明。

- [~] **M1-14** 第三方目录（官网与文档链接） 〔离线〕
  - 来由：2026-11-11 用户要求。集成或提到的每个交易所、钱包、数据服务，都要能在 app 里直接点到它的官网和相关文档，不用自己去搜。
  - 做什么：新建纯 Dart 包 `ow_directory`，内置 `directory.json`（交易所、钱包、数据服务、区块浏览器的名称、官网、API 文档、创建只读 Key 的指引、导出私钥的指引、帮助中心等链接）与加载、查询、校验代码。选型与字段见 IMPLEMENTATION_SPEC 第 9 节；后续补充条目的方法见 `docs/DIRECTORY_COLLECTION_GUIDE.md`。
  - 安全要求：钱包类应用里的链接是钓鱼的高发点。只允许 https；每条链接的主机名必须落在该条目声明的官方域名内；每个条目记录核对日期与出处；app 只展示已核对的条目，并在打开前显示完整域名。
  - 验收：结构校验测试（id 唯一、https、域名归属、必填字段、枚举取值）；已接入的 4 家交易所、6 个钱包来源、各数据服务都有条目。
- [ ] **M1-15** 目录接入页面 〔离线〕
  - 做什么：`Account.walletSource` 从固定枚举改为目录中的钱包 id（字符串，可为空表示"其他"）；P05 的来源钱包改为从目录选择（可搜索）；P06 的"如何创建只读 Key"、P08、P11 的无助记词钱包建议、P20 的服务商、P22 各处显示对应链接。新增通用组件 `OwExternalLink`（显示域名，点击后先确认再用系统浏览器打开）。同步更新 PRD 的 R5、P05、P06、P11、P20。
  - 依赖：M1-14，以及 M1-09 至 M1-12 的页面。

- [ ] **M1-13** M1 集成测试与验收 〔设备〕〔用户〕
  - 做什么：`integration_test` 走通"添加 EVM 地址 → 总览显示资产"（用假适配器）；用户用真实地址和自己的 Key 试用，核对余额与区块浏览器一致。
  - 验收：PRD 第 11 节"账户与同步"前两条；更新 `progress.md`。

---

## M2 全部数据源

- [ ] **M2-01** Bitcoin 适配器 〔离线〕＋〔用户〕冒烟
- [ ] **M2-02** Solana 适配器（原生币与 SPL 代币） 〔离线〕＋〔用户〕冒烟
- [ ] **M2-03** Tron 适配器（TRX 与 TRC-20） 〔离线〕＋〔用户〕冒烟
  - 三者通用：先写 `EXTERNAL_APIS.md` 对应小节；录制样本测试；`tools/smoke/` 脚本；把该链的主流代币补进映射表。
- [ ] **M2-04** P05 支持全部地址类型；P20 补全四类链 〔离线〕
- [ ] **M2-05** 交易所签名与公共基础 〔离线〕
  - 做什么：`ow_exchanges` 中实现四家的请求签名、时间同步（时间戳偏差时用服务器时间校正后重试一次，仍失败返回 `ClockSkewFailure`）、错误码映射。
  - 验收：每家的签名都用其官方文档中的示例输入输出验证。
- [ ] **M2-06** Binance 适配器 〔离线〕＋〔用户〕核对
- [ ] **M2-07** OKX 适配器 〔离线〕＋〔用户〕核对
- [ ] **M2-08** Bybit 适配器 〔离线〕＋〔用户〕核对
- [ ] **M2-09** Bitget 适配器 〔离线〕＋〔用户〕核对
  - 四者通用：
    - 实现 `verify`（连通性与权限：能查到权限的返回 `readOnly`、`canTrade`、`canWithdraw`；查不到的返回 `unknown`）、`fetchHoldings`（覆盖现货、资金、合约权益、理财等所有能通过只读接口取到的子账户）、`fetchDepositAddresses`。
    - 先写 `EXTERNAL_APIS.md` 对应小节，列出每个子账户用的接口，以及**取不到的产品**（会在 P08 明示"未包含"）。
    - 录制样本测试；`tools/smoke/exchange.dart`。
    - 〔用户〕核对：总估值与官方 app 相差不超过 1%，否则不算完成。
- [ ] **M2-10** 添加交易所账户（P06）与凭据存储 〔离线〕
  - 做什么：`AddExchangeAccount`、`ReplaceExchangeCredentials`、`CredentialRepository`；P06 页面，含权限警告流程和各家的"如何创建只读 Key"说明。
  - 验收：组件测试覆盖 P06 的四种状态与四类验证失败文案；保存后输入框被清空；凭据不出现在任何状态对象中。
- [ ] **M2-11** 交易所账户详情（P08） 〔离线〕
- [ ] **M2-12** 币种详情（P09）与跨来源归一化 〔离线〕
  - 验收：同一币种在链上与四家交易所的不同写法合并为一个（映射表补充交易所符号别名）。
- [ ] **M2-13** 同步状态（P21） 〔离线〕
- [ ] **M2-14** M2 验收 〔设备〕〔用户〕
  - PRD 第 11 节"账户与同步"全部五条。

---

## M3 管理与备份清单

- [ ] **M3-01** 应用锁核心 〔离线〕
  - 做什么：`SetUpPin`、`VerifyPin`、`ChangePin`；错误次数与锁定截止时间的持久化；锁定状态机（锁定时关闭数据库、清空内存数据、路由重定向）。PIN 校验值的算法：M0-12 完成后用 Argon2id，此前先抽象为接口。
  - 依据：PRD R18–R21；SECURITY_DESIGN 第 7 节。
  - 验收：用假时钟测试：连错 5 次锁 1 分钟，之后每次翻倍，上限 1 小时；重启后锁定仍在；把系统时间往回调不能提前解锁。
- [ ] **M3-02** 解锁页（P00）与首次引导（P01） 〔离线〕＋〔设备〕
  - 含 `BiometricAuth` 的平台实现、后台超时重新锁定、任务切换器遮挡。〔设备〕验收后三项。
- [ ] **M3-03** 账户列表完整版（P03） 〔离线〕：分组、排序、长按与右键菜单、重命名、删除（`RenameAccount`、`DeleteAccount`）。
- [ ] **M3-04** 地址簿（P10） 〔离线〕：`SearchAddresses`；"是不是我的地址"精确匹配。
- [ ] **M3-05** 每日快照与净值曲线 〔离线〕
  - 做什么：快照表与仓储；`RecordDailySnapshot`（R16）；`OwNetWorthChart`；P02 加入曲线与区间切换。
  - 验收：同一天多次同步只保留一条；有账户失败时 `complete` 为假；数据不足两天时曲线显示占位说明。
- [ ] **M3-06** 备份清单（P11）与备份状态 〔离线〕
  - 做什么：`UpdateBackupStatus`、`WatchBackupChecklist`；P11；P07 的备份状态操作面板；P02 的提醒卡片。"去入库"在 M4 前跳转到说明页。
  - 验收：R34–R38 每条规则有测试，包括 180 天提醒（假时钟）与待处理组按估值降序。
- [ ] **M3-07** 设置（P18、P19 的应用锁部分、P22） 〔离线〕：计价货币、隐藏小额、未识别代币管理、外观、自动锁定时间、`WipeAllData`。
- [ ] **M3-08** 设备完整性提示 〔设备〕：`DeviceIntegrity` 的平台实现；启动警告与 P19 的状态行。
- [ ] **M3-09** M3 验收 〔设备〕：PRD 第 11 节"应用锁"三条、"备份清单"第一条；PRD 第 10 节相关边界逐条走查。

---

## M4 保险库

前置：M0-11、M0-12、M3-01 的代码完成。开工前通读 SECURITY_DESIGN 全文。

- [ ] **M4-01** `VaultCrypto` 的 libsodium 实现 〔离线〕
  - 验收：用 libsodium 或 RFC 的公开测试向量验证 Argon2id 与 XChaCha20-Poly1305；篡改密文、nonce、AAD 任一字节都解密失败。
- [ ] **M4-02** 保险库文件格式与 `Vault`、`VaultSession` 〔离线〕
  - 依据：SECURITY_DESIGN 第 3、5.1 节；IMPLEMENTATION_SPEC 第 6 节。
  - 验收：创建、解锁、增删读、改密码的往返测试；错误密码返回 `WrongPasswordFailure`；把条目密文互换后解密失败（AAD 生效）；`close()` 之后任何操作抛出状态错误；文件中搜索不到明文片段；格式有版本号并有"读取未来版本时报错"的测试。
- [ ] **M4-03** `VaultStorage` 的文件实现 〔离线〕：原子写入与 `.bak`；模拟写入中断后原文件完好。
- [ ] **M4-04** 平台保护正式实现 〔真机〕：`ScreenGuard`（Android 禁止截屏、iOS 录屏检测与遮挡）、安全输入配置。SECURITY_DESIGN 第 8 节相关真机项。
- [ ] **M4-05** 创建保险库（P13、P12） 〔离线〕＋〔真机〕：`CreateVault`、`SetVaultBiometrics`；硬件包裹的生成。
- [ ] **M4-06** 导入密钥（P14） 〔离线〕＋〔真机〕
  - 做什么：`ImportVaultItem`；应用内 BIP39 词表键盘；整段粘贴分词；私钥输入与各链格式校验；查重。
  - 验收：R27、R28 的测试；离开页面清空输入的组件测试；重复导入被拒绝。
- [ ] **M4-07** 密钥详情与明文显示（P15） 〔离线〕＋〔真机〕
  - 做什么：`RevealVaultItem`（先硬件解包，失败转主密码）；`OwVeil`、`OwMnemonicGrid`；60 秒倒计时；离开即清除；主密码错误锁定（R31）；`DeleteVaultItem`（R32）。
  - 验收：R23–R26、R30–R32 每条有测试；明文不进入任何 Riverpod 状态、路由参数（代码审查项，在提交说明中逐条确认）。
- [ ] **M4-08** 派生地址（P16） 〔离线〕
  - 做什么：`DeriveAddresses`（在独立 isolate 中进行）、`AttachDerivedAddresses`；路径预设；"检测余额"；加入观察后自动关联并更新备份状态（R29）。
  - 验收：抓包或用假适配器断言"检测余额"只发出地址。
- [ ] **M4-09** 保险库设置（P19） 〔离线〕＋〔真机〕：`ChangeMasterPassword`、生物识别开关、生物识别变更后的恢复流程（R30）。
- [ ] **M4-10** 与真实钱包的派生对照 〔用户〕：用户用测试钱包在 MetaMask、Phantom、TronLink 及一款 Bitcoin 钱包中查看地址，与本应用派生结果对照，结果记入 ADR_004。
- [ ] **M4-11** M4 验收 〔真机〕：PRD 第 11 节"保险库"全部条目；SECURITY_DESIGN 第 8 节静态检查部分。

---

## M5 加密备份

- [ ] **M5-01** `BackupCodec` 与格式文档 〔离线〕
  - 依据：SECURITY_DESIGN 5.2；PRD R39。同时写 `tools/backup_decrypt/FORMAT.md`。
  - 验收：往返测试；错误密码；篡改任一字节失败且不输出内容；高于当前版本的文件报"请更新 app"。
- [ ] **M5-02** 独立解密工具 〔离线〕
  - 做什么：`tools/backup_decrypt/` 下一个 Python 单文件脚本（只依赖 PyNaCl 或同等的 libsodium 绑定），输入文件与密码，输出 JSON。附使用说明。
  - 验收：CI 中的互操作测试——Dart 生成样本，Python 解密，逐字段比对。
- [ ] **M5-03** 导出流程（P17） 〔离线〕＋〔设备〕：`ExportBackup`；`FileExporter` 的平台实现；"我已保存"后才更新导出时间（R41）。
- [ ] **M5-04** 恢复流程（P17、P01 入口） 〔离线〕＋〔设备〕：`PreviewBackup`、`RestoreBackup`；合并规则（R42）。
- [ ] **M5-05** "有未备份的更改"提醒 〔离线〕：R38。
- [ ] **M5-06** M5 验收 〔真机〕〔用户〕：PRD 第 11 节"加密备份"四条，含另一台手机恢复与断网电脑解密。

---

## M6 稳定化与自用发布

- [ ] **M6-01** SECURITY_DESIGN 第 8 节全部清单，逐项记录结果到 `docs/evidence/M6-01.md` 〔真机〕
- [ ] **M6-02** PRD 第 11 节全部验收标准逐项勾选 〔真机〕〔用户〕
- [ ] **M6-03** PRD 第 10 节异常与边界逐条走查 〔设备〕
- [ ] **M6-04** 性能检查：冷启动与全量同步耗时达到 PRD 第 3 节指标 〔真机〕
- [ ] **M6-05** 应用图标、启动页、版本号 〔离线〕〔用户〕
- [ ] **M6-06** 发布构建与安装 〔真机〕〔用户〕
- [ ] **M6-07** 迁入真实数据并导出第一份加密备份 〔用户〕

---

## 可以并行的工作线

多个执行者同时工作时，按工作线分配，各线之间文件基本不重叠：

| 工作线 | 任务 | 主要目录 |
|---|---|---|
| A 界面基础 | M0-07、M0-08 | `app/lib/widgets`、`app/lib/theme` |
| B 领域与数据 | M0-09 → M1-01 → M1-08 → M1-07 | `packages/ow_domain`、`ow_data`、`ow_application` |
| C 链上数据 | M1-05 → M1-02、M1-06 → M2-01、M2-02、M2-03 | `packages/ow_net`、`ow_chains` |
| D 价格与映射 | M1-03、M1-04 | `packages/ow_pricing` |
| E 交易所 | M2-05 → M2-06…M2-09 | `packages/ow_exchanges` |
| F 平台与真机 | M0-10 … M0-13、M3-02、M3-08、M4-04 | `packages/ow_platform`、原生工程 |
| G 页面 | M1-09 … M1-12、M2-10 … M2-13、M3-03 … M3-07 | `app/lib/features` |

- B 线的 M0-09 是几乎所有任务的前置，最先做。
- G 线依赖 A、B 线的产出；在适配器未完成时用假实现开发页面。
- `app/lib/l10n/app_zh.arb`、`app/lib/bootstrap/providers.dart`、`app/lib/router/app_router.dart`、本文件是多线共同修改的文件：每次只追加自己的条目，合并冲突时保留双方内容。
