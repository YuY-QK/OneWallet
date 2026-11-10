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
| 页面布局 | `docs/PROTOTYPE_v1.0.md` |
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

工程尚未建立。M0 完成后在此补充：安装依赖、运行、测试、格式化、静态检查、依赖边界检查的命令。
