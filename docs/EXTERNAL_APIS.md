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

- 官方文档（均于 2026-11-12 通过 `llms.txt` / `llms-full.txt` / 页面 `.md` 后缀直读原文）：
  - 支持的链与 URL：<https://www.alchemy.com/docs/reference/node-supported-chains>
  - Token API 概览：<https://www.alchemy.com/docs/reference/token-api-overview>
  - `alchemy_getTokenBalances`：<https://www.alchemy.com/docs/data/token-api/token-api-endpoints/alchemy-get-token-balances>
  - `alchemy_getTokenMetadata`：<https://www.alchemy.com/docs/data/token-api/token-api-endpoints/alchemy-get-token-metadata>
  - 错误参考：<https://www.alchemy.com/docs/reference/error-reference>
  - 吞吐量：<https://www.alchemy.com/docs/reference/throughput>；计算单元成本：<https://www.alchemy.com/docs/reference/compute-unit-costs>；套餐：<https://www.alchemy.com/docs/reference/pricing-plans>
- 核对日期：2026-11-12。除标注"未能核对"的条目外均已对照官方原文。**仍需用真实 Key 跑 `tools/smoke/README.md` 的冒烟脚本确认。**
- 鉴权方式（已核对）：Key 放在 URL 路径 `https://<主机>/v2/<API Key>`，POST、`Content-Type: application/json`、JSON-RPC 2.0（node-supported-chains 的 URL 表与各方法的 `POST https://eth-mainnet.g.alchemy.com/v2/{apiKey}`）。文档中另有 Bearer 头的写法，属于其他产品（Data API），Node 与 Token API 不用。
- 限频（已核对，throughput 与 pricing-plans）：按计算单元每秒（CU/s）限频，免费档 300 CU/s，在 10 秒滚动窗口内用令牌桶计量（可突发到 3000 CU / 10 秒）。限频在账户级而非应用级。各方法成本（compute-unit-costs）：`eth_getBalance` 20、`eth_getTransactionCount` 20、`alchemy_getTokenBalances` 20、`alchemy_getTokenMetadata` 10。适配器默认 `RateLimiter` 每秒 10 次，最坏 200 CU/s，低于 300。被限频时：HTTP 429；WebSocket 才返回 JSON-RPC 错误码 429；HTTP 响应**可能**带 `Retry-After`（整数秒，文档建议配合指数退避）。适配器同时把 HTTP 429 与 JSON-RPC 错误码 429 映射为 `RateLimitedFailure`，不读 `Retry-After`。
- 免费额度（已核对，pricing-plans）：免费档每月 30,000,000 CU（FAQ 同为 30M；quickstart 里"300 million"的说法与之矛盾，以套餐页为准）。超额时 HTTP 403，消息 `Monthly capacity limit exceeded.`（error-reference）；当前统一映射为 `UnauthorizedFailure`（`ow_net` 对 401/403 一视同仁），界面无法区分"Key 无效"与"额度用尽"，v1 接受。
- 各链端点（已核对，node-supported-chains；适配器内置于 `EvmChainAdapter.alchemyHosts`）与 Token API 可用性（已核对，各链 "API Overview" 页的接口列表均列出 Token API）：

| 链 id | 主机名 | 文档中的链名 | Token API |
|---|---|---|---|
| ethereum | `eth-mainnet.g.alchemy.com` | Ethereum Mainnet | 列出 |
| bsc | `bnb-mainnet.g.alchemy.com` | BNB Smart Chain Mainnet（**官方支持**） | 列出 |
| arbitrum | `arb-mainnet.g.alchemy.com` | Arbitrum Mainnet | 列出 |
| optimism | `opt-mainnet.g.alchemy.com` | OP Mainnet | 列出 |
| base | `base-mainnet.g.alchemy.com` | Base Mainnet | 列出 |
| polygon | `polygon-mainnet.g.alchemy.com` | Polygon PoS（Polygon Mainnet） | 列出 |

  "Feature Support by Chain"（<https://www.alchemy.com/docs/reference/feature-support-by-chain>）是前端动态组件，**未能核对**逐链逐方法的矩阵，仅凭各链 API Overview 页的列表判断；冒烟时请对六条链各跑一次 `alchemy_getTokenBalances`。

