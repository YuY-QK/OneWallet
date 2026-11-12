# 第三方目录补充指南

写给以后继续补充条目的人或 AI。数据格式与校验规则的权威说明在 `docs/IMPLEMENTATION_SPEC_v1.0.md` 第 9 节。

## 1. 目标

用户希望：凡是集成或提到的第三方（交易所、钱包、数据服务、区块浏览器），都能在 app 里直接点到官网和相关文档，不用自己去搜；并且尽可能多地列出第三方。

**准确性高于数量。** 钱包类应用里的链接是钓鱼的高发点：仿冒域名、搜索广告位里的假官网都很常见。一条错的链接比缺一条链接糟糕得多。

## 2. 文件

- 数据：`packages/ow_directory/data/directory.json`（唯一需要手工编辑的文件）
- 生成：`packages/ow_directory/lib/src/directory_data.g.dart`（由脚本生成，不要手改）

## 3. 字段说明

见 IMPLEMENTATION_SPEC 第 9.2 节。补充时常见的几点：

- `id` 一经发布不改。新增条目用小写英文和连字符，如 `trust-wallet`。
- `officialDomains` 是**白名单**：该条目所有链接的主机名必须等于其中之一或是其子域。只写能确认属于该项目的域名；不要写 `github.io`、`github.com` 这类共享托管域名（校验器会拒绝）。需要链接托管在 `xxx.github.io` 上的官方文档时，写完整主机名（如 `bybit-exchange.github.io`）。
- 钱包请尽量填 `wallet.custody` 与 `wallet.exportable`。MPC 或无助记词模式的钱包对本应用的"备份清单"很重要：`exportable` 为 `false` 或 `null`，并在 `notes` 里写明。不确定填 `null`，不要猜。
- `integration`：本应用已接入的填 `integrated`，计划接入的填 `planned`，其余 `none`。已接入的交易所还要填 `exchange.domainExchangeId`。

## 4. 核对规则

**可信来源**（域名必须从至少一个确认，并把依据写进 `sources`）：

- 项目官方文档或官方帮助中心（页面自己声明了官网域名的最好，例如"唯一官方网站是 …"）；
- 项目的官方 GitHub 组织；
- 知名聚合站（CoinGecko、CoinMarketCap）的官网字段；
- 维基百科。

**禁止**：

- 搜索结果里的广告位链接；
- 带推广或邀请参数的链接（`ref=`、`referral`、`utm_`、`invite`、`aff`）。邀请返佣链接一律不收；
- 域名拼写可疑的（多一个字母、换后缀、连字符变体）；
- 凭印象拼 URL。具体的文档深链（`apiKeyGuide`、`exportKeyGuide` 等）只有在你**确实打开过页面**，或搜索结果明确给出该地址且在官方域名下时才填；不确定就留空。

**如实标注**：

- 确认过的条目填 `verifiedAt`（核对当天的日期），并至少写一个 `sources`；
- 只知道名字、没能确认官网的，可以收录，但 `verifiedAt` 为 `null`，`links` 留空，`notes` 写"待核对"；
- 无法打开页面、只依据搜索结果摘要时，在 `notes` 里写明"仅依据搜索结果摘要"，不要假装亲自打开过；
- 页面会改版：深链失效时，宁可删掉也不要留着。

## 5. 步骤

1. 编辑 `packages/ow_directory/data/directory.json`。
2. 运行 `cd packages/ow_directory && dart run tool/embed.dart`，重新生成内嵌常量。
3. 运行 `cd packages/ow_directory && dart test`。校验器会报出所有违规，测试会检查 JSON 与内嵌常量是否一致。
4. 回到仓库根目录运行 `tools/check.sh`。
5. 提交信息格式：`feat(directory): <一句话>`；`directory.json` 与生成文件一起提交。

## 6. 可以直接发给 AI 的指令

> 请按 `docs/DIRECTORY_COLLECTION_GUIDE.md` 补充 `packages/ow_directory/data/directory.json`。先通读该指南和 IMPLEMENTATION_SPEC 第 9 节。从本指南第 7 节"待补充清单"里取条目：确认官网域名（必须来自官方文档、官方 GitHub 组织、CoinGecko/CoinMarketCap 的官网字段或维基百科，把依据写进 `sources`），再按需补充 `apiDocs`、`apiKeyGuide`、`exportKeyGuide`、`helpCenter`、`status` 等深链。只有确实打开或在搜索结果中见到该页面且属于官方域名时才填；不确定就留空。不要使用搜索广告、带邀请或推广参数的链接。无法确认的条目保持 `verifiedAt: null`、`links` 留空、`notes` 写"待核对"；只依据搜索摘要的在 `notes` 里写明。完成后运行 `cd packages/ow_directory && dart run tool/embed.dart` 和 `dart test`，再运行 `tools/check.sh`。完成后更新本指南的待补充清单。不要修改 ow_domain、其他包和 app。

