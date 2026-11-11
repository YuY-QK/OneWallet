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

（尚无记录。）

## CoinGecko（价格）

- 官方文档：
  - 简单价格 https://docs.coingecko.com/reference/simple-price
  - 按合约查价 https://docs.coingecko.com/reference/simple-token-price
  - 按合约查币 https://docs.coingecko.com/reference/coins-contract-address
  - 资产平台列表 https://docs.coingecko.com/reference/asset-platforms-list
  - 无 Key 公共接口 https://docs.coingecko.com/docs/keyless-public-api
  - 错误与限频 https://docs.coingecko.com/docs/errors-and-rate-limits
- 核对日期：2026-11-11
- 核对方式与可信度：核对时网页抓取工具无法访问 docs.coingecko.com（域名不可达），只能用网页搜索得到官方文档页的摘要，**没有逐页直读原文**。下表中标"摘要核对"的是搜索结果里官方页面明确给出的内容；标"未核对"的是凭既有知识写入的，务必在联网环境对照上面的链接复核，复核后改写本节。
- 鉴权方式：
  - 主机 `https://api.coingecko.com/api/v3`（Demo 档，摘要核对）。Pro 档用 `pro-api.coingecko.com` 与 `x-cg-pro-api-key`，v1 不支持。
  - Demo Key 放在请求头 `x-cg-demo-api-key`（摘要核对）；官方也接受查询参数 `x_cg_demo_api_key`，本实现只用请求头，避免 Key 出现在 URL 与日志里。
  - 无 Key 可用：免费公共接口无需 Key，带上 Key 头会被忽略（摘要核对）。
  - Key 通过 `DataSourceConfig.apiKey('coingecko')` 读取，可为空；日志拦截器对 `x-cg-demo-api-key` 脱敏。
- 限频：
  - 无 Key：官方称约 5 次/分钟，随服务负载浮动，同一 IP 共享，不适合生产与定时轮询（摘要核对）。
  - Demo 档：文档间两种说法，30 次/分钟、每月约 1 万次，另一页写 100 次/分钟（摘要核对，说法不一）。实现按 30 次/分钟限速（`RateLimiter`），取较小值。
  - 所有请求（含 4xx、5xx）都计入限额，超限返回 HTTP 429（摘要核对）。官方页面未提到 `Retry-After` 响应头，不依赖它。
- 免费额度（如适用）：Demo 档约 1 万次调用/月（摘要核对）。
- 本地缓存：同一 (assetId, 计价货币) 5 分钟内不重复请求（内存缓存，时间来自注入的 `Clock`）。合约查询结果（含"查不到"）缓存 1 小时。

| 用途 | 方法与路径 | 关键参数 | 返回中用到的字段 |
|---|---|---|---|
| 按币种标识批量查价 | `GET /simple/price` | `ids`（逗号分隔的 coin id）、`vs_currencies`（`usd` / `cny`）、`include_24hr_change=true`、`include_last_updated_at=true` | `{id: {"usd": 数, "usd_24h_change": 数或 null, "last_updated_at": Unix 秒}}`（摘要核对涨跌字段与 `last_updated_at`；24 小时涨跌在价格过期时为 null） |
| 按合约查币种 | `GET /coins/{asset_platform_id}/contract/{contract_address}` | `localization=false&tickers=false&market_data=false&community_data=false&developer_data=false&sparkline=false`（减小响应，**未核对**这些开关的名字） | `id`（coin id，即 `priceId`）、`symbol`、`name`（路径与 `id` 为平台标识摘要核对；字段名未核对原文） |
| （未使用）按合约查价 | `GET /simple/token_price/{id}` | `contract_addresses`、`vs_currencies` | 返回以合约地址为键的价格，**不含 coin id**，无法产出 `Asset.priceId`，故不用 |