| 用途 | 方法与路径 | 关键参数 | 返回中用到的字段 |
|---|---|---|---|
| 原生币余额 | POST `/v2/<Key>`，`eth_getBalance` | `params: [地址, "latest"]` | `result`：十六进制字符串（wei） |
| 交易计数 | `eth_getTransactionCount` | `params: [地址, "latest"]` | `result`：十六进制字符串 |
| 代币余额（含发现） | `alchemy_getTokenBalances` | `params: [地址, "erc20", {"maxCount": 100, "pageKey": "<上一页返回>"}]`。已核对：第二个参数 `tokenSpec` 可为 `"erc20"`（默认）、`"NATIVE_TOKEN"`、`"DEFAULT_TOKENS"`（已弃用）或合约地址数组；第三个参数 `options` 含 `pageKey`、`maxCount`（默认且上限 100） | `result.address`、`result.tokenBalances[]`：`contractAddress`、`tokenBalance`（十六进制字符串，带前导零；出错时为 null）、`error`（文档：二者恰有一个非 null；文档示例有时省略 `error` 字段）。**未能核对**响应里翻页字段的名字：参数文档写 `pageKey` 用于翻页，但响应示例都没有该字段，适配器按 `result.pageKey` 读取 |
| 代币元数据 | `alchemy_getTokenMetadata` | `params: [合约地址]` | `result.name`、`symbol`、`decimals`（数字）、`logo`（URL），找不到时各字段为 null（已核对） |

- 字段到领域模型的映射：原生币 → `RawHolding(NativeToken(链id))`，`symbolHint` 取链的原生币符号；代币 → `RawHolding(ContractToken(链id, 小写合约地址))`，`symbolHint`/`nameHint` 取元数据的 `symbol`/`name`（null 或空串为 null）；数量 = 十六进制整数按 `decimals`（原生币取链配置的 18）精确换算为 `Decimal`（整数移位，不经过浮点）。余额为 0、带 `error` 或 `tokenBalance` 为 null、`decimals` 缺失的代币不返回。
- 错误到 Failure 的映射（依据 error-reference）：缺 Key → `UnauthorizedFailure('missing api key')`（不发请求）；HTTP 429 / JSON-RPC 错误码 429 → `RateLimitedFailure`；HTTP 401/403 / 错误码 401、403 → `UnauthorizedFailure`；-32601 → `UnsupportedFailure`；-32603 及 -32000 至 -32099 → `ServiceDownFailure`；其余错误对象（含 -32600、-32602、3）→ `UnknownFailure`（`detail` 仅含方法名与错误码，不含 message）；HTTP 5xx 与网络错误由 `ow_net` 统一映射。**2026-11-12 修正**：原先把 -32005 当作限频，官方文档中它属于 -32000..-32099 的服务端错误，已改为 `ServiceDownFailure`。获取代币元数据时单个代币的普通错误（`UnknownFailure`）只跳过该代币，限频/凭据/网络/服务故障使整次查询失败。
- 取不到的内容：自定义节点（标准 JSON-RPC）下无法发现代币，只返回原生币（界面应明示"未包含代币"）；元数据查不到小数位的代币被跳过。`alchemy_getTokenBalances` 的 `"erc20"` 模式按文档（Token API 概览）返回"地址曾经交互过的所有代币"，从未交互过但被空投的代币是否出现以实测为准。
- 备注：单次查询的请求数 = 1（原生币）+ 代币页数 + 新代币数（元数据有内存缓存，同一合约只查一次）。每个新代币 10 CU，一个有 100 个代币的地址首次同步约 20 + 20 + 1000 CU，免费档月额度 30M CU 约可支撑 2.9 万次这样的同步。

## CoinGecko（价格）

- 官方文档（2026-11-12 通过页面 `.md` 后缀、`llms.txt`、`llms-full.txt` 直读原文；Demo 档用 `/demo/reference/` 下的页面）：
  - 简单价格 https://docs.coingecko.com/demo/reference/simple-price
  - 按合约查币 https://docs.coingecko.com/demo/reference/coins-contract-address
  - 资产平台列表 https://docs.coingecko.com/demo/reference/asset-platforms-list
  - Demo 档鉴权 https://docs.coingecko.com/demo/reference/authentication
  - 无 Key 公共接口 https://docs.coingecko.com/docs/keyless-public-api
  - 错误与限频 https://docs.coingecko.com/docs/errors-and-rate-limits
