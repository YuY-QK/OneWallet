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

## Solana RPC（Helius 与官方公共节点）

- 官方文档：
  - **Solana 官方 RPC 文档（<https://solana.com/docs/rpc>）2026-11-12 未能读取**：`solana.com` 对非浏览器客户端返回 HTTP 429 与 Vercel 安全检查页（`llms.txt`、页面 `.md` 后缀、`sitemap.xml` 都一样），因此**官方公共节点的主机名、限频、使用限制全部未能核对**。
  - 改读 Helius 文档（2026-11-12 通过 <https://docs.helius.dev/llms-full.txt> 直读原文，Helius 复述了标准 RPC 方法的参数与返回结构，不等同于 Solana 基金会文档）：
    - `getBalance`：<https://www.helius.dev/docs/api-reference/rpc/http/getbalance> 与指南 <https://www.helius.dev/docs/rpc/guides/getbalance>
    - `getTokenAccountsByOwner`：<https://www.helius.dev/docs/api-reference/rpc/http/gettokenaccountsbyowner> 与指南 <https://www.helius.dev/docs/rpc/guides/gettokenaccountsbyowner>
    - `getSignaturesForAddress`：<https://www.helius.dev/docs/rpc/guides/getsignaturesforaddress>
    - 限频与错误：<https://www.helius.dev/docs/billing/rate-limits>、<https://www.helius.dev/docs/faqs/error-codes>
- 核对日期：2026-11-12。**仍需用真实 Key 跑冒烟脚本**（本环境访问不到任何 Solana RPC 主机）。
- 端点与鉴权：
  - 自定义节点（`DataSourceConfig.customEndpoint('solana')`，必须 https）：优先级最高，查询串原样保留，其中的**所有查询参数名**都按敏感信息脱敏（`OwHttpConfig.extraSensitiveNames`）；路径里的不透明长段由 `ow_net` 的路径脱敏处理。
  - 配置了 `apiKey('helius')`：`POST https://mainnet.helius-rpc.com/?api-key=<Key>`（已核对：DAS 概览与各方法示例；错误码页写明 Key 以 `?api-key=` 传递）。Helius 文档另说 WebSocket 与 Parsed Streams 可用 `x-api-key` 请求头，**RPC 是否接受该头未能核对**，故用查询参数。`ow_net` 的敏感名称规则含 `key`，`api-key` 已被脱敏（只保留前 4 位），已有测试覆盖，无需 `extraSensitiveNames`；用户自定义端点的参数名则逐个加入 `extraSensitiveNames`。
  - 都没有配置：`POST https://api.mainnet-beta.solana.com/`（**主机名来自既有知识，未能核对**）。
- 限频：
  - Helius（已核对，rate-limits 页）：免费档 RPC 10 次/秒（月 100 万 credits），Developer 50、Business 200、Professional 500；超限 HTTP 429。限频对所有 RPC 方法合计，不是按方法分别计。`getProgramAccounts` 另有更严限制（本适配器不用）。各方法的 credit 消耗**未能核对**。适配器默认 `RateLimiter` 每秒 5 次（低于免费档的 10）。官方建议 429、503、5xx 退避重试（首次约 1 秒，翻倍，上限 30 秒）；适配器不自动重试，由上层决定。`Retry-After` 响应头在文档示例里被读取，但文档未保证存在，不依赖。
  - 官方公共节点：限频与"仅限开发/测试、不得用于生产"之类的使用限制**未能核对**。可以预期它对 `getTokenAccountsByOwner` 这类较重的方法限制更严；只在用户没有配置 Helius Key 时作为后备，界面应提示"公共节点可能限频，建议配置自己的 Key"。

