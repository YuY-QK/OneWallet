# 内置币种映射表的出处（asset_mappings.json）

核对日期：2026-11-11。本文件记录 `asset_mappings.json` 中每个合约地址的出处。

## 核对方式与可信度（请先读）

本次核对时的工具环境无法直接打开发行方官网和区块浏览器页面（网页抓取对除包仓库外的站点一律不可达），
只有两类渠道可用：（1）包仓库 npm；（2）网页搜索（只返回摘要，不返回原页面）。因此：

1. **主要来源**：Uniswap Labs 维护的默认代币列表，npm 包 `@uniswap/default-token-list@22.34.0`
   （文件 `build/uniswap-default.tokenlist.json`，列表时间戳 2026-11-06T18:43:20Z；
   上游仓库 https://github.com/Uniswap/default-token-list ，对应 https://tokens.uniswap.org ）。
   这是经过审核的第三方代币列表，**不是发行方文档**；表中"来源"列写 `Uniswap` 的条目均属此类。
2. **交叉印证**（搜索摘要，非原页面直读），与上表一致的有：
   - USDT Ethereum `0xdac17f…1ec7`：Tether 公告 https://tether.io/news/usd%e2%82%ae-and-eur%e2%82%ae-now-supported-on-ethereum/ 。
   - USDT Tron `TR7NHq…Lj6t`：第三方稳定币指南摘要（未直读 Tether 官方页）。
   - USDT Polygon `0xc2132d…8e8f`、BNB Chain `0x55d398…7955`、Arbitrum `0xfd086b…cbb9`：CoinGecko 代币页与 Backpack 文档摘要。
   - USDT Solana `Es9vMF…wNYB`：Eco 指南摘要（Solscan 持有人数据）。
   - USDC Ethereum / Base / Arbitrum / Optimism / Polygon：与 Circle 官方页 https://developers.circle.com/stablecoins/usdc-contract-addresses 的地址表一致是我的记忆，**搜索未能返回该表原文**，未直读核对。
   - LINK Ethereum `0x514910…86ca`：https://docs.chain.link/resources/link-token-contracts 搜索摘要；LINK Arbitrum `0xf97f4d…9fb4` 仅前后缀被摘要印证。
   - OP Optimism `0x4200…0042`：CoinGecko Optimism 页摘要。
3. 未列入交叉印证的条目只有 Uniswap 列表一个来源。**发布前应由人工逐条对照发行方文档或区块浏览器认证页复核**（见文末"待人工复核"）。

## priceId 核对（2026-11-12）

`/coins/list` 在 `api.coingecko.com`，本环境不可达（代理拒绝连接），公开的币种列表（含官方 Google Sheet）同样不可达，
因此**无法逐个验证**。能对照 `docs.coingecko.com` 全文（llms-full.txt）及页面示例确认的只有：

- 文档示例中作为 coin id 出现：`bitcoin`、`ethereum`、`solana`、`weth`（contract 页示例响应 `id: weth`）、`uniswap`、`1inch`（示例 `id: "1inch"`）、`tether`（示例 `target_coin_id`）。
- 文档中提到 `usd-coin`、`tron`、`arbitrum`、`optimism` 的位置是 GeckoTerminal 网络 id 或无关文字，不能证明它们是 coin id。
- **未能确认**（文档不含）：`polygon-ecosystem-token`、`havven`、`compound-governance-token`、`matic-network`（本表未使用，POL 现用 `polygon-ecosystem-token`）以及其余全部 id。

这几个容易过时的 id 的现状只能凭既有知识判断（POL 迁移后 CoinGecko 使用 `polygon-ecosystem-token`；Synthetix 的 id 为 `havven`；
Compound 为 `compound-governance-token`），**不是核对结论**。上线前必须运行 `packages/ow_pricing/tool/smoke_price.dart --catalog` 用真实接口验证。

## 其他约定

- EVM 合约地址统一小写；Solana、Tron 原样（Base58 区分大小写）。
- `priceId`（CoinGecko coin id）核对结论见下一节"priceId 核对"；
  `tools/smoke/price.dart --catalog` 会用真实接口逐个验证所有 priceId 是否有价格，上线前请运行一次。
