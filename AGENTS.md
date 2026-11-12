# OneWallet 协作规则

本地优先的个人加密资产看板加离线密钥保险库。只看不动：不签名、不转账、不交易。
Flutter，多端架构，第一版发布 iOS 与 Android。

产品、架构、安全方案和任务清单都已定稿。**按文档实现，不要重新设计。**

## 开始任何工作前

1. 读 `docs/EXECUTION_GUIDE.md`：工作流程、完成标准、禁止事项、何时必须停下来问用户。
2. 读 `docs/progress.md` 和 `docs/TASKS.md`：现在做到哪了，下一个任务是什么。
3. 按下表找到权威文档，先读再动手。

## 文档路由

| 要做的事 | 先读 |
|---|---|
| 怎么干活、什么算完成、什么不能做 | `docs/EXECUTION_GUIDE.md` |
| 下一个任务及其验收 | `docs/TASKS.md` |
| 类型名、接口签名、路由、表结构 | `docs/IMPLEMENTATION_SPEC_v1.0.md` |
| 了解产品是什么、不做什么 | `docs/IDEA_BRIEF_v1.0.md` |
| 实现或修改功能、页面 | `docs/PRD_v1.0.md`（页面编号 P00–P22，规则编号 R1–R43） |
| 页面布局 | `docs/PROTOTYPE_v1.0.md`、可点击原型 `docs/prototype.html` |
| 颜色、字体、间距、组件样式 | `docs/UI_DESIGN_SYSTEM_v1.0.md` |
| 架构、分层、外部服务 | `docs/TECH_DESIGN_v1.0.md` |
| 任何涉及密钥、加密、应用锁、备份文件的改动 | `docs/SECURITY_DESIGN_v1.0.md`（通读全文） |
| 写代码的规范、提交格式、扩展步骤 | `docs/DEV_GUIDELINES_v1.0.md` |
| 外部接口的核对记录 | `docs/EXTERNAL_APIS.md` |
| 补充第三方官网与文档链接 | `docs/DIRECTORY_COLLECTION_GUIDE.md` |
| 里程碑的背景与门禁 | `docs/DEVELOPMENT_PLAN_v1.0.md` |
| 重要决定的来由 | `docs/ADR_*.md` |

文档之间矛盾时的取舍顺序见 `docs/EXECUTION_GUIDE.md` 第 3 节。

## 不可违反

`docs/DEV_GUIDELINES_v1.0.md` 第 1 节"安全红线"的全部条目。其中最重要的：

- 不实现任何签名、转账、下单、划转、提现。
- 密钥类数据（助记词、私钥、种子、密码、API Secret）不进日志、异常、路由参数、状态对象、剪贴板，不出设备。
- `ow_vault` 不得有网络依赖，不得导入 `dart:io`。
- 不自己实现密码学算法。
- 测试中不使用真实的助记词或 API Key；不向用户索要这些。
- 金额不用浮点数。
- 不为通过检查而删除测试、放宽规则或加忽略注释。

## 改动顺序

需求变了先改文档，再改代码。完成任务后更新 `docs/TASKS.md`；完成里程碑后更新 `docs/progress.md`。

## 项目命令

需要 Flutter 3.47.9（Dart 3.13）。全部命令在仓库根目录运行。

| 目的 | 命令 |
|---|---|
| 安装依赖 | `flutter pub get` |
| 合并前的全部检查（格式、静态检查、依赖边界、测试） | `tools/check.sh` |
| 只跑依赖边界与安全红线检查 | `dart run tools/ci/check_deps.dart` |
| 格式化 | `dart format .` |
| 静态检查 | `flutter analyze` |
| 单个纯 Dart 包的测试 | `cd packages/<包名> && dart test` |
| 应用的测试 | `cd app && flutter test` |
| 运行应用（需要已连接的设备或模拟器） | `cd app && flutter run` |
| 重新生成派生对照样本 | `pip install bip_utils && python3 packages/ow_vault/test/fixtures/generate_vectors.py` |
| 修改 ARB 文案后重新生成本地化代码 | `flutter pub get` 会自动生成 `app/lib/l10n/app_localizations*.dart` |
| 修改数据库表结构后重新生成（生成的 `*.g.dart` 需提交） | `cd packages/ow_data && dart run build_runner build` |
| 修改第三方目录后重新生成 | `cd packages/ow_directory && dart run tool/embed.dart` |
| 重新生成页面截图 | `cd app && flutter test --update-goldens --run-skipped -t screenshots test/screenshots/` |

## 目录

| 目录 | 内容 |
|---|---|
| `app/` | Flutter 应用，唯一依赖 Flutter 界面库的地方 |
| `packages/ow_domain` | 实体、接口、规则（纯 Dart，无 IO） |
| `packages/ow_application` | 用例 |
| `packages/ow_data` | 数据库与仓储实现 |
| `packages/ow_net` | 网络基础设施：仅 HTTPS 的客户端工厂、脱敏日志、失败映射、限速器（纯 Dart） |
| `packages/ow_chains`、`ow_exchanges`、`ow_pricing` | 数据源适配器 |
| `packages/ow_directory` | 第三方目录：内置的官网与文档链接（纯 Dart，只读） |
| `packages/ow_vault` | 保险库核心（禁止联网） |
| `packages/ow_platform` | 平台适配（含原生代码） |
| `tools/` | 检查脚本、冒烟脚本、备份解密工具 |
| `docs/` | 全部文档；`docs/evidence/` 放真机验收证据 |

各包的依赖规则见 `docs/DEV_GUIDELINES_v1.0.md` 第 2 节，由 `tools/ci/check_deps.dart` 强制。