| 用途 | 方法 | 参数（本适配器实际发送） | 返回中用到的字段 |
|---|---|---|---|
| SOL 余额 | `getBalance` | `[地址, {"commitment": "finalized"}]`（文档：commitment 取 `processed`/`confirmed`/`finalized`；`getBalance` 默认 finalized） | `result.value`：lamports，无符号 64 位整数（已核对）。账户不存在时通常返回 0（已核对） |
| 代币账户 | `getTokenAccountsByOwner` | `[地址, {"programId": <程序>}, {"encoding": "jsonParsed", "commitment": "finalized"}]`，对两个程序各发一次（文档：filter 必须给 `mint` 或 `programId` 之一） | `result.value[]`：`account.data.parsed.info.mint`、`info.tokenAmount.amount`（整数字符串）、`info.tokenAmount.decimals`（数字）；另有 `uiAmount`（浮点，**不使用**）、`uiAmountString`、`state`、`isNative`（均已核对） |
| 是否有交易 | `getSignaturesForAddress` | `[地址, {"limit": 1, "commitment": "finalized"}]`（文档：limit 默认与上限 1000；commitment 仅支持 `finalized`、`confirmed`） | `result[]` 是否非空；每项含 `signature`、`slot`、`err`、`memo`、`blockTime`、`confirmationStatus`（已核对） |

- 两个代币程序的地址（已核对，Helius 指南原文："SPL Token Program: `TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA`；Token-2022 Program: `TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb`"）。**未能对照 Solana 官方文档**。
- 字段到领域模型的映射：
  - SOL → `RawHolding(NativeToken('solana'))`，`symbolHint`=`SOL`、`nameHint`=`Solana`；lamports ÷ 10^9，`Decimal` 整数移位；余额为 0 不返回。
  - 代币 → `RawHolding(ContractToken('solana', mint))`（mint 为 Base58，区分大小写，原样保留）。**`symbolHint`/`nameHint` 为空**：RPC 不返回元数据，由币种目录与价格源识别。数量 = `amount`（整数字符串，用 `BigInt` 解析）÷ 10^`decimals`；**不使用 `uiAmount`**。
  - **同一 mint 多个代币账户合并求和**（一个钱包可持有同一代币的多个账户）。
  - **NFT 过滤规则**：合并后 `decimals == 0` 且数量恰为 1 的 mint 视为 NFT，不返回。代价：恰好持有 1 个最小单位的 0 位小数同质化代币会被误滤，v1 接受；压缩 NFT（cNFT）不是代币账户，本来就不会出现。
  - 数量为 0 的账户、`amount` 不是非负整数串或 `decimals` 越界的账户被跳过（单个坏条目不使整次查询失败）。包装 SOL（wSOL）的代币账户按普通代币返回，由上层映射表决定是否归并到 SOL。
- 错误到 Failure 的映射：HTTP 429 → `RateLimitedFailure`；401/403 → `UnauthorizedFailure`；5xx → `ServiceDownFailure`；网络/超时 → `NetworkFailure`（`ow_net`）。JSON-RPC `error`：`detail` 只含方法名与错误码，不含 message。`-32005`：Helius 文档的限频响应形式是 `{"error": {"code": -32005, "message": "Too many requests"}}`（已核对，rate-limits 页），而 Solana 节点自身用 `-32005` 表示 `Node is unhealthy`（来自既有知识，**未能核对**），所以按 message 区分（含 `too many` 或 `rate` → `RateLimitedFailure`，否则 `ServiceDownFailure`）；`429` → 限频；`401/403` → `UnauthorizedFailure`；`-32601` → `UnsupportedFailure`；`-32602`（Helius 文档：非法公钥、未知字段、不支持的 commitment）→ `ValidationFailure`；`-32603` 与其余 `-32000..-32099` → `ServiceDownFailure`；其他 → `UnknownFailure`。
- 取不到的内容：
  - 代币的符号、名称（RPC 不返回），无法识别的代币在界面上只能显示缩略的 mint；
  - NFT 与 cNFT（按规则过滤，不计价）；
  - 质押在验证者上的 SOL（质押账户是独立账户，不在钱包地址的 `getBalance` 里）——**v1 未包含**，界面应明示；
  - 未领取的奖励、DeFi 协议里的头寸。