- 原生币：ETH（ethereum、arbitrum、optimism、base）、BNB（bsc）、POL（polygon）、BTC（bitcoin）、SOL（solana）、TRX（tron），不涉及合约地址。
- 桥接/包装类资产（如 BSC 上的 Binance-Peg 代币、Polygon PoS 桥接代币、Arbitrum 的 USDT0）按 1:1 锚定的同一标准币种收录，估值使用主币种价格。

## 合约条目

### USDT（Tether USD，priceId `tether`）

| 链 | 合约地址 | 来源 |
|---|---|---|
| ethereum | `0xdac17f958d2ee523a2206206994597c13d831ec7` | Uniswap 默认代币列表 |
| bsc | `0x55d398326f99059ff775485246999027b3197955` | Uniswap 默认代币列表 |
| optimism | `0x94b008aa00579c1307b0ef2c499ad98a8ce58e58` | Uniswap 默认代币列表 |
| base | `0xfde4c96c8593536e31f229ea8f37b2ada2699bb2` | Uniswap 默认代币列表 |
| polygon | `0xc2132d05d31c914a87c6611c10748aeb04b58e8f` | Uniswap 默认代币列表 |
| solana | `Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB` | Uniswap 默认代币列表 |
| arbitrum | `0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9` | Uniswap 默认代币列表（符号 USDT0） |
| tron | `TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t` | Tether 官方公告/第三方指南（搜索摘要核对） |

### USDC（USD Coin，priceId `usd-coin`）

| 链 | 合约地址 | 来源 |
|---|---|---|
| ethereum | `0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48` | Uniswap 默认代币列表 |
| bsc | `0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d` | Uniswap 默认代币列表 |
| arbitrum | `0xaf88d065e77c8cc2239327c5edb3a432268e5831` | Uniswap 默认代币列表 |
| optimism | `0x0b2c639c533813f4aa9d7837caf62653d097ff85` | Uniswap 默认代币列表 |
| base | `0x833589fcd6edb6e08f4c7c32d4f71b54bda02913` | Uniswap 默认代币列表 |
| polygon | `0x3c499c542cef5e3811e1192ce70d8cc03d5c3359` | Uniswap 默认代币列表 |
| solana | `EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v` | Uniswap 默认代币列表 |

### DAI（Dai，priceId `dai`）

| 链 | 合约地址 | 来源 |
|---|---|---|
| ethereum | `0x6b175474e89094c44da98b954eedeac495271d0f` | Uniswap 默认代币列表 |
| bsc | `0x1af3f329e8be154074d8769d1ffa4ee058b1dbc3` | Uniswap 默认代币列表 |
| arbitrum | `0xda10009cbd5d07dd0cecc66161fc93d7c9000da1` | Uniswap 默认代币列表 |
| optimism | `0xda10009cbd5d07dd0cecc66161fc93d7c9000da1` | Uniswap 默认代币列表 |
| base | `0x50c5725949a6f0c72e6c4a641f24049a917db0cb` | Uniswap 默认代币列表 |
| polygon | `0x8f3cf7ad23cd3cadbd9735aff958023239c6a063` | Uniswap 默认代币列表 |

### WETH（Wrapped Ether，priceId `weth`）

| 链 | 合约地址 | 来源 |
|---|---|---|
| ethereum | `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` | Uniswap 默认代币列表 |
| bsc | `0x2170ed0880ac9a755fd29b2688956bd959f933f8` | Uniswap 默认代币列表 |
| arbitrum | `0x82af49447d8a07e3bd95bd0d56f35241523fbab1` | Uniswap 默认代币列表 |
| optimism | `0x4200000000000000000000000000000000000006` | Uniswap 默认代币列表 |
| base | `0x4200000000000000000000000000000000000006` | Uniswap 默认代币列表 |
| polygon | `0x7ceb23fd6bc0add59e62ac25578270cff1b9f619` | Uniswap 默认代币列表 |

### WBTC（Wrapped Bitcoin，priceId `wrapped-bitcoin`）

| 链 | 合约地址 | 来源 |
|---|---|---|
| ethereum | `0x2260fac5e5542a773aa44fbcfedf7c193bc2c599` | Uniswap 默认代币列表 |
| arbitrum | `0x2f2a2543b76a4166549f7aab2e75bef0aefc5b0f` | Uniswap 默认代币列表 |
| optimism | `0x68f180fcce6836688e9084f035309e29bf0a2095` | Uniswap 默认代币列表 |
| polygon | `0x1bfd67037b42cf73acf2047067bd4f2c47d9bfd6` | Uniswap 默认代币列表 |

