# OneWallet 交接说明

> 写给接手剩余开发的执行者（人或 AI）。**先读这份，再读 `EXECUTION_GUIDE.md`。**
> 这份文档讲三件事：现在做到哪了；已经形成、必须照做的做法；剩下的任务按什么顺序做、每个任务要注意什么。
> 任务的正式条目、验收条件仍以 `TASKS.md` 为准；这里是它的补充，不重复它。

## 1. 现状

应用骨架已经能跑通核心循环（在自动化测试里）：添加链上地址 → 同步余额 → 总览显示总资产。

| 部分 | 状态 |
|---|---|
| 文档、原型、设计规范 | 完成并定稿 |
| 工程骨架、CI 配置、依赖边界检查、响应式外壳、主题、字体、通用组件 | 完成 |
| 领域模型与接口（`ow_domain`） | 完成，测试覆盖率 99% |
| 数据库（Drift + SQLCipher）、仓储、安全存储、应用启动与依赖装配 | 完成（手机上未验证） |
| 网络基础设施（`ow_net`） | 完成 |
| 链适配器：EVM 六条链、Bitcoin、Solana、Tron | 完成（接口对照官方文档核对过；Bitcoin 之外没有真实调用过） |
| 价格源、币种映射表、资产汇总计算 | 完成 |
| 同步与添加钱包的用例 | 完成 |
| 第三方目录（`ow_directory`，79 个条目） | 完成，尚未接进页面 |
| 交易所适配器 | 公共基础与 Binance 完成；OKX、Bybit、Bitget 见 `TASKS.md` 的状态 |
| 页面 | P02 总览、P03 账户列表、P04、P05、P07、P20 的基础版完成；其余未做 |
| 应用锁、备份清单、净值曲线 | 未做（M3） |
| 保险库 | 只有地址派生；加密、文件格式、页面都未做（M4） |
| 加密备份 | 未做（M5） |
| 原生代码（硬件密钥、防截屏、iOS 备份排除） | 未做 |

**没有任何东西在手机上运行过。** 全部验证都来自 `flutter test`。真机验收统一放在最后，待测项目汇总在 `DEVICE_TEST_CHECKLIST.md`。

## 2. 已经形成的做法（必须照做）

这些不是建议。仓库里已有的代码都是这么写的，新代码要与它们保持一致。动手前先读对应的范本文件。

### 2.1 范本文件

| 要做的事 | 照着这个写 |
|---|---|
| 链适配器 | `packages/ow_chains/lib/src/evm_chain_adapter.dart` 及其测试 |
| 交易所适配器 | `packages/ow_exchanges/ADAPTER_TEMPLATE.md`、`lib/src/binance/` 及其测试 |
| 用例 | `packages/ow_application/lib/src/accounts/add_wallet_account.dart`、`sync/sync_account.dart` |
| 仓储与表 | `packages/ow_data/lib/src/repositories/`、`database/` |
| 页面与控制器 | `app/lib/features/overview/`（状态推导写成纯函数，页面只渲染）、`app/lib/features/accounts/` |
| 表单页 | `app/lib/features/accounts/presentation/add_wallet_page.dart` 及 `controllers/add_wallet_controller.dart` |
| 设置类列表页与底部弹层编辑 | `app/lib/features/settings/` 的数据源设置 |
| 页面测试 | `app/test/features/` 下任一文件；假数据与渲染工具在 `app/test/support/fakes.dart`、`pump_app.dart` |
| 依赖装配 | `app/lib/bootstrap/`，清单在 `IMPLEMENTATION_SPEC` 7.5 |
| 内置数据的嵌入 | `packages/ow_directory/tool/embed.dart`（JSON 生成 Dart 常量，测试断言两者一致） |

### 2.2 规矩

1. **外部接口先核对再写**：任何新的第三方接口，先读官方文档，把核对结果写进 `EXTERNAL_APIS.md`，再写代码。文档站读不到正文时，试 `llms.txt`、`llms-full.txt`、页面网址加 `.md`、官方 SDK 的源码；都读不到就写"未能核对"，不要凭印象写接口路径。
2. **交易所只读**：每个适配器把自己用到的全部路径列成常量，测试断言所有发出的请求都在这份只读白名单内。附加账户（合约、杠杆、理财）先尝试查询，交易所明确返回无权限时才当作空，并记入 `lastSkipped`；其他失败让整次同步失败，不允许悄悄少算。
3. **金额只用 `Decimal`**：从接口返回的字符串构造；接口返回 JSON 数字时用 `exact_json.dart` 保留原文精度。
4. **密钥类数据用 `Sensitive`**：不进日志、异常、路由参数、Riverpod 状态、剪贴板、测试快照。测试里的助记词只用 BIP39 公开测试向量。
5. **页面**：
   - 只通过控制器和 `app/lib/bootstrap/` 里的 provider 取数据、调用用例；
   - 只用 `app/lib/widgets/` 的 `Ow*` 组件和 `context.ow` 的颜色；
   - 文案全部进 `app/lib/l10n/app_zh.arb`；金额、地址、时间用 `formatters.dart`；失败文案用 `failureText`；
   - PRD 里该页列出的每个页面状态都要实现并各有测试；
   - 在 390×800 和 1280×900 两种宽度下各渲染一次，断言没有溢出。