- 备注：
  - 一次 `fetchHoldings` 发 3 个请求（`getBalance` 加两个 programId）。代币很多的钱包响应体可能很大；Helius 提供支持分页的 `getTokenAccountsByOwnerV2`（上限每页 1 万个账户），本适配器 v1 不用，**超大钱包的实际表现未能核对**。
  - 测试样本 `packages/ow_chains/test/fixtures/sol_token_accounts_*.json` 按 Helius 指南描述的结构手工整理（含 `rentEpoch` 为 2^64−1 的真实形态，用来验证大整数不会破坏解析）；地址与代币账户是假数据，其中 USDC、USDT、PYUSD 的 mint 是真实地址，其余 mint 为假。数值是示意，不是真实响应。

## TronGrid（Tron）

- 官方文档（2026-11-12 通过 <https://developers.tron.network/llms.txt> 的索引与各页面 `.md` 后缀直读原文，含完整 OpenAPI 定义）：
  - 获取账户信息：<https://developers.tron.network/reference/get-account-info-by-address>
  - 获取 TRC-20 余额：<https://developers.tron.network/reference/get-trc20-token-balances-by-address>
  - 获取 TRC-20 合约信息：<https://developers.tron.network/reference/get-trc-20-token-information>
  - API Key：<https://developers.tron.network/reference/select-network>；限频：<https://developers.tron.network/reference/rate-limits>
  - 委托资源（Stake 2.0）：<https://developers.tron.network/docs/delegation>；全节点 `GetAccount`：<https://developers.tron.network/reference/account-getaccount>
- 核对日期：2026-11-12。除标注"未能核对"的条目外均已对照官方原文。**本环境访问不到 `api.trongrid.io`，未做真实接口调用，仍需用冒烟脚本确认。**
- 主机（已核对）：主网 `https://api.trongrid.io`（另有 Shasta、Nile 测试网，不用）。
- 鉴权（已核对）：请求头 `TRON-PRO-API-KEY: <Key>`（Key 可在 TronGrid 控制台创建）。**无 Key 是否可用**：文档只说"无 Key 的请求可能被严格限频或拒绝"，没有给出确切行为，**未能核对**；适配器无 Key 时照常请求，不带该头。Key 通过 `DataSourceConfig.apiKey('trongrid')` 读取；`ow_net` 的敏感名称规则含 `key`，请求头 `TRON-PRO-API-KEY` 被脱敏（保留前 4 位），有测试覆盖。**Key 只发往默认主机**，自定义节点（`customEndpoint('tron')`，必须 https，路径前缀保留）不会收到。
- 限频（部分核对）：官方明确"不要把固定限额写进业务逻辑，以控制台和实时响应为准"；限频维度有 API Key、账户、IP、接口类型，每秒/每分钟/每天窗口并存；超限返回 429，"异常高频轮询"可能被临时封禁并返回 403；建议指数退避并缓存。**具体数值未能核对**（文档未给）。适配器默认 `RateLimiter` 每秒 3 次；一次同步最少 2 个请求（账户、TRC-20 余额），每多一页或每多 20 个未知合约再加 1 个。429 响应体形如 `{"success": false, "error": "The key exceeds the frequency limit", "statusCode": 429}`（已核对）。