### LINK（Chainlink，priceId `chainlink`）

| 链 | 合约地址 | 来源 |
|---|---|---|
| ethereum | `0x514910771af9ca656af840dff83e8264ecf986ca` | Uniswap 默认代币列表 |
| bsc | `0xf8a0bf9cf54bb92f17374d9e9a321e6a111a51bd` | Uniswap 默认代币列表 |
| arbitrum | `0xf97f4df75117a78c1a5a0dbb814af92458539fb4` | Uniswap 默认代币列表 |
| optimism | `0x350a791bfc2c21f9ed5d10980dad2e2638ffa7f6` | Uniswap 默认代币列表 |
| polygon | `0x53e0bca35ec356bd5dddfebbd1fc0fd03fabad39` | Uniswap 默认代币列表 |

### UNI（Uniswap，priceId `uniswap`）

| 链 | 合约地址 | 来源 |
|---|---|---|
| ethereum | `0x1f9840a85d5af5bf1d1762f925bdaddc4201f984` | Uniswap 默认代币列表 |
| bsc | `0xbf5140a22578168fd562dccf235e5d43a02ce9b1` | Uniswap 默认代币列表 |
| arbitrum | `0xfa7f8980b0f1e64a2062791cc3b0871572f1f7f0` | Uniswap 默认代币列表 |
| optimism | `0x6fd9d7ad17242c41f7131d257212c54a0e816691` | Uniswap 默认代币列表 |
| base | `0xc3de830ea07524a0761646a6a4e4be0e114a3c83` | Uniswap 默认代币列表 |
| polygon | `0xb33eaad8d922b1083446dc23f610c2567fb5180f` | Uniswap 默认代币列表 |

### AAVE（Aave，priceId `aave`）

| 链 | 合约地址 | 来源 |
|---|---|---|
| ethereum | `0x7fc66500c84a76ad7e9c93437bfc5ac33e2ddae9` | Uniswap 默认代币列表 |
| bsc | `0xfb6115445bff7b52feb98650c87f44907e58f802` | Uniswap 默认代币列表 |
| arbitrum | `0xba5ddd1f9d7f570dc94a51479a000e3bce967196` | Uniswap 默认代币列表 |
| optimism | `0x76fb31fb4af56892a25e32cfc43de717950c9278` | Uniswap 默认代币列表 |
| base | `0x63706e401c06ac8513145b7687a14804d17f814b` | Uniswap 默认代币列表 |
| polygon | `0xd6df932a45c0f255f85145f286ea0b292b21c90b` | Uniswap 默认代币列表 |

### ARB（Arbitrum，priceId `arbitrum`）

| 链 | 合约地址 | 来源 |
|---|---|---|
| ethereum | `0xb50721bcf8d664c30412cfbc6cf7a15145234ad1` | Uniswap 默认代币列表 |
| arbitrum | `0x912ce59144191c1204e64559fe8253a0e49e6548` | Uniswap 默认代币列表 |

### OP（Optimism，priceId `optimism`）

| 链 | 合约地址 | 来源 |
|---|---|---|
| optimism | `0x4200000000000000000000000000000000000042` | Uniswap 默认代币列表 |

### CBBTC（Coinbase Wrapped BTC，priceId `coinbase-wrapped-btc`）

| 链 | 合约地址 | 来源 |
|---|---|---|
| ethereum | `0xcbb7c0000ab88b473b1f5afd9ef808440eed33bf` | Uniswap 默认代币列表 |
| arbitrum | `0xcbb7c0000ab88b473b1f5afd9ef808440eed33bf` | Uniswap 默认代币列表 |
| base | `0xcbb7c0000ab88b473b1f5afd9ef808440eed33bf` | Uniswap 默认代币列表 |

### PYUSD（PayPal USD，priceId `paypal-usd`）

| 链 | 合约地址 | 来源 |
|---|---|---|
| ethereum | `0x6c3ea9036406852006290770bedfcaba0e23a0e8` | Uniswap 默认代币列表 |
| arbitrum | `0x327006c8712fe0abdbbd55b7999db39b0967342e` | Uniswap 默认代币列表 |
| solana | `2b1kV6DkPAnxd5ixfnxCpjxmKwqjjaYmCZfHsFu24GXo` | Uniswap 默认代币列表 |