6. **时间与随机**：当前时间用注入的 `Clock`，不直接调用 `DateTime.now()`；标识用 `IdGenerator`；安全随机数用 `Random.secure()` 或 libsodium。
7. **改表**：`schemaVersion` 加一，写迁移和迁移测试，运行 `cd packages/ow_data && dart run build_runner build` 并提交生成的 `*.g.dart`。
8. **真机相关**：没有设备时，代码和自动化测试照常做完，把没验证的项目追加到 `DEVICE_TEST_CHECKLIST.md`（新开一节，编号顺延）。原生代码没编译过的要单独标"未编译"。**不要把没验证的说成已验证。**
9. **每个任务结束**：`tools/check.sh` 输出"全部通过"；更新 `TASKS.md` 的状态；涉及的文档同步。

### 2.3 容易踩的坑

- `flutter pub get` 会通过构建钩子从 GitHub Releases 下载 SQLCipher 预编译库，网络不通时会失败（见 `ADR_006`）。
- 测试输出里的 `ERROR CORE sqlcipher…` 是"错误密钥打不开"那几个测试的预期输出，不是失败。
- Riverpod 3 会暂停没有监听者的 provider：测试里读 `StreamProvider` 的 `.future` 之前要先 `container.listen`。
- go_router 的 `push` 之后，路由器的当前地址不反映被 push 的页面；测试里断言页面内容，不要断言路径。
- `sodium_libs` 包已停止维护，用 `sodium` 包本身。
- 生成文件要入库的有三处：`ow_data` 的 `*.g.dart`、`ow_directory` 的 `directory_data.g.dart`、`ow_pricing` 的 `asset_mappings_data.dart`，以及 `app/lib/l10n/app_localizations*.dart`。改了源头要重新生成。
- `tools/ci/check_deps.dart` 会扫描 `ow_exchanges` 里含 `order`、`withdraw`、`transfer` 等字样的字符串。确属只读的查询路径或返回字段被拦时，加入 `readOnlyPathAllowlist`，每条写明用途和出处。不要用别的办法绕过。

## 3. 剩余任务的顺序

按批次做。同一批内的任务互不依赖，可以并行；下一批依赖上一批。每个任务的验收见 `TASKS.md`，这里只写顺序、建议的模型档位（原则见 `EXECUTION_GUIDE.md` 第 10 节）和额外注意点。

开工前先看 `TASKS.md` 里这些任务的实际状态：标了 `[x]` 的跳过。

### 第一批：把已有的东西接起来

| 任务 | 档位 | 注意 |
|---|---|---|
| M2-07、M2-08、M2-09 中尚未完成的交易所适配器 | 省 | 严格照 `ADAPTER_TEMPLATE.md`。公共层已备好这三家的签名、错误码和判定函数，不要重写 |
| M1-18 中尚未完成的小项 | 中 | 看 `TASKS.md` 该条目下的完成记录。涉及改表时遵守 2.2 第 7 条 |
| M2-04 四类链的接线 | 中 | 条目里已写明要做的四件事。Tron 适配器需要内置表里代币的小数位数：给 `asset_mappings.json` 加 `decimals` 字段并重新生成，数值要有出处 |
| M1-15 目录接入页面 | 中做组件、省做填充 | 先做通用组件 `OwExternalLink`（显示域名、点击后确认、用系统浏览器打开）；再把各页面的链接填上。`Account.walletSource` 从枚举改成目录 id 要改表，遵守 2.2 第 7 条 |

### 第二批：交易所接进应用

依赖第一批的交易所适配器。

| 任务 | 档位 | 注意 |
|---|---|---|
| M2-10 添加交易所账户（P06）与凭据存储 | 中 | **安全敏感**。`CredentialRepository` 基于 `SecretStore`，键名加 `ow.` 前缀。凭据只在保存那一刻从输入框读出，保存后清空输入框；不进任何状态对象。把 `SyncAccount` 里交易所账户的分支补上（现在返回 `UnsupportedFailure`），并把四个适配器接入 `AppAdapterRegistry`。权限为 `canTrade` 或 `canWithdraw` 时的警告流程按 PRD P06 |
| M2-11 交易所账户详情（P08） | 省 | 照 P07 的页面写。显示各适配器的 `notIncluded` 和 `lastSkipped`（"未包含：…"） |
| M2-12 币种详情（P09） | 省 | 数据来自 `PortfolioCalculator.distributionOf`，已实现。把总览里预留的说明页换成它 |
| M2-13 同步状态（P21） | 省 | 照数据源设置页的列表写法 |