| 用途 | 方法与路径 | 关键参数 | 返回中用到的字段 |
|---|---|---|---|
| TRX 与质押 | GET `/v1/accounts/{地址}` | 地址为 Base58 或 Hex（用 Base58）；另有 `only_confirmed`、`only_unconfirmed`（不用，默认两者都含） | `data[]`（未激活地址为空数组，见下）：`balance`（整数，sun，1 TRX = 10^6 sun，"可用余额"）；`frozenV2[].amount`（Stake 2.0 质押，sun，**条目可能省略 `amount` 或 `type`**）；`delegated_frozenV2_balance_for_bandwidth`、`account_resource.delegated_frozenV2_balance_for_energy`（本账户质押后委托给他人的 TRX，sun）；`unfrozenV2[].unfreeze_amount`（已申请解锁、等待提取的 TRX，仅在有时返回）。示例响应（官方）：`{"data":[{"address":"41…","balance":1000000,"frozenV2":[{},{"type":"ENERGY"},{"type":"TRON_POWER"}],…}],"success":true,"meta":{"at":…,"page_size":1}}` |
| TRC-20 余额（分页） | GET `/v1/accounts/{地址}/trc20/balance` | `limit`（默认 20，最大 200，本实现用 200）、`fingerprint`（取上一页 `meta.fingerprint`）、`contract_address`（不用） | `data[]`：每项是 **{合约 Base58 地址: 最小单位余额字符串}**，零余额的代币被省略，**不含 decimals、name、symbol**（已核对）；`meta.fingerprint` 存在表示还有下一页（`meta.links.next` 同理）。示例（官方，Nile）：`{"data":[{"TXYZopYRdj2D9XRtbG411XZZ3kM5VkAeBf":"4999997900"}],"success":true,…}`；无余额时 `data` 为 `[]` |
| TRC-20 合约信息 | GET `/v1/trc20/info` | `contract_list`：逗号分隔的合约地址，**最多 20 个**（已核对） | `data[]`：`contract_address`、`symbol`、`name`、`decimals`（**字符串**，如 `"6"`）、`type`、`total_supply`（整数串）。是只读的 GET 查询 |

- **decimals 的获取方式（自行决定）**：任务提示可用 `triggerconstantcontract` 调合约的 `decimals()`，但读文档发现 TronGrid 有专门的只读 GET 接口 `/v1/trc20/info`（批量、带符号与名称），故**不使用 `triggerconstantcontract`**（它是 POST，且属于“模拟合约调用”，语义上更接近交易构造；`tools/ci/check_deps.dart` 只扫描 `ow_exchanges`，不会拦截，但没有必要引入）。适配器顺序：构造参数 `knownDecimals`（合约 → decimals，由装配层传入）→ `/v1/trc20/info`（带内存缓存，只缓存查到的）→ 仍查不到则**跳过该代币**。注意：内置映射表 `asset_mappings.json` 目前**没有 decimals 字段**，装配层需要自行提供（见汇报的建议）；不提供时全部走 `/v1/trc20/info`，只是多几个请求。
- 为什么不用 `/v1/accounts/{地址}` 返回的 `trc20` 数组：文档只写"TRC-20 balance held by this account"，没有给出元素形态与分页方式；专用的 `/trc20/balance` 接口有明确的分页和示例。
- 字段到领域模型的映射：
  - TRX → `RawHolding(NativeToken('tron'))`，`symbolHint`=`TRX`、`nameHint`=`Tron`；数量 = (可用 + 质押口径) ÷ 10^6，`Decimal` 整数移位。
  - **TRX 口径（自行决定）**：可用 `balance` + Stake 2.0 的 `frozenV2[].amount` + 已委托出去的 `delegated_frozenV2_balance_for_bandwidth`/`…_for_energy` + 解锁等待中的 `unfrozenV2[].unfreeze_amount`。理由：这些 TRX 仍归用户所有。**不计**：Stake 1.0 的旧字段（`frozen`、`account_resource.frozen_balance_for_energy`、`delegated_frozen_balance_for_*`；已弃用，且文档没有说明 1.0 下委托部分是否与 `frozen` 重复，为避免重复计入而不加）；`allowance`（未领取的投票奖励）；他人委托给本账户的资源（`acquired_delegated_*`，不是本账户的资产）。
  - **未能核对**：`frozenV2[].amount` 是否已扣除委托出去的部分。文档只说委托后"原始质押的 TRX 仍在你名下"；本实现按 java-tron 的实现印象（委托时从 `frozenV2` 转入 `delegated_frozenV2_*`）把两者相加。若实际 `frozenV2` 已包含委托部分，会重复计入，请按真机清单用有委托的账户核对。
  - TRC-20 → `RawHolding(ContractToken('tron', Base58合约地址))`，原样保留大小写；`knownDecimals` 命中的合约不带符号/名称提示（交给币种目录），否则取 `/v1/trc20/info` 的 `symbol`/`name`；余额为 0、`decimals` 查不到的代币不返回。
  - **未激活的地址**：`data` 为空数组，视为零 TRX、`hasActivity=false`，不是错误（任务约定；官方示例文档未给出该情形的响应样例，**未能核对**空数组之外是否还有其他形式，如 404）。因为未激活地址理论上也可能被转入 TRC-20，适配器仍会查询 TRC-20 余额。