### SHIB（Shiba Inu，priceId `shiba-inu`）

| 链 | 合约地址 | 来源 |
|---|---|---|
| ethereum | `0x95ad61b0a150d79219dcf64e1e6cc01f0b64c4ce` | Uniswap 默认代币列表 |
| arbitrum | `0x5033833c9fe8b9d3e09eed2f73d2aaf7e3872fd1` | Uniswap 默认代币列表 |
| polygon | `0x6f8a06447ff6fcf75d803135a7de15ce88c1d4ec` | Uniswap 默认代币列表 |

### PEPE（Pepe，priceId `pepe`）

| 链 | 合约地址 | 来源 |
|---|---|---|
| ethereum | `0x6982508145454ce325ddbe47a25d4ec3d2311933` | Uniswap 默认代币列表 |
| arbitrum | `0x35e6a59f786d9266c7961ea28c7b768b33959cbb` | Uniswap 默认代币列表 |
| optimism | `0xc1c167cc44f7923cd0062c4370df962f9ddb16f5` | Uniswap 默认代币列表 |
| base | `0xb4fde59a779991bfb6a52253b51947828b982be3` | Uniswap 默认代币列表 |

### MKR（Maker，priceId `maker`）

| 链 | 合约地址 | 来源 |
|---|---|---|
| ethereum | `0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2` | Uniswap 默认代币列表 |
| arbitrum | `0x2e9a6df78e42a30712c10a9dc4b1c8656f8f2879` | Uniswap 默认代币列表 |
| optimism | `0xab7badef82e9fe11f6f33f87bc9bc2aa27f2fcb5` | Uniswap 默认代币列表 |
| polygon | `0x6f7c932e7684666c9fd1d44527765433e01ff61d` | Uniswap 默认代币列表 |

### CRV（Curve DAO Token，priceId `curve-dao-token`）

| 链 | 合约地址 | 来源 |
|---|---|---|
| ethereum | `0xd533a949740bb3306d119cc777fa900ba034cd52` | Uniswap 默认代币列表 |
| arbitrum | `0x11cdb42b0eb46d95f990bedd4695a6e3fa034978` | Uniswap 默认代币列表 |
| optimism | `0x0994206dfe8de6ec6920ff4d779b0d950605fb53` | Uniswap 默认代币列表 |
| base | `0x8ee73c484a26e0a5df2ee2a4960b789967dd0415` | Uniswap 默认代币列表 |
| polygon | `0x172370d5cd63279efa6d502dab29171933a610af` | Uniswap 默认代币列表 |

### LDO（Lido DAO，priceId `lido-dao`）

| 链 | 合约地址 | 来源 |
|---|---|---|
| ethereum | `0x5a98fcbea516cf06857215779fd812ca3bef1b32` | Uniswap 默认代币列表 |
| arbitrum | `0x13ad51ed4f1b7e9dc168d8a00cb3f4ddd85efa60` | Uniswap 默认代币列表 |
| optimism | `0xfdb794692724153d1488ccdbe0c56c252596735f` | Uniswap 默认代币列表 |
| polygon | `0xc3c7d422809852031b44ab29eec9f1eff2a58756` | Uniswap 默认代币列表 |

### COMP（Compound，priceId `compound-governance-token`）

| 链 | 合约地址 | 来源 |
|---|---|---|
| ethereum | `0xc00e94cb662c3520282e6f5717214004a7f26888` | Uniswap 默认代币列表 |
| bsc | `0x52ce071bd9b1c4b00a0b92d298c512478cad67e8` | Uniswap 默认代币列表 |
| arbitrum | `0x354a6da3fcde098f8389cad84b0182725c6c91de` | Uniswap 默认代币列表 |
| base | `0x9e1028f5f1d5ede59748ffcee5532509976840e0` | Uniswap 默认代币列表 |
| polygon | `0x8505b9d2254a7ae468c0e9dd10ccea3a837aef5c` | Uniswap 默认代币列表 |

### CBETH（Coinbase Wrapped Staked ETH，priceId `coinbase-wrapped-staked-eth`）