### 第三批：应用锁与管理功能

M3-01 先做，M3-02 依赖它；其余互不依赖。

| 任务 | 档位 | 注意 |
|---|---|---|
| M3-01 应用锁核心 | 强 | 先通读 `SECURITY_DESIGN` 第 7 节。PIN 校验值的算法要用 Argon2id，依赖 M0-12/M4-01 的 `VaultCrypto`；如果它还没做，先把"口令哈希"抽象成接口并在本任务里一并实现 `VaultCrypto` 的 Argon2id 部分（见第四批 M4-01 的注意点），不要用别的哈希临时顶替。锁定时要关闭数据库连接、清空内存数据、路由重定向。错误次数和锁定截止时间存 `SecretStore`；防改时间绕过的规则在 PRD R20 和 SECURITY_DESIGN 第 7 节 |
| M3-02 解锁页（P00）与首次引导（P01） | 中 | 生物识别用成熟插件 `local_auth`，不手写原生代码。后台超时重新锁定和任务切换器遮挡在 Dart 侧能做的部分做掉，其余记入真机清单 |
| M3-03 账户列表完整版、M3-04 地址簿 | 省 | 照已有的 P03 扩展。长按菜单同时提供右键菜单和"更多"按钮（PRD 7.3） |
| M3-05 每日快照与净值曲线 | 中 | `SyncAllAccounts` 已留了 `onFullSyncCompleted` 钩子。快照以 USD 计。图表自己用 `CustomPainter` 画，不引入图表库；样式见 `UI_DESIGN_SYSTEM` 第 5 节和 `prototype.html` |
| M3-06 备份清单（P11）与备份状态 | 中 | 规则 R34–R38 逐条写测试。`Account.backupLevel` 已实现。"去入库"在保险库做完前跳到说明页 |
| M3-07 设置、关于 | 省 | 启动失败页要加"清除本地数据并重新开始"的入口（条目里已写）。关于页展示 CoinGecko 署名（M1-15 的遗留） |
| M3-08 设备完整性提示 | 省 | 用成熟插件；检测到时只警告不阻止 |

### 第四批：保险库

**开工前通读 `SECURITY_DESIGN` 全文和 `ADR_003`。** 这是整个项目里做错代价最高的部分。M4-01 到 M4-03 是核心，按顺序做；页面依赖它们。

| 任务 | 档位 | 注意 |
|---|---|---|
| M0-12 的 Dart 侧 + M4-01 `VaultCrypto` | 强 | 用 `sodium` 包，只调用高层接口：Argon2id（`pwhash`）、XChaCha20-Poly1305（`aead`）、`kdf`、`genericHash`、`randombytes`。先确认它在桌面测试环境和手机上的接入方式，写 `ADR_005`，并把 `sodium` 加入 `check_deps.dart` 的保险库白名单。用 libsodium 或 RFC 的公开测试向量验证。Argon2id 默认参数：内存 64 MiB、迭代 3、并行 1；真机定标留到最后的整体测试 |
| M4-02 保险库文件格式与 `Vault`、`VaultSession` | 强 | 接口在 `IMPLEMENTATION_SPEC` 第 6 节，格式在 `SECURITY_DESIGN` 第 5.1 节，照做，不要改格式。`ow_vault` 不得导入 `dart:io`，文件读写走注入的 `VaultStorage`。每条密文带关联数据（版本、条目 id、类型）。验收里"把两个条目的密文互换后解密失败"必须有测试 |
| M4-03 `VaultStorage` 的文件实现 | 中 | 放在 `ow_platform` 或 `app/lib/bootstrap`。原子写入：写临时文件、落盘、重命名，保留 `.bak` |
| M0-11 硬件密钥、M4-04 防截屏与安全输入 | 中 | 这是唯一必须写原生代码（Swift、Kotlin）的地方，而且无法在没有设备的环境里编译。做法：先查有没有成熟、维护活跃、代码量小的插件能满足 `SECURITY_DESIGN` 6.1 的要求（生物识别变更后失效、仅本设备）；有就用并写 ADR；没有才手写，并在真机清单里标"未编译"。在此之前，保险库页面必须能在"没有硬件密钥"的情况下只用主密码工作（`PlatformCapabilities.hardwareKeystore` 为假） |
| M4-05 创建保险库（P13、P12） | 中 | 主密码输入框的内容不进控制器状态；创建过程显示进度（密钥派生要 1 到数秒，放到 isolate） |
| M4-06 导入密钥（P14） | 中 | **安全敏感**。助记词用应用内的 BIP39 词表键盘输入，不经过系统输入法；离开页面即清空；保存前验证；查重用指纹 |
| M4-07 密钥详情与明文显示（P15） | 中 | **安全敏感**。每次查看都验证；60 秒自动遮挡；明文不进 Riverpod 状态、不进路由参数；不提供复制。提交说明里逐条确认这几点 |
| M4-08 派生地址（P16） | 中 | 派生在独立 isolate 里做，只把地址传回。`AddressDeriver` 和 9 种方案已实现并验证过 |
| M4-09 保险库设置 | 省 | 照安全设置页写；修改主密码调用 `VaultSession.changePassword` |