- 核对日期：2026-11-12。下表逐项标注"已核对"或"未能核对"。
- 鉴权方式：
  - 根 URL `https://api.coingecko.com/api/v3`（已核对，Demo 鉴权页）。Pro 档用 `pro-api.coingecko.com` 与 `x-cg-pro-api-key`，v1 不支持。
  - Demo Key 放请求头 `x-cg-demo-api-key`（官方"推荐"），也接受查询参数 `x_cg_demo_api_key`（已核对）。本实现只用请求头，避免 Key 出现在 URL 与日志里。
  - 无 Key 可用（已核对，keyless-public-api）：直接请求，不带任何头；官方警告"不要带 `x-cg-demo-api-key`，会被忽略"。注意：无 Key 档要求展示 CoinGecko 署名（Attribution），见 https://brand.coingecko.com/resources/attribution-guide ——**界面需另行落实**（超出本适配器范围）。Demo 档是否同样要求署名**未能核对**。
  - Key 通过 `DataSourceConfig.apiKey('coingecko')` 读取，可为空；日志拦截器对 `x-cg-demo-api-key` 脱敏。
- 限频：
  - 无 Key（已核对）：约 5 次/分钟，随服务负载浮动，同一 IP 共享，不适合生产与定时轮询。
  - Demo 档（已核对，errors-and-rate-limits）：**100 次/分钟**。实现取更保守的 30 次/分钟（`RateLimiter`）。
  - 所有请求（含 4xx、5xx）都计入每分钟限额；超限返回 HTTP 429（已核对）。官方页面未提到 `Retry-After`，不依赖它。官方错误页没有给出 429 的响应体样例，**未能核对**响应体形式，测试里的 `error_429.json` 仍是示意。
  - 月度额度：官方页面只写"每次成功请求（HTTP 200）扣 1 个 credit，月度 credit 取决于套餐"，**未能核对**Demo 档的具体月度总量（定价页不在放行范围内）；旧记录里的"约 1 万次/月"无法证实，不再作为依据。
- 本地缓存：同一 (assetId, 计价货币) 5 分钟内不重复请求（内存缓存，时间来自注入的 `Clock`）。合约查询结果（含"查不到"）缓存 1 小时。

| 用途 | 方法与路径 | 关键参数 | 返回中用到的字段 |
|---|---|---|---|
| 按币种标识批量查价 | `GET /simple/price` | 已核对：`vs_currencies`（必填）、`ids`、`include_24hr_change`、`include_last_updated_at`、`precision`（`full` 或 0 至 18）。实现传 `precision=full`（见下） | `{id: {"usd": 数, "usd_24h_change": 数, "last_updated_at": Unix 秒}}`（已核对官方示例；文档注明 24 小时涨跌在价格过期时为 null） |
| 按合约查币种 | `GET /coins/{asset_platform_id}/contract/{contract_address}` | 已核对：Demo 档文档列出该接口（endpoint-overview 与 keyless 页的 Demo 列表），**文档没有任何查询参数**，实现不再带 `localization`、`tickers` 等开关 | 已核对：顶层 `id`（coin id，即 `priceId`）、`symbol`、`name`；另有 `asset_platform_id`、`platforms`、`detail_platforms`（含 `decimal_place`） |
| （未使用）按合约查价 | `GET /simple/token_price/{id}` | `contract_addresses`、`vs_currencies` | 返回以合约地址为键的价格，**不含 coin id**，无法产出 `Asset.priceId`，故不用 |

- 单次请求数量上限：
  - `simple/price` 的 `ids`：官方上限 **515**（已核对）。实现取更保守的 100 一批（`maxIdsPerRequest`），同时避免 URL 过长。
  - `/coins/{平台}/contract/{地址}` 每次只能查一个合约，故 `lookupContracts` 按合约逐个请求，每次调用最多 20 个（`maxLookupsPerCall`），超出的留给下次调用。
- **精度**：官方 `precision` 参数说明为"价格的小数位数"，枚举含 `full`；文档**未说明省略该参数时的默认小数位数**，因此实现显式传 `precision=full`，避免低价币（如 PEPE、SHIB）被截断。该参数需在真实接口上冒烟确认被接受。
- 9 条链对应的 asset platform id：