| 链 | 合约地址 | 来源 |
|---|---|---|
| ethereum | `0xbe9895146f7af43049ca1c1ae358b0541ea49704` | Uniswap 默认代币列表 |
| arbitrum | `0x1debd73e752beaf79865fd6446b0c970eae7732f` | Uniswap 默认代币列表 |
| optimism | `0xaddb6a0412de1ba0f936dcaeb8aaa24578dcf3b2` | Uniswap 默认代币列表 |
| base | `0x2ae3f1ec7f1f5012cfeab0185bfc7aa3cf0dec22` | Uniswap 默认代币列表 |

### WBNB（Wrapped BNB，priceId `wrapped-bnb`）

| 链 | 合约地址 | 来源 |
|---|---|---|
| bsc | `0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c` | Uniswap 默认代币列表 |

### GRT（The Graph，priceId `the-graph`）

| 链 | 合约地址 | 来源 |
|---|---|---|
| ethereum | `0xc944e90c64b2c07662a292be6244bdf05cda44a7` | Uniswap 默认代币列表 |
| arbitrum | `0x9623063377ad1b27544c965ccd7342f7ea7e88c7` | Uniswap 默认代币列表 |
| base | `0x0f4d237b09cb37d207ba60353dc254d4530d4df1` | Uniswap 默认代币列表 |
| polygon | `0x5fe2b58c013d7601147dcdd68c143a77499f5531` | Uniswap 默认代币列表 |

### ENS（Ethereum Name Service，priceId `ethereum-name-service`）

| 链 | 合约地址 | 来源 |
|---|---|---|
| ethereum | `0xc18360217d8f7ab5e7c516566761ea12ce7f9d72` | Uniswap 默认代币列表 |
| arbitrum | `0xfea31d704deb0975da8e77bf13e04239e70d7c28` | Uniswap 默认代币列表 |
| optimism | `0x65559aa14915a70190438ef90104769e5e890a00` | Uniswap 默认代币列表 |
| polygon | `0xbd7a5cf51d22930b8b3df6d834f9bcef90ee7c4f` | Uniswap 默认代币列表 |

### SNX（Synthetix Network Token，priceId `havven`）

| 链 | 合约地址 | 来源 |
|---|---|---|
| ethereum | `0xc011a73ee8576fb46f5e1c5751ca3b9fe0af2a6f` | Uniswap 默认代币列表 |
| arbitrum | `0xcba56cd8216fcbbf3fa6df6137f3147cbca37d60` | Uniswap 默认代币列表 |
| optimism | `0x8700daec35af8ff88c16bdf0418774cb3d7599b4` | Uniswap 默认代币列表 |
| base | `0x22e6966b799c4d5b13be962e1d117b56327fda66` | Uniswap 默认代币列表 |
| polygon | `0x50b728d8d964fd00c2d0aad81718b71311fef68a` | Uniswap 默认代币列表 |

### BAL（Balancer，priceId `balancer`）

| 链 | 合约地址 | 来源 |
|---|---|---|
| ethereum | `0xba100000625a3754423978a60c9317c58a424e3d` | Uniswap 默认代币列表 |
| arbitrum | `0x040d1edc9569d4bab2d15287dc5a4f10f56a56b8` | Uniswap 默认代币列表 |
| optimism | `0xfe8b128ba8c78aabc59d4c64cee7ff28e9379921` | Uniswap 默认代币列表 |
| base | `0x4158734d47fc9692176b5085e0f52ee0da5d47f1` | Uniswap 默认代币列表 |
| polygon | `0x9a71012b13ca4d3d0cdc72a177df3ef03b0e76a3` | Uniswap 默认代币列表 |

### 1INCH（1inch，priceId `1inch`）

| 链 | 合约地址 | 来源 |
|---|---|---|
| ethereum | `0x111111111117dc0aa78b770fa6a738034120c302` | Uniswap 默认代币列表 |
| bsc | `0x111111111117dc0aa78b770fa6a738034120c302` | Uniswap 默认代币列表 |
| arbitrum | `0x6314c31a7a1652ce482cffe247e9cb7c3f4bb9af` | Uniswap 默认代币列表 |
| optimism | `0xad42d013ac31486b73b6b059e748172994736426` | Uniswap 默认代币列表 |
| base | `0xc5fecc3a29fb57b5024eec8a2239d4621e111cbe` | Uniswap 默认代币列表 |
| polygon | `0x9c2c5fd7b07e95ee044ddeba0e97a665f142394f` | Uniswap 默认代币列表 |

### SUSHI（Sushi，priceId `sushi`）

