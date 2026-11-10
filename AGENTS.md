# OneWallet 协作规则

本地优先的个人加密资产看板加离线密钥保险库。Flutter，多端架构，第一版发布 iOS 与 Android。

## 开始任何工作前

1. 读 `docs/progress.md` 了解当前进度。
2. 按下表找到权威文档，先读再动手。

## 文档路由

| 要做的事 | 先读 |
|---|---|
| 了解产品是什么、不做什么 | `docs/IDEA_BRIEF_v1.0.md` |
| 实现或修改功能、页面 | `docs/PRD_v1.0.md`（页面编号 P00–P22，规则编号 R1–R43） |
| 页面布局 | `docs/PROTOTYPE_v1.0.md`、可点击原型 `docs/prototype.html` |
| 颜色、字体、间距、组件样式 | `docs/UI_DESIGN_SYSTEM_v1.0.md` |
| 架构、分层、数据模型、外部服务 | `docs/TECH_DESIGN_v1.0.md` |
| 任何涉及密钥、加密、应用锁、备份文件的改动 | `docs/SECURITY_DESIGN_v1.0.md` |
| 写代码的规范、提交格式、扩展步骤 | `docs/DEV_GUIDELINES_v1.0.md` |
| 当前该做哪个里程碑 | `docs/DEVELOPMENT_PLAN_v1.0.md` |
| 重要决定的来由 | `docs/ADR_*.md` |

## 不可违反

`docs/DEV_GUIDELINES_v1.0.md` 第 1 节"安全红线"的全部条目。其中最重要的：

- 不实现任何签名、转账、下单、提现。
- 密钥类数据不进日志、不进剪贴板、不出设备。
- `ow_vault` 不得有网络依赖。
- 不自己实现密码学算法。
- 测试中不使用真实的助记词或 API Key。

## 改动顺序

需求变了先改文档，再改代码。完成一个里程碑后更新 `docs/progress.md`。

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

## 目录

`app/` 是 Flutter 应用；`packages/ow_*` 是各层的包；`tools/` 是检查脚本；`docs/` 是文档。各包的职责与依赖规则见 `docs/TECH_DESIGN_v1.0.md` 3.2、3.3 节和 `docs/DEV_GUIDELINES_v1.0.md` 第 2 节。