| 链 | platform id | 核对 |
|---|---|---|
| ethereum | `ethereum` | 已核对（contract 页参数说明与示例 `ethereum`） |
| bsc | `binance-smart-chain` | 已核对（llms-full 示例 `platforms` 里出现） |
| arbitrum | `arbitrum-one` | **未能核对**（放行的文档里没有出现，来自既有知识） |
| optimism | `optimistic-ethereum` | **未能核对**（同上） |
| base | `base` | **未能核对**（同上；文档里的 `base` 是 GeckoTerminal 网络 id，不是 asset platform id） |
| polygon | `polygon-pos` | 已核对（contract 页参数说明 "ethereum, polygon-pos, solana"） |
| solana | `solana` | 已核对（asset-platforms-list 示例） |
| tron | `tron` | 已核对（contract 页示例 `platforms.tron`） |
| bitcoin | 无（没有合约代币） | — |

  完整列表需要 `/asset_platforms`，其所在的 `api.coingecko.com` 不在放行范围，**未能核对**；冒烟脚本应调用一次确认三个未核对的 id。

- 字段到领域模型的映射：
  - `Price.price` = `{vs}`，`Price.change24hPercent` = `{vs}_24h_change`（百分数，如 `3.6` 表示涨 3.6%），`Price.updatedAt` = `last_updated_at`（缺失时用注入时钟的当前时间）。
  - **数字精度**：`dart:convert` 的 `jsonDecode` 会把带小数点的数字先变成 `double`，二进制浮点已经不是原来的十进制数。实现用自带的 `parseJsonExact` 解析响应，数字保留原文（`JsonNumber`），直接用文本构造 `Decimal`，指数写法（`1.2e-7`）先展开。若调用方传入的已是 `double`，则用其最短往返字符串（`double.toString()`）构造，不使用二进制展开。
  - `Asset`（来自合约查询）：`priceId` = 响应 `id`，`symbol`/`id` = 大写 `symbol`，`name` = 响应 `name`。若 `id` 与内置币种的 `priceId` 相同，返回内置币种；若符号与内置币种 id 相同但 coin id 不同，则 `id` 加 `-<COIN-ID>` 后缀，防止同名仿冒币被当成真币估值。
  - 返回里缺少某个币、没有对应货币的价格、价格不是数字或不大于 0：该币不出现在结果中（界面显示"—"，R9）。
- 错误码到 Failure 的映射（`ow_net` 的 `mapHttpFailure`）：
  - 429 → `RateLimitedFailure`；401（Key 缺失或无效）→ `UnauthorizedFailure`；5xx → `ServiceDownFailure`；连接失败、超时 → `NetworkFailure`；响应不是合法 JSON → `UnknownFailure`。
  - 403 官方解释为"Access blocked by the server"（已核对，errors-and-rate-limits），与"Key 无效"不同；`fetchPrices` 中仍按 `UnauthorizedFailure` 返回。`lookupContracts` 中 403 与 404 一样视为"查不到"，返回空映射（免费档不支持该接口时不应让同步失败）。
  - 分批请求中任一批失败，整次 `fetchPrices` 返回该失败；已成功批次已进缓存，重试只补发失败的批次。
- 取不到的内容（会在界面明示"未包含"）：CoinGecko 没有收录或没有报价的代币（垃圾币、新币）——无价格，估值显示"—"，不计入总额。CoinGecko 对部分链的合约代币没有收录（以平台为准）。
- 备注：
  - 内置映射表 `priceId` 的核对结论见 `packages/ow_pricing/SOURCES.md`（`/coins/list` 不可达，仅少数 id 在官方文档示例中出现）；`packages/ow_pricing/tool/smoke_price.dart --catalog` 会用真实接口逐个验证（见 `tools/smoke/README.md`），上线前必须运行。
  - 测试样本在 `packages/ow_pricing/test/fixtures/`：`simple_price_doc.json`、`contract_weth_doc.json` 取自官方文档示例；其余按文档结构手工整理，数值为示意，不是真实响应。
  - 用户填写 Pro Key 的场景（需换主机与请求头名）v1 不支持，属于 PRD 之外，需要时另行加任务。

## mempool.space（Bitcoin）