| 链 | 合约地址 | 来源 |
|---|---|---|
| ethereum | `0x6b3595068778dd592e39a122f4f5a5cf09c90fe2` | Uniswap 默认代币列表 |
| bsc | `0x947950bcc74888a40ffa2593c5798f11fc9124c4` | Uniswap 默认代币列表 |
| arbitrum | `0xd4d42f0b6def4ce0383636770ef773390d85c61a` | Uniswap 默认代币列表 |
| optimism | `0x3eaeb77b03dbc0f6321ae1b72b2e9adb0f60112b` | Uniswap 默认代币列表 |
| base | `0x7d49a065d17d6d4a55dc13649901fdbb98b2afba` | Uniswap 默认代币列表 |
| polygon | `0x0b3f868e0be5597d5db7feb59e1cadbb0fdda50a` | Uniswap 默认代币列表 |

### USDS（USDS，priceId `usds`）

| 链 | 合约地址 | 来源 |
|---|---|---|
| ethereum | `0xdc035d45d973e3ec169d2276ddab16f1e407384f` | Uniswap 默认代币列表 |
| arbitrum | `0x6491c05a82219b8d1479057361ff1654749b876b` | Uniswap 默认代币列表 |

### LUSD（Liquity USD，priceId `liquity-usd`）

| 链 | 合约地址 | 来源 |
|---|---|---|
| ethereum | `0x5f98805a4e8be255a32880fdec7f6728c6568ba0` | Uniswap 默认代币列表 |
| arbitrum | `0x93b346b6bc2548da6a1e7d98e9a421b42541425b` | Uniswap 默认代币列表 |
| optimism | `0xc40f949f8a4e094d1b49a23ea9241d289b7b2819` | Uniswap 默认代币列表 |
| base | `0x368181499736d0c0cc614dbb145e2ec1ac86b8c6` | Uniswap 默认代币列表 |
| polygon | `0x23001f892c0c82b79303edc9b9033cd190bb21c7` | Uniswap 默认代币列表 |

### EURC（Euro Coin，priceId `euro-coin`）

| 链 | 合约地址 | 来源 |
|---|---|---|
| ethereum | `0x1abaea1f7c830bd89acc67ec4af516284b1bc33c` | Uniswap 默认代币列表 |
| arbitrum | `0x863708032b5c328e11abcbc0df9d79c71fc52a48` | Uniswap 默认代币列表 |
| base | `0x60a3e35cc302bfa44cb288bc5a4f316fdb1adb42` | Uniswap 默认代币列表 |
| polygon | `0x8a037dbca8134ffc72c362e394e35e0cad618f85` | Uniswap 默认代币列表 |
| solana | `HzwqbKZw8HxMN6bF2yFZNrht3c2iXXzpKcFu7uBEDKtr` | Uniswap 默认代币列表 |

### RPL（Rocket Pool，priceId `rocket-pool`）

| 链 | 合约地址 | 来源 |
|---|---|---|
| ethereum | `0xd33526068d116ce69f19a9ee46f0bd304f21a51f` | Uniswap 默认代币列表 |
| arbitrum | `0xb766039cc6db368759c1e56b79affe831d0cc507` | Uniswap 默认代币列表 |
| optimism | `0xc81d1f0eb955b0c020e5d5b264e1ff72c14d1401` | Uniswap 默认代币列表 |
| base | `0x1f73eaf55d696bffa9b0ea16fa987b93b0f4d302` | Uniswap 默认代币列表 |

### APE（ApeCoin，priceId `apecoin`）

| 链 | 合约地址 | 来源 |
|---|---|---|
| ethereum | `0x4d224452801aced8b2f0aebe155379bb5d594381` | Uniswap 默认代币列表 |
| arbitrum | `0x74885b4d524d497261259b38900f54e6dbad2210` | Uniswap 默认代币列表 |
| polygon | `0xb7b31a6bc18e48888545ce79e83e06003be70930` | Uniswap 默认代币列表 |

### SAND（The Sandbox，priceId `the-sandbox`）

| 链 | 合约地址 | 来源 |
|---|---|---|
| ethereum | `0x3845badade8e6dff049820680d1f14bd3903a5d0` | Uniswap 默认代币列表 |
| arbitrum | `0xd1318eb19dbf2647743c720ed35174efd64e3dac` | Uniswap 默认代币列表 |
| polygon | `0xbbba073c31bf03b8acf7c28ef0738decf3695683` | Uniswap 默认代币列表 |