- 单次请求数量上限：
  - `simple/price` 的 `ids` 数量：官方页面未在摘要中给出明确上限（**未核对**）。实现取保守值 100 一批（`maxIdsPerRequest`），同时避免 URL 过长。
  - `simple/token_price` 的合约数量：Demo 文档称最多 515 个（摘要核对），但本实现不使用该接口。
  - `/coins/{平台}/contract/{地址}` 每次只能查一个合约，故 `lookupContracts` 按合约逐个请求，每次调用最多 20 个（`maxLookupsPerCall`），超出的留给下次调用。
- 9 条链对应的 asset platform id：

| 链 | platform id | 核对 |
|---|---|---|
| ethereum | `ethereum` | 摘要核对 |
| bsc | `binance-smart-chain` | 摘要核对 |
| arbitrum | `arbitrum-one` | 摘要核对 |
| optimism | `optimistic-ethereum` | 摘要核对（CoinGecko 的 OP、USDC 平台映射里出现） |
| base | `base` | 摘要核对 |
| polygon | `polygon-pos` | 摘要核对 |
| solana | `solana` | 摘要核对 |
| tron | `tron` | 摘要核对 |
| bitcoin | 无（没有合约代币） | — |

- 字段到领域模型的映射：
  - `Price.price` = `{vs}`，`Price.change24hPercent` = `{vs}_24h_change`（百分数，如 `3.6` 表示涨 3.6%），`Price.updatedAt` = `last_updated_at`（缺失时用注入时钟的当前时间）。
  - **数字精度**：`dart:convert` 的 `jsonDecode` 会把带小数点的数字先变成 `double`，二进制浮点已经不是原来的十进制数。实现用自带的 `parseJsonExact` 解析响应，数字保留原文（`JsonNumber`），直接用文本构造 `Decimal`，指数写法（`1.2e-7`）先展开。若调用方传入的已是 `double`，则用其最短往返字符串（`double.toString()`）构造，不使用二进制展开。
  - `Asset`（来自合约查询）：`priceId` = 响应 `id`，`symbol`/`id` = 大写 `symbol`，`name` = 响应 `name`。若 `id` 与内置币种的 `priceId` 相同，返回内置币种；若符号与内置币种 id 相同但 coin id 不同，则 `id` 加 `-<COIN-ID>` 后缀，防止同名仿冒币被当成真币估值。
  - 返回里缺少某个币、没有对应货币的价格、价格不是数字或不大于 0：该币不出现在结果中（界面显示"—"，R9）。
- 错误码到 Failure 的映射（`ow_net` 的 `mapHttpFailure`）：
  - 429 → `RateLimitedFailure`；401（Key 缺失或无效）→ `UnauthorizedFailure`；5xx → `ServiceDownFailure`；连接失败、超时 → `NetworkFailure`；响应不是合法 JSON → `UnknownFailure`。
  - 403 官方解释为"被服务器拦截"（摘要核对），与"Key 无效"不同；`fetchPrices` 中仍按 `UnauthorizedFailure` 返回。`lookupContracts` 中 403 与 404 一样视为"查不到"，返回空映射（免费档不支持该接口时不应让同步失败）。
  - 分批请求中任一批失败，整次 `fetchPrices` 返回该失败；已成功批次已进缓存，重试只补发失败的批次。
- 取不到的内容（会在界面明示"未包含"）：CoinGecko 没有收录或没有报价的代币（垃圾币、新币）——无价格，估值显示"—"，不计入总额。CoinGecko 对部分链的合约代币没有收录（以平台为准）。
- 备注：
  - 内置映射表 `priceId` 同样未能对照 CoinGecko 官方币种清单核对；`packages/ow_pricing/tool/smoke_price.dart --catalog` 会用真实接口逐个验证（见 `tools/smoke/README.md`），上线前必须运行。
  - 测试样本在 `packages/ow_pricing/test/fixtures/`，结构按上述文档示例手工整理（因文档原页不可达，没有取自真实响应），数值为示意。
  - 用户填写 Pro Key 的场景（需换主机与请求头名）v1 不支持，属于 PRD 之外，需要时另行加任务。