- 错误到 Failure 的映射：HTTP 429 → `RateLimitedFailure`；401/403 → `UnauthorizedFailure`（官方说 403 也可能是临时封禁或安全设置拦截，界面无法区分，v1 接受）；5xx → `ServiceDownFailure`；网络/超时 → `NetworkFailure`（`ow_net`）。400 的响应体形如 `{"success":false,"error":"A valid account address is required.","statusCode":400}` → `ow_net` 映射为 `UnknownFailure('HTTP 400 …')`（不含地址与响应体）。另外对 **HTTP 200 但 `success` 为 `false`** 的响应按 `statusCode` 再映射一次（429/401/403/≥500），其余 `UnknownFailure`（官方没有说明会不会出现，防御性处理）。合约信息接口的普通错误（`UnknownFailure`）只跳过该批，限频/凭据/网络/服务故障使整次查询失败。
- 取不到的内容：TRC-10 资产（`assetV2`）、TRC-721/1155（v1 不含）；Stake 1.0 的质押；未领取的投票奖励；他人委托给本账户的资源；能量/带宽（不是资产）。
- 备注：测试样本 `packages/ow_chains/test/fixtures/tron_*.json`：`tron_account_doc.json` 是官方文档的示例响应（原样），`tron_trc20_*` 按官方示例的结构整理（`TXYZ…` 合约与 `"4999997900"` 取自文档），其余为手工构造的假数据；USDT 主网合约 `TR7NHq…Lj6t` 在官方文档 <https://developers.tron.network/docs/get-trc20-transaction-history> 中出现（见"币种映射核对"）。

### 内置映射表中 Solana、Tron 合约的核对（M2-02、M2-03，2026-11-12，未修改映射表）

| 资产 | 链 | 映射表中的地址 | 官方来源核对 |
|---|---|---|---|
| USDT | Tron | `TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t` | 一致。TRON 官方开发者文档 <https://developers.tron.network/docs/get-trc20-transaction-history> 写明"USDT (`TR7NHq…Lj6t`)" |
| USDC | Solana | `EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v` | 一致。Helius 文档多处示例标注为 USDC mint（第三方文档，非 Circle 官方） |
| USDT | Solana | `Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB` | 一致。Helius 文档代码示例注释为 USDT（第三方文档，非 Tether 官方） |
| PYUSD | Solana | `2b1kV6DkPAnxd5ixfnxCpjxmKwqjjaYmCZfHsFu24GXo` | **未能核对**：可读的文档中未出现 |
| EURC | Solana | `HzwqbKZw8HxMN6bF2yFZNrht3c2iXXzpKcFu7uBEDKtr` | **未能核对**：同上 |

另：映射表 `asset_mappings.json` 没有 decimals 字段，`TronChainAdapter.knownDecimals` 需要装配层另行提供（Solana 的 decimals 由 RPC 返回，不需要）。