- 官方文档：REST API <https://mempool.space/docs/api/rest>。该页是前端渲染的单页应用，`llms.txt`、`.md` 后缀、`sitemap.xml` 都只返回 SPA 外壳；**2026-11-12 改为读取站点前端的懒加载脚本**（`https://mempool.space/320.<hash>.js`，内含 API 文档页的全部文案、路径与示例响应）取得官方文档原文，并对 `mempool.space` 的真实接口发了只读请求核对字段（本节标"实测"）。
- 核对日期：2026-11-12。除标注"未能核对"的条目外均已对照官方原文或实测。
- 鉴权方式（已核对）：无需 Key。自定义实例（自建 mempool 或其他 Esplora 兼容服务）通过 `DataSourceConfig.customEndpoint('bitcoin')` 配置，必须 https，路径前缀保留。
- 限频（部分核对）：文档页原文："Note that we enforce rate limits. If you exceed these limits, you will get an HTTP 429 error. If you repeatedly exceed the limits, you may be banned from accessing the service altogether."；定价页写明付费档有"更高的 REST API 限额（API Key 或 IP 白名单）"。**具体的每秒/每分钟数值未能核对**（文档未给）。适配器默认 `RateLimiter` 每秒 2 次，一次同步只发 1 个请求。被限频时 HTTP 429 → `RateLimitedFailure`；`Retry-After` 是否存在**未能核对**，不依赖。多个地址同步时由上层逐个调用，请保持在此速率内。
- 免费额度：无（公共实例免费，受上述限频约束）。

| 用途 | 方法与路径 | 关键参数 | 返回中用到的字段 |
|---|---|---|---|
| 地址余额与交易计数 | GET `/api/address/{地址}` | 路径参数：P2PKH（`1…`）、P2SH（`3…`）、bech32（`bc1q…`）、bech32m（`bc1p…`）均可（实测四种都返回 200） | 已核对（文档原文与实测一致）：`address`；`chain_stats`、`mempool_stats` 各含 `funded_txo_count`、`funded_txo_sum`、`spent_txo_count`、`spent_txo_sum`、`tx_count`。`chain_stats` 为已确认，`mempool_stats` 为内存池（未确认）。金额单位聪，整数 |

- 字段到领域模型的映射：余额（聪）= `chain_stats.funded_txo_sum − chain_stats.spent_txo_sum`，除以 10^8 得 BTC（`Decimal` 整数移位，不经过浮点）→ `RawHolding(NativeToken('bitcoin'))`，`symbolHint`=`BTC`、`nameHint`=`Bitcoin`；余额为 0 时不返回。`hasActivity` = `chain_stats.tx_count + mempool_stats.tx_count > 0`。
- **余额口径（自行决定）：只计已确认**。`mempool_stats`（未确认）不计入余额：未确认的收入可能被替换（RBF）或丢弃，未确认的支出也可能不被打包，看板只展示链上已落定的数量。区块浏览器网页默认显示的余额可能含未确认部分（其前端代码用"确认+内存池"计算总余额），与本应用有短暂差异属预期。`hasActivity` 则把未确认交易也算作活动。
- 错误到 Failure 的映射：HTTP 429 → `RateLimitedFailure`；5xx → `ServiceDownFailure`；网络/超时 → `NetworkFailure`（均由 `ow_net` 统一映射）；非法地址：实测返回 HTTP 400 与纯文本 `Invalid Bitcoin address`，`ow_net` 对 400 一律映射为 `UnknownFailure('HTTP 400 host=…')`（不含地址与响应体）；响应不是 JSON 或缺少必需字段、字段不是整数、已确认支出大于收入 → `UnknownFailure`；地址含 `/`、`.`、`?` 等非字母数字字符 → `ValidationFailure`（不发请求）。
- 取不到的内容：Bitcoin 没有代币，只有原生币；Ordinals/Runes/BRC-20 等铭文资产不在范围内（它们占用的聪仍计入余额）。
- 备注：
  - 测试样本 `packages/ow_chains/test/fixtures/btc_*.json` 中 `p2pkh_doc`（官方文档示例地址 `1wiz18…`）、`p2sh`、`bech32`、`bech32m`、`bech32_big` 是 2026-11-12 从公共接口取得的真实响应（公开的知名地址，随时间会变化，测试只依赖固定副本）；`new_address`、`mempool_only`、`pending_spend` 是按同一结构手工构造的边界样本。
  - 冒烟脚本 `packages/ow_chains/tool/smoke_btc.dart` 见 `tools/smoke/README.md`；开发时已用该脚本对真实接口查询 `1wiz18…`，返回结构与解析一致。
