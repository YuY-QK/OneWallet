# OneWallet

本地优先的个人加密资产看板加离线密钥保险库。

- **一处看全**：链上钱包（EVM 系、Bitcoin、Solana、Tron）与交易所（Binance、OKX、Bybit、Bitget）的资产汇总。
- **备份不丢**：备份清单告诉你每个钱包是否有备份；保险库用硬件密钥加主密码加密保存助记词与私钥。
- **只看不动**：不签名、不转账、不交易。
- **不依赖任何人**：没有自有服务器；备份格式公开，可脱离 app 解密。

状态：计划阶段，尚未开始实施。见 [`docs/progress.md`](docs/progress.md)。

## 文档

| 文档 | 内容 |
|---|---|
| [想法简报](docs/IDEA_BRIEF_v1.0.md) | 一页说清做什么、不做什么 |
| [产品需求文档](docs/PRD_v1.0.md) | 规则与逐页需求 |
| [原型说明](docs/PROTOTYPE_v1.0.md) | 信息架构与页面线框 |
| [技术设计](docs/TECH_DESIGN_v1.0.md) | 架构、多端策略、数据模型 |
| [安全设计](docs/SECURITY_DESIGN_v1.0.md) | 威胁模型、密钥层级、存储格式 |
| [开发规范](docs/DEV_GUIDELINES_v1.0.md) | 安全红线、分层规则、代码与提交规范 |
| [开发计划](docs/DEVELOPMENT_PLAN_v1.0.md) | 里程碑、所需资源、启动清单 |
| [ADR 001](docs/ADR_001_技术栈与多端策略.md)、[002](docs/ADR_002_本地优先无后端.md)、[003](docs/ADR_003_保险库加密方案.md) | 关键决定 |