## 7. 待补充清单

首批（2026-11-11）共 79 条，其中 62 条已核对、17 条待核对。核对时无法直接打开大部分站点，多数链接依据搜索结果；`notes` 中写有"仅依据搜索结果摘要"的条目，建议有条件时亲自打开一遍再确认。

### 7.1 待核对的条目（官网域名未确认，`links` 为空）

- 交易所：Crypto.com（`crypto-com`）、Gemini（`gemini`）、Upbit（`upbit`）、Bithumb（`bithumb`）
- 软件钱包：Rabby（`rabby`）、Rainbow（`rainbow`）、Coinbase Wallet / Base app（`coinbase-wallet`）、Backpack（`backpack`）、Exodus（`exodus`）、Argent / Ready（`argent`）、Safe（`safe`）、Electrum（`electrum`）、Binance Web3 Wallet（`binance-web3-wallet`）、Bybit Wallet（`bybit-wallet`）
- 硬件钱包：SafePal（`safepal`，同时有软件钱包，需决定是否拆成两条）
- 数据服务：Infura（`infura`）、DeBank（`debank`）

### 7.2 只有官网（缺深链）的已核对条目

交易所：Kraken、KuCoin、Gate、HTX、MEXC、Bitstamp、BingX、BitMart、Hyperliquid、Coinbase、Bitfinex、LBank、Deribit 缺 `apiDocs`、`apiKeyGuide`、`helpCenter`（部分已有）、`status`。
钱包与硬件钱包：imToken、TronLink、Sparrow、BlueWallet、UniSat、Leather、Ledger、Trezor、OneKey、Keystone、Tangem、Coldcard 缺 `exportKeyGuide`、`helpCenter`、`download`；Phantom、Keplr 缺 `website`（只确认了帮助中心）。
数据服务：Blockstream（缺 `apiDocs`，Esplora 文档在 GitHub，不能作为官方域名，需找 blockstream.info 或 blockstream.com 下的文档页）、QuickNode、Ankr、Moralis、GoldRush、CoinMarketCap 缺 `apiDocs`、`signup`、`pricing`。
区块浏览器：Etherscan 系列缺 `apiDocs`（Etherscan 的 API 文档在 docs.etherscan.io）、`helpCenter`。

### 7.3 已接入条目中缺失的链接类型

- Binance：`apiKeyManagement`（API 管理页）、`helpCenter`。
- Bybit：`status`、`helpCenter`（只确认了帮助文章，根路径未确认）。
- Bitget：`status`（只找到"系统更新"公告列表，未收）。
- TronGrid：`apiKeyGuide`（搜索结果给出的地址已失效，需重新找）、`signup`、`pricing`。
- Solana RPC：`pricing` 不适用；公共 RPC 的限额说明页可补。
- 钱包：Uniswap Wallet、MetaMask、Trust Wallet、OKX Web3 Wallet、Bitget Wallet 的 `download`；各钱包的 `families` 只填了已确认的部分（MetaMask、Uniswap 仅填 `evm`），需对照官方支持的网络补全。

### 7.4 尚未收录的第三方

- 交易所：Bitkub、Bitso、Coinone、WhiteBIT、Phemex、Poloniex、AscendEX、CoinEx、ProBit、Bitvavo、OKCoin、Binance US、Coinbase International 等。
- 钱包：Ronin、Sui Wallet、Petra、Pera、Yoroi、Ambire、Frame、Taho、Enkrypt、Coin98、Math Wallet、Guarda、Atomic Wallet、Cake Wallet、Wasabi、Samourai 等。
- 硬件钱包：Foundation Passport、Blockstream Jade、Ellipal、Arculus、NGRAVE、D'CENT、Secux 等。
- 数据服务与浏览器：Etherscan API、Blockchair、Blockcypher、DRPC、Chainstack、Blast API、GetBlock、Nodereal、Zerion API、CoinPaprika、CryptoCompare、Defillama、Dune 等；Solana Explorer、Blockstream Explorer、Ethplorer、Optimism / Base 官方浏览器等。