### MANA（Decentraland，priceId `decentraland`）

| 链 | 合约地址 | 来源 |
|---|---|---|
| ethereum | `0x0f5d2fb29fb7d3cfee444a200298f468908cc942` | Uniswap 默认代币列表 |
| arbitrum | `0x442d24578a564ef628a65e6a7e3e7be2a165e231` | Uniswap 默认代币列表 |
| polygon | `0xa1c57f48f0deb89f569dfbe6e2b7f46d33606fd4` | Uniswap 默认代币列表 |

### AXS（Axie Infinity，priceId `axie-infinity`）

| 链 | 合约地址 | 来源 |
|---|---|---|
| ethereum | `0xbb0e17ef65f82ab018d8edd776e8dd940327b28b` | Uniswap 默认代币列表 |
| bsc | `0x715d400f88c167884bbcc41c5fea407ed4d2f8a0` | Uniswap 默认代币列表 |
| arbitrum | `0xe88998fb579266628af6a03e3821d5983e5d0089` | Uniswap 默认代币列表 |
| polygon | `0x61bdd9c7d4df4bf47a4508c0c8245505f2af5b7b` | Uniswap 默认代币列表 |

### IMX（Immutable，priceId `immutable-x`）

| 链 | 合约地址 | 来源 |
|---|---|---|
| ethereum | `0xf57e7e7c23978c3caec3c3548e3d615c346e79ff` | Uniswap 默认代币列表 |
| arbitrum | `0x3cfd99593a7f035f717142095a3898e3fca7783e` | Uniswap 默认代币列表 |
| polygon | `0x183070c90b34a63292cc908ce1b263cb56d49a7f` | Uniswap 默认代币列表 |

### BAT（Basic Attention Token，priceId `basic-attention-token`）

| 链 | 合约地址 | 来源 |
|---|---|---|
| ethereum | `0x0d8775f648430679a709e98d2b0cb6250d2887ef` | Uniswap 默认代币列表 |
| arbitrum | `0x3450687ef141dcd6110b77c2dc44b008616aee75` | Uniswap 默认代币列表 |
| polygon | `0x3cef98bb43d732e2f285ee605a8158cde967d219` | Uniswap 默认代币列表 |

### ZRX（0x Protocol，priceId `0x`）

| 链 | 合约地址 | 来源 |
|---|---|---|
| ethereum | `0xe41d2489571d322189246dafa5ebde1f4699f498` | Uniswap 默认代币列表 |
| arbitrum | `0xbd591bd4ddb64b77b5f76eab8f03d02519235ae2` | Uniswap 默认代币列表 |
| optimism | `0xd1917629b3e6a72e6772aab5dbe58eb7fa3c2f33` | Uniswap 默认代币列表 |
| base | `0x3bb4445d30ac020a84c1b5a8a2c6248ebc9779d0` | Uniswap 默认代币列表 |
| polygon | `0x5559edb74751a0ede9dea4dc23aee72cca6be3d5` | Uniswap 默认代币列表 |

## 未收录及原因

- stETH、wstETH（Lido）：不在 Uniswap 列表中（stETH 为 rebase 代币），Lido 官方文档无法直读，不收录。
- USDC.e / USDbC 等桥接版 USDC（Arbitrum、Optimism、Polygon、Base）：CoinGecko 上是独立币种，且可能脱锚，不并入 USDC。
- Circle 在 Tron 上的 USDC：搜索显示 Circle 已于 2024 年停止支持，不收录。
- Solana 上的 LINK、WETH、WBTC：均为 Wormhole 包装版，不并入对应币种。
- JUP、BONK、JitoSOL 等 Solana 生态代币，以及 Tron 上除 USDT 外的 TRC-20：没有可用的可信来源，不收录。
- Base 上的 WBTC、BSC 上的 WBTC/BTCB、Tron 上的 USDC/USDD 等：列表中没有，不收录。
- FRAX、FET、RENDER、MATIC（旧）：CoinGecko 标识近期有合并或改名，无法核对 priceId，不收录。

## 待人工复核

发布前请至少复核：USDT、USDC、DAI、WETH、WBTC 全部条目（对照 Tether、Circle、Sky、各链区块浏览器认证页），
以及所有只有单一来源且金额可能较大的条目；复核后在本文件对应行改写"来源"为官方 URL。