### 第五批：加密备份

依赖第四批。

| 任务 | 档位 | 注意 |
|---|---|---|
| M5-01 `BackupCodec` 与格式文档 | 强 | 格式在 `SECURITY_DESIGN` 5.2，照做。同时写 `tools/backup_decrypt/FORMAT.md` |
| M5-02 独立解密工具 | 省 | Python 单文件，只依赖 PyNaCl。必须有互操作测试：Dart 生成样本，Python 解密，逐字段比对 |
| M5-03 导出、M5-04 恢复（P17） | 中 | 文件导出与选取用成熟插件（`share_plus`、`file_picker` 一类），写清选型。合并规则见 PRD R42 |
| M5-05 "有未备份的更改"提醒 | 省 | R38 |

### 第六批：收尾

| 任务 | 档位 | 注意 |
|---|---|---|
| M1-13 集成测试 | 省 | `integration_test` 走通主流程（用假适配器） |
| M6-05 应用图标、启动页、版本号 | 省 | 图标需要用户提供或确认 |
| 全仓库审查 | 强 | 对照 `DEV_GUIDELINES` 第 1 节红线和 `SECURITY_DESIGN` 第 8 节的静态检查部分通读一遍代码，列出问题 |

其余带〔真机〕〔用户〕标签的验收任务（M0-10、M2-14、M3-09、M4-10、M4-11、M5-06、M6-01 至 M6-04、M6-06、M6-07）由用户在最后用真机按 `DEVICE_TEST_CHECKLIST.md` 完成，不需要执行者做。

## 4. 协调与审查

如果由一个协调者拆任务、派给多个执行者：

- 每个执行者在独立的分支或工作副本里做，不直接改默认分支。同时进行的任务之间，除共用文件外目录不重叠。
- 共用文件（`app_zh.arb`、`app/lib/bootstrap/`、`app_router.dart`、`TASKS.md`、`DEVICE_TEST_CHECKLIST.md`、`EXTERNAL_APIS.md`）只追加自己的条目；合并冲突时保留双方内容。
- 给执行者的任务说明要写明：范本文件的路径、允许改动的目录、明确不做的事、验收条件、汇报格式。

审查每个交回的任务时至少看这些：

- [ ] 自己重跑 `tools/check.sh`，不采信对方自报的结果。
- [ ] 改动范围是否超出了任务允许的目录。
- [ ] 有没有新增 `// ignore`、被跳过或删除的测试、放宽的检查规则。
- [ ] 有没有为了让测试通过而迁就错误行为（断言被改弱、分支被特判）。
- [ ] 新的外部接口路径有没有文档出处；"未能核对"的项有没有如实记录。
- [ ] 涉及金额的地方有没有 `double`；涉及密钥的地方有没有进入日志、状态、路由参数。
- [ ] 对方"自行决定的事项"里有没有影响用户可见行为或数据口径的，有就要写进文档或打回。
- [ ] 对方提出的"接口修改建议"：认可的开成新任务，不要让它们散落在对话里。

## 5. 目前已知、尚未解决的问题

| 问题 | 去处 |
|---|---|
| GitHub Actions 是否实际运行过没有确认 | 用户在仓库的 Actions 页面查看；没有记录就在设置里开启 |
| 手机上的构建、SQLCipher 的链接、安全存储、Android 备份排除都没验证 | `DEVICE_TEST_CHECKLIST` 第 3 节 |
| iOS 上数据库文件没有排除出系统备份 | 随 M0-11 的原生插件一起做；在那之前 M3-07 提供"清除本地数据"的出口 |
| 币种映射表的合约地址主要来自第三方代币列表，没有逐个对照发行方 | `DEVICE_TEST_CHECKLIST` 第 2 节，需人工复核 |
| 第三方目录有 17 个条目待核对，多数链接只确认了域名 | `DIRECTORY_COLLECTION_GUIDE.md` |
| 各交易所适配器只对照了文档或官方 SDK，没有真实调用过 | `DEVICE_TEST_CHECKLIST` 第 6 节，需用户用只读 Key 跑冒烟脚本 |
| Tron 的质押与委托是否重复计入、Solana 公共节点的限频等 | `DEVICE_TEST_CHECKLIST` 第 5 节 |
