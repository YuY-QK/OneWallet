# 外部接口核对记录

> 每个适配器在实现前，对照官方文档核对后在这里记一节。没有记录的适配器不得合并。
> 规则见 `IMPLEMENTATION_SPEC_v1.0.md` 第 8 节。

## 模板

```
## <服务或交易所名>

- 官方文档：<链接>
- 核对日期：YYYY-MM-DD
- 鉴权方式：
- 限频：
- 免费额度（如适用）：

| 用途 | 方法与路径 | 关键参数 | 返回中用到的字段 |
|---|---|---|---|

- 字段到领域模型的映射：
- 错误码到 Failure 的映射：
- 取不到的内容（会在界面明示"未包含"）：
- 备注：
```

## Alchemy（EVM）

- 官方文档：<https://www.alchemy.com/docs>（Token API：`alchemy_getTokenBalances`、`alchemy_getTokenMetadata`；吞吐量与计算单元：`/docs/reference/throughput`）
- 核对日期：2026-11-11 —— **未能核对**。本次执行环境的网络只放行包仓库，`www.alchemy.com` 无法解析，WebFetch 全部失败；仅有一次 WebSearch，返回的是第三方集成站（withone.ai）的摘录，不是官方文档，只能作旁证。下表所有内容是**凭记忆实现的假设**，标"未核对"。**在真实 Key 上跑通 `tools/smoke/README.md` 里的冒烟脚本之前，不得当作已验证。**
- 鉴权方式（未核对）：Key 放在 URL 路径，`https://<主机>/v2/<API Key>`；HTTP POST，`Content-Type: application/json`，JSON-RPC 2.0。没有请求头鉴权。
- 限频（未核对）：Alchemy 按"计算单元（CU）/秒"限频，免费档的具体数值与各方法的 CU 开销未能核对。适配器默认用 `RateLimiter` 每秒 10 次请求作保守估计，调用方可注入其他限速器。超限时预期返回 HTTP 429 或 JSON-RPC 错误（错误码未核对；适配器同时把 HTTP 429、错误码 `429`、`-32005` 映射为 `RateLimitedFailure`）。
- 免费额度：未能核对。

各链的端点主机名（全部未核对；适配器内置于 `EvmChainAdapter.alchemyHosts`）：

| 链 id | 主机名（未核对） | 备注 |
|---|---|---|
| ethereum | `eth-mainnet.g.alchemy.com` | — |
| bsc | `bnb-mainnet.g.alchemy.com` | 第三方站点称有 BNB 主网端点，**官方是否支持、Token API 是否在 BNB 上可用均未核对** |
| arbitrum | `arb-mainnet.g.alchemy.com` | — |
| optimism | `opt-mainnet.g.alchemy.com` | — |
| base | `base-mainnet.g.alchemy.com` | — |
| polygon | `polygon-mainnet.g.alchemy.com` | — |

若核对后发现某条链不被支持，从 `alchemyHosts` 中删除该条目即可：适配器对表外的链返回 `UnsupportedFailure`（用户配置了自定义节点时仍可查原生币）。

| 用途 | 方法与路径 | 关键参数 | 返回中用到的字段 |
|---|---|---|---|
| 原生币余额 | POST `/v2/<Key>`，`eth_getBalance` | `params: [地址, "latest"]` | `result`：十六进制字符串（wei） |
| 交易计数 | `eth_getTransactionCount` | `params: [地址, "latest"]` | `result`：十六进制字符串 |
| 代币余额（含发现） | `alchemy_getTokenBalances` | `params: [地址, "erc20", {"maxCount": 100, "pageKey": "<上一页返回>"}]`（`pageKey` 仅翻页时带）。第二个参数 `"erc20"` 与 `maxCount` 上限 100 为未核对假设 | `result.tokenBalances[]`：`contractAddress`、`tokenBalance`（十六进制，可能带前导零）、`error`；`result.pageKey`（有下一页时存在） |
| 代币元数据 | `alchemy_getTokenMetadata` | `params: [合约地址]` | `result.decimals`（整数或 null）、`result.symbol`、`result.name`（可为 null）、`result.logo`（不使用） |

- 字段到领域模型的映射：原生币 → `RawHolding(NativeToken(链id))`，`symbolHint` 取链的原生币符号；代币 → `RawHolding(ContractToken(链id, 小写合约地址))`，`symbolHint`/`nameHint` 取元数据的 `symbol`/`name`（null 或空串为 null）；数量 = 十六进制整数按 `decimals`（原生币取链配置的 18）精确换算为 `Decimal`（整数移位，不经过浮点）。余额为 0、带 `error` 字段、`decimals` 缺失的代币不返回。
- 错误到 Failure 的映射：缺 Key → `UnauthorizedFailure('missing api key')`（不发请求）；HTTP 429 / JSON-RPC 错误码 429、-32005 → `RateLimitedFailure`；HTTP 401/403 / 错误码 401、403 → `UnauthorizedFailure`；-32601 → `UnsupportedFailure`；-32603 及 -32000 至 -32099 → `ServiceDownFailure`；其余错误对象 → `UnknownFailure`（`detail` 仅含方法名与错误码，不含 message）；HTTP 5xx 与网络错误由 `ow_net` 统一映射。获取代币元数据时单个代币的普通错误（`UnknownFailure`）只跳过该代币，限频/凭据/网络/服务故障使整次查询失败。
- 取不到的内容：自定义节点（标准 JSON-RPC）下无法发现代币，只返回原生币（界面应明示"未包含代币"）；元数据查不到小数位的代币被跳过。
- 备注：错误码与 429 的实际形态、`erc20` 参数、`maxCount` 上限、各主机名、免费档限频均须在真机冒烟时核对。单次查询的请求数 = 1（原生币）+ 代币页数 + 新代币数（元数据有内存缓存，同一合约只查一次）。
