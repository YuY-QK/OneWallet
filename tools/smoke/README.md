# 冒烟测试脚本

需要真实网络和真实 Key 的手动测试放在这里，由用户在自己的机器上运行。

- Key 一律从环境变量读取，例如 `OW_ALCHEMY_KEY`、`OW_BINANCE_KEY`、`OW_BINANCE_SECRET`。
- 脚本不得把 Key 写入文件或打印出来。
- 这些脚本不在 CI 中运行。

## 脚本清单

| 脚本 | 用途 | 运行 |
|---|---|---|
| `packages/ow_chains/tool/smoke_evm.dart` | 用 Alchemy 查询 EVM 地址的持仓（M1-06） | 在 `packages/ow_chains` 目录：`OW_ALCHEMY_KEY=<Key> dart run tool/smoke_evm.dart <地址> [链id]` |
| `packages/ow_chains/tool/smoke_btc.dart` | 用 mempool.space 查询 Bitcoin 地址的已确认余额（M2-01，无需 Key） | 在 `packages/ow_chains` 目录：`dart run tool/smoke_btc.dart <地址> [自定义实例]` |
| `packages/ow_chains/tool/smoke_sol.dart` | 查询 Solana 地址的持仓（M2-02）；Key 可缺省，缺省时用官方公共 RPC | 在 `packages/ow_chains` 目录：`OW_HELIUS_KEY=<Key> dart run tool/smoke_sol.dart <地址>` |
| `packages/ow_chains/tool/smoke_tron.dart` | 用 TronGrid 查询 Tron 地址的持仓（M2-03）；Key 可缺省 | 在 `packages/ow_chains` 目录：`OW_TRONGRID_KEY=<Key> dart run tool/smoke_tron.dart <地址>` |

脚本放在各自的包内（`tool/` 目录），因为 `dart run` 需要解析该包的依赖；本目录只做索引。

## 价格源（CoinGecko）

脚本在 `packages/ow_pricing/tool/smoke_price.dart`（需要 `ow_pricing` 的依赖，所以放在包内；`tools/` 属于不带依赖的根工作区，无法直接导入）。

```
cd packages/ow_pricing
dart run tool/smoke_price.dart             # 打印 BTC、ETH、USDT 的 USD 价格与 24 小时涨跌
dart run tool/smoke_price.dart --catalog   # 核对内置映射表里每个 priceId 是否都查得到价格
```

- Key 从环境变量 `OW_COINGECKO_KEY` 读取，可缺省：`OW_COINGECKO_KEY=你的Key dart run tool/smoke_price.dart`。
- 无 Key 时免费档限频很严，遇到 `RateLimitedFailure` 稍等一分钟再试。
- `--catalog` 在上线前至少运行一次：映射表中的 priceId 来自既有知识，未能对照 CoinGecko 官方清单核对，这一步用真实接口验证。

## 交易所（Binance 等）

脚本在 `packages/ow_exchanges/tool/smoke_exchange.dart`（需要包内依赖，所以放在包内）。

```
cd packages/ow_exchanges
OW_BINANCE_KEY=<只读Key> OW_BINANCE_SECRET=<Secret> dart run tool/smoke_exchange.dart binance
```

- 环境变量命名：`OW_<交易所大写>_KEY`、`OW_<交易所大写>_SECRET`；OKX、Bitget 另需 `OW_<交易所大写>_PASSPHRASE`。
- 打印权限判断（`readOnly` / `canTrade` / `canWithdraw` / `unknown`）与各子账户按币种的数量，不打印任何凭据。
- 目前只实现了 `binance`，其余交易所由后续任务加入。
