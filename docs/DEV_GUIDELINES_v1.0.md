# 《OneWallet》开发规范

> 版本 v1.0 · 2026-11-10

## 1. 安全红线（违反任何一条都不得合并）

1. 不自己实现密码学算法，不自己拼装加密模式。只用 SECURITY_DESIGN 第 4 节列出的算法和库。
2. 助记词、私钥、种子、主密码、备份密码、API Secret 不得出现在：日志、异常信息、路由参数、状态管理对象、分析事件、测试快照、提交记录。
3. `ow_vault` 包及 `ow_platform` 中的保险库代码不得引入任何网络依赖。
4. 不得出现任何能动用资金的代码：链上交易的构造、签名与广播；交易所的下单、划转、提现接口。
5. 敏感数据不得写入应用私有目录之外的任何位置，不得使用剪贴板。
6. 金额不得使用浮点数。
7. 测试中不得使用真实的助记词或 API Key。只用公开的测试向量和假数据。
8. 密钥、证书、`.env` 文件不得提交到仓库。

## 2. 分层与依赖规则

| 包 | 可以依赖 | 不可以依赖 |
|---|---|---|
| `ow_domain` | Dart 标准库、十进制库、freezed | 其他任何 `ow_*` 包、Flutter、IO |
| `ow_application` | `ow_domain` | 具体实现包、Flutter |
| `ow_net` | `ow_domain`、`dio` | 其他 `ow_*` 包、Flutter、平台名称判断 |
| `ow_data` | `ow_domain` | 彼此、`ow_vault`、`ow_net`、Flutter 界面库 |
| `ow_chains`、`ow_exchanges`、`ow_pricing` | `ow_domain`、`ow_net` | 彼此、`ow_data`、`ow_vault`、Flutter 界面库 |
| `ow_vault` | `ow_domain`、白名单内的密码学库 | 任何网络库、其他 `ow_*` 包 |
| `ow_platform` | `ow_domain`、Flutter 插件接口、`drift` 与 `sqlite3`（仅用于打开加密数据库，见 ADR_006） | 业务包（`ow_data` 等） |
| `app` | 以上全部 | — |

- 这些规则由 `tools/ci/check_deps.dart` 在 CI 中检查。
- 页面不得直接调用仓储或适配器，必须通过控制器和用例。
- 平台判断（`Platform.isIOS` 等）只允许出现在 `ow_platform` 和 `app/lib/bootstrap` 中。界面根据 `PlatformCapabilities` 和屏幕宽度决定行为，不根据平台名称。

## 3. 多端规范

- 页面必须放在 `AdaptiveScaffold` 内；列表详情类页面使用 `ListDetailLayout`。
- 不写死屏幕尺寸；断点统一使用 `Breakpoints.compact / medium / expanded`。
- 交互不依赖单一输入方式：长按菜单同时提供右键和"更多"按钮；可点击元素有悬停和焦点样式。
- 使用平台能力前先查询 `PlatformCapabilities`，并实现 PRD 7.3 的降级行为。
- 新增平台插件方法时，必须同时给出所有已支持平台的实现，或显式返回"不支持"。

## 4. Dart 代码风格

- 遵循 Effective Dart；静态检查使用 `flutter_lints` 加仓库根目录 `analysis_options.yaml` 中的严格规则（`strict-casts`、`strict-inference`、`strict-raw-types`）。
- 提交前运行 `dart format`；CI 检查格式。
- 命名：文件用 `snake_case`，类型用 `UpperCamelCase`，成员用 `lowerCamelCase`。页面类以 `Page` 结尾，控制器以 `Controller` 结尾，用例以动词开头（`SyncAllAccounts`）。
- 模型一律不可变。`ow_domain` 中手写（final 字段、const 构造函数、值相等、需要时加 copyWith），不用代码生成；其他包可按需使用 freezed，同一个包内保持一致。
- 公开接口写文档注释，说明"做什么"和"失败时怎样"；实现细节的注释只写"为什么"。
- 单个文件不超过 400 行，单个函数不超过 60 行；超过时拆分。
- 不使用 `dynamic`；不使用 `!` 强制解包，除非紧邻处有判空。
- 代码标识符用英文；注释和文档用中文；界面文案全部放在 ARB 资源文件中，不硬编码。

## 5. 错误处理

