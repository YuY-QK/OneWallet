# 冒烟测试脚本

需要真实网络和真实 Key 的手动测试放在这里，由用户在自己的机器上运行。

- Key 一律从环境变量读取，例如 `OW_ALCHEMY_KEY`、`OW_BINANCE_KEY`、`OW_BINANCE_SECRET`。
- 脚本不得把 Key 写入文件或打印出来。
- 这些脚本不在 CI 中运行。

## 脚本清单

| 脚本 | 用途 | 运行 |
|---|---|---|
| `packages/ow_chains/tool/smoke_evm.dart` | 用 Alchemy 查询 EVM 地址的持仓（M1-06） | 在 `packages/ow_chains` 目录：`OW_ALCHEMY_KEY=<Key> dart run tool/smoke_evm.dart <地址> [链id]` |

脚本放在各自的包内（`tool/` 目录），因为 `dart run` 需要解析该包的依赖；本目录只做索引。