- 可预期的失败（网络、限频、凭据无效、校验失败、密码错误）用结果类型返回：`Result<T, Failure>`，`Failure` 是封闭的类型集合，每种对应一条用户可读的文案。
- 异常只用于程序缺陷。不捕获后静默吞掉。
- 适配器必须把服务商的错误码映射为统一的 `Failure`（`rateLimited`、`unauthorized`、`keyExpired`、`clockSkew`、`network`、`serviceDown`、`unknown`）。
- 面向用户的错误信息说明"发生了什么、能做什么"，不显示原始异常文本。

## 6. 日志

- 使用统一的 `Logger` 封装，禁止 `print`。
- 级别：`debug`（仅调试构建）、`info`、`warn`、`error`。
- 敏感类型（`Mnemonic`、`PrivateKey`、`ApiSecret`、`Password`）的 `toString()` 固定返回 `***`。
- 地址在日志中缩略；API Key 只保留前 4 位。
- 发布构建只保留最近 50 条同步日志（P21），不记录其他内容。

## 7. 测试

- 新增业务规则必须带单元测试；修复缺陷必须先写出能重现它的测试。
- 测试命名：`被测对象_条件_预期`。
- 适配器测试使用 `test/fixtures/` 下的响应样本；样本中的地址和数值须脱敏。
- 派生与加密测试必须包含官方测试向量。
- 不在单元测试中访问真实网络。需要联网的冒烟测试单独标记，手动运行。
- 覆盖率门槛见 TECH_DESIGN 第 8 节。

## 8. Git 与提交

- 默认分支 `main`；功能分支 `feat/<里程碑>-<简述>`，修复分支 `fix/<简述>`。
- 提交信息采用约定式提交，正文用中文：

```
<类型>(<范围>): <一句话说明>

<可选：为什么这样改>
```

类型：`feat`、`fix`、`refactor`、`test`、`docs`、`chore`、`security`。范围：包名或 feature 名，如 `vault`、`chains`、`overview`。

- 一次提交只做一件事；格式化、重命名与逻辑改动分开提交。
- 合并前必须通过：格式检查、静态检查、全部测试、依赖边界检查。
- 涉及 `ow_vault`、`ow_platform`、备份格式的改动，在合并请求中单独说明安全影响，并对照 SECURITY_DESIGN 第 8 节相关条目自查。

## 9. 常见扩展的步骤

**新增一条链**
1. 在 `ow_domain` 的链定义中登记（id、名称、所属家族、原生币、浏览器地址模板）。
2. 若属于已有家族（如新的 EVM 链），只需补充配置和数据服务地址。
3. 若是新的家族：在 `ow_chains` 实现 `ChainAdapter`；在 `ow_vault` 增加派生与地址编码并补测试向量。
4. 在映射表中补充该链上主流代币的合约地址。
5. 更新 PRD 的链清单和 P16 的路径表。

**新增一家交易所**
1. 在 `ow_exchanges` 实现 `ExchangeAdapter`：签名、余额（覆盖所有子账户）、充值地址、权限检查。
2. 添加响应样本与解析测试；用文档示例验证签名。
3. 在映射表中补充符号别名。
4. 在 P06 的"创建步骤"中补充图文说明。
5. 与官方 app 的总资产核对，误差超过 1% 不得合并。

**新增一个平台**
1. 在 `ow_platform` 实现全部能力接口，做不到的返回"不支持"。
2. 添加平台工程目录与构建配置。
3. 检查中屏、宽屏布局与键鼠交互。
4. 按 SECURITY_DESIGN 第 8 节做该平台的真机验证，并在 6.1 的表中补充实现说明。

## 10. 依赖管理

- 新增依赖前检查：维护是否活跃、许可是否兼容、是否引入原生代码、传递依赖数量。
- 版本锁定到确切版本，锁文件入库。
- `ow_vault` 新增依赖必须写 ADR。
- 每个里程碑结束时检查一次依赖的安全公告。

## 11. 文档同步

- 需求变更先改 PRD；页面变更先改 PROTOTYPE；技术方案变更改 TECH_DESIGN 或新增 ADR；安全相关变更先改 SECURITY_DESIGN。然后再改代码。
- 每完成一个里程碑，更新 `docs/progress.md`。
- 重要决定写成 `docs/ADR_<编号>_<主题>.md`，包含背景、选项、决定、后果。

## 12. 合并前自查表

- [ ] 没有触碰第 1 节的任何红线
- [ ] 格式、静态检查、测试全部通过
- [ ] 新逻辑有测试
- [ ] 界面文案在资源文件中
- [ ] 空、加载、错误三种状态都已处理
- [ ] 没有平台名称判断泄漏到业务代码
- [ ] 相关文档已更新
