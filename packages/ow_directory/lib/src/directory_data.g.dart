// 由 tool/embed.dart 从 data/directory.json 生成，不要手工修改。
// 修改数据后运行：cd packages/ow_directory && dart run tool/embed.dart

/// 内嵌的第三方目录 JSON 原文。
const String directoryJson = r'''
{
  "schemaVersion": 1,
  "entries": [
    {
      "id": "binance",
      "kind": "exchange",
      "name": "Binance",
      "aliases": [
        "币安"
      ],
      "officialDomains": [
        "binance.com"
      ],
      "links": {
        "website": "https://www.binance.com",
        "apiDocs": "https://developers.binance.com/docs/binance-spot-api-docs",
        "apiKeyGuide": "https://www.binance.com/en/support/faq/how-to-create-api-keys-on-binance-360002502072",
        "status": "https://status.binance.com/"
      },
      "integration": "integrated",
      "exchange": {
        "domainExchangeId": "binance"
      },
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://www.binance.com/en/support/faq/how-to-create-api-keys-on-binance-360002502072",
        "https://developers.binance.com/docs/wallet/others/system-status",
        "https://www.binance.com/en/binance-api"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。apiDocs 经 curl 可达（跳转到 developers.binance.com/en/docs/products/spot/）。apiKeyManagement 与 helpCenter 的深链未能确认，待补充。"
    },
    {
      "id": "okx",
      "kind": "exchange",
      "name": "OKX",
      "aliases": [
        "欧易"
      ],
      "officialDomains": [
        "okx.com"
      ],
      "links": {
        "website": "https://www.okx.com",
        "apiDocs": "https://www.okx.com/docs-v5/en/",
        "apiKeyGuide": "https://www.okx.com/help/api-faq",
        "apiKeyManagement": "https://www.okx.com/account/my-api",
        "helpCenter": "https://www.okx.com/help",
        "status": "https://www.okx.com/status"
      },
      "integration": "integrated",
      "exchange": {
        "domainExchangeId": "okx"
      },
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://www.okx.com/docs-v5/en/",
        "https://www.okx.com/en-us/help/api-faq"
      ],
      "notes": "website、apiDocs、apiKeyManagement、helpCenter、status、apiKeyGuide 均经 curl 返回 200（apiKeyManagement 会跳转到登录页）。"
    },
    {
      "id": "bybit",
      "kind": "exchange",
      "name": "Bybit",
      "aliases": [],
      "officialDomains": [
        "bybit.com",
        "bybit-exchange.github.io"
      ],
      "links": {
        "website": "https://www.bybit.com",
        "apiDocs": "https://bybit-exchange.github.io/docs/v5/intro",
        "apiKeyGuide": "https://www.bybit.com/en/help-center/article/How-to-create-your-API-key",
        "apiKeyManagement": "https://www.bybit.com/app/user/api-management"
      },
      "integration": "integrated",
      "exchange": {
        "domainExchangeId": "bybit"
      },
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://www.bybit.com/en/help-center/article/How-to-create-your-API-key",
        "https://bybit-exchange.github.io/docs/v5/intro"
      ],
      "notes": "apiDocs 经 curl 返回 200；其余仅依据搜索结果摘要（帮助文章正文给出 api-management 地址）。bybit-exchange.github.io 是 Bybit 官方文档站。未找到专门的状态页，helpCenter 根路径未确认。"
    },
    {
      "id": "bitget",
      "kind": "exchange",
      "name": "Bitget",
      "aliases": [],
      "officialDomains": [
        "bitget.com"
      ],
      "links": {
        "website": "https://www.bitget.com",
        "apiDocs": "https://www.bitget.com/docs/uta/Introduction",
        "apiKeyGuide": "https://www.bitget.com/docs/uta/quick-start",
        "apiKeyManagement": "https://www.bitget.com/account/newapi",
        "helpCenter": "https://www.bitget.com/support"
      },
      "integration": "integrated",
      "exchange": {
        "domainExchangeId": "bitget"
      },
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://www.bitget.com/docs/uta/quick-start",
        "https://www.bitget.com/support/sections/12508313405050"
      ],
      "notes": "以上链接经 curl 返回 200（apiKeyManagement 为登录后页面）。未找到专门的状态页，待补充。"
    },
    {
      "id": "alchemy",
      "kind": "dataProvider",
      "name": "Alchemy",
      "aliases": [],
      "officialDomains": [
        "alchemy.com"
      ],
      "links": {
        "website": "https://www.alchemy.com",
        "apiDocs": "https://www.alchemy.com/docs",
        "apiKeyGuide": "https://www.alchemy.com/docs/alchemy-quickstart-guide",
        "signup": "https://dashboard.alchemy.com",
        "pricing": "https://www.alchemy.com/pricing"
      },
      "integration": "integrated",
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://www.alchemy.com/docs/alchemy-quickstart-guide",
        "https://www.alchemy.com/pricing"
      ],
      "notes": "website、apiDocs、apiKeyGuide、pricing 经 curl 返回 200；signup 指向 dashboard.alchemy.com 首页（搜索结果指出注册入口在此），未能直接打开。"
    },
    {
      "id": "coingecko",
      "kind": "dataProvider",
      "name": "CoinGecko",
      "aliases": [
        "币价",
        "CoinGecko API"
      ],
      "officialDomains": [
        "coingecko.com"
      ],
      "links": {
        "website": "https://www.coingecko.com",
        "apiDocs": "https://docs.coingecko.com/reference/introduction",
        "apiKeyGuide": "https://docs.coingecko.com/docs/setting-up-your-api-key",
        "pricing": "https://www.coingecko.com/en/api/pricing"
      },
      "integration": "integrated",
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://docs.coingecko.com/docs/setting-up-your-api-key",
        "https://www.coingecko.com/en/api/pricing"
      ],
      "notes": "docs.coingecko.com 两条经 curl 返回 200；www.coingecko.com 在本环境不可达，website 与 pricing 依据搜索结果。"
    },
    {
      "id": "mempool-space",
      "kind": "dataProvider",
      "name": "mempool.space",
      "aliases": [],
      "officialDomains": [
        "mempool.space"
      ],
      "links": {
        "website": "https://mempool.space",
        "apiDocs": "https://mempool.space/docs/api/rest"
      },
      "integration": "integrated",
      "explorer": {
        "chainId": "bitcoin",
        "addressUrlTemplate": "https://mempool.space/address/{address}"
      },
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://mempool.space/docs/api/rest"
      ],
      "notes": "经 curl 返回 200。同时是比特币的区块浏览器。"
    },
    {
      "id": "blockstream",
      "kind": "dataProvider",
      "name": "Blockstream（Esplora）",
      "aliases": [
        "Blockstream Esplora"
      ],
      "officialDomains": [
        "blockstream.info",
        "blockstream.com"
      ],
      "links": {
        "website": "https://blockstream.info"
      },
      "integration": "integrated",
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://github.com/Blockstream/esplora"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。Esplora 的 API 说明在 GitHub（github.com/Blockstream/esplora 的 API.md），因 github.com 不能作为官方域名，未收 apiDocs，待补充。blockstream.info 为 Esplora README 中给出的公共实例。"
    },
    {
      "id": "solana-rpc",
      "kind": "dataProvider",
      "name": "Solana RPC（官方文档）",
      "aliases": [
        "Solana 官方 RPC"
      ],
      "officialDomains": [
        "solana.com"
      ],
      "links": {
        "website": "https://solana.com",
        "apiDocs": "https://solana.com/docs/rpc/http"
      },
      "integration": "integrated",
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://solana.com/docs/rpc/http"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。solana.com 在本环境返回 429（限流），链接来自搜索结果。"
    },
    {
      "id": "trongrid",
      "kind": "dataProvider",
      "name": "TronGrid",
      "aliases": [],
      "officialDomains": [
        "tron.network",
        "trongrid.io"
      ],
      "links": {
        "website": "https://developers.tron.network/docs/trongrid",
        "apiDocs": "https://developers.tron.network/reference/select-network"
      },
      "integration": "integrated",
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://developers.tron.network/docs/trongrid",
        "https://developers.tron.network/reference/select-network"
      ],
      "notes": "两条链接经 curl 返回 200。API Key 说明页（搜索结果给出的地址已失效）与注册入口待补充。"
    },
    {
      "id": "helius",
      "kind": "dataProvider",
      "name": "Helius",
      "aliases": [],
      "officialDomains": [
        "helius.dev"
      ],
      "links": {
        "website": "https://www.helius.dev",
        "apiDocs": "https://www.helius.dev/docs",
        "apiKeyGuide": "https://www.helius.dev/docs/api-reference/authentication",
        "signup": "https://dashboard.helius.dev",
        "pricing": "https://www.helius.dev/pricing"
      },
      "integration": "integrated",
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://www.helius.dev/docs/api-reference/authentication",
        "https://www.helius.dev/pricing"
      ],
      "notes": "website、apiDocs、apiKeyGuide、pricing 经 curl 返回 200；signup 为 dashboard.helius.dev 首页（搜索结果指出在此注册），curl 不可达。"
    },
    {
      "id": "etherscan",
      "kind": "explorer",
      "name": "Etherscan",
      "aliases": [],
      "officialDomains": [
        "etherscan.io"
      ],
      "links": {
        "website": "https://etherscan.io"
      },
      "integration": "integrated",
      "explorer": {
        "chainId": "ethereum",
        "addressUrlTemplate": "https://etherscan.io/address/{address}"
      },
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://docs.etherscan.io/contract-verification/supported-chains"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。模板与 ow_domain 的 explorerAddressUrl 一致。"
    },
    {
      "id": "bscscan",
      "kind": "explorer",
      "name": "BscScan",
      "aliases": [],
      "officialDomains": [
        "bscscan.com"
      ],
      "links": {
        "website": "https://bscscan.com"
      },
      "integration": "integrated",
      "explorer": {
        "chainId": "bsc",
        "addressUrlTemplate": "https://bscscan.com/address/{address}"
      },
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://docs.etherscan.io/contract-verification/supported-chains"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。模板与 ow_domain 的 explorerAddressUrl 一致。"
    },
    {
      "id": "arbiscan",
      "kind": "explorer",
      "name": "Arbiscan",
      "aliases": [],
      "officialDomains": [
        "arbiscan.io"
      ],
      "links": {
        "website": "https://arbiscan.io"
      },
      "integration": "integrated",
      "explorer": {
        "chainId": "arbitrum",
        "addressUrlTemplate": "https://arbiscan.io/address/{address}"
      },
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://docs.etherscan.io/contract-verification/supported-chains"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。模板与 ow_domain 的 explorerAddressUrl 一致。"
    },
    {
      "id": "optimistic-etherscan",
      "kind": "explorer",
      "name": "Optimistic Etherscan",
      "aliases": [],
      "officialDomains": [
        "etherscan.io"
      ],
      "links": {
        "website": "https://optimistic.etherscan.io"
      },
      "integration": "integrated",
      "explorer": {
        "chainId": "optimism",
        "addressUrlTemplate": "https://optimistic.etherscan.io/address/{address}"
      },
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://docs.etherscan.io/contract-verification/supported-chains"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。模板与 ow_domain 的 explorerAddressUrl 一致。"
    },
    {
      "id": "basescan",
      "kind": "explorer",
      "name": "BaseScan",
      "aliases": [],
      "officialDomains": [
        "basescan.org"
      ],
      "links": {
        "website": "https://basescan.org"
      },
      "integration": "integrated",
      "explorer": {
        "chainId": "base",
        "addressUrlTemplate": "https://basescan.org/address/{address}"
      },
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://docs.etherscan.io/contract-verification/supported-chains"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。模板与 ow_domain 的 explorerAddressUrl 一致。"
    },
    {
      "id": "polygonscan",
      "kind": "explorer",
      "name": "PolygonScan",
      "aliases": [],
      "officialDomains": [
        "polygonscan.com"
      ],
      "links": {
        "website": "https://polygonscan.com"
      },
      "integration": "integrated",
      "explorer": {
        "chainId": "polygon",
        "addressUrlTemplate": "https://polygonscan.com/address/{address}"
      },
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://docs.etherscan.io/contract-verification/supported-chains"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。模板与 ow_domain 的 explorerAddressUrl 一致。"
    },
    {
      "id": "solscan",
      "kind": "explorer",
      "name": "Solscan",
      "aliases": [],
      "officialDomains": [
        "solscan.io"
      ],
      "links": {
        "website": "https://solscan.io",
        "apiDocs": "https://docs.solscan.io/",
        "helpCenter": "https://info.solscan.io/"
      },
      "integration": "integrated",
      "explorer": {
        "chainId": "solana",
        "addressUrlTemplate": "https://solscan.io/account/{address}"
      },
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://docs.solscan.io/",
        "https://kb.solscan.io/exploring-account-page"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。模板与 ow_domain 的 explorerAddressUrl 一致。helpCenter 指向知识库 info.solscan.io 首页，由搜索结果推断，待核对。"
    },
    {
      "id": "tronscan",
      "kind": "explorer",
      "name": "Tronscan",
      "aliases": [],
      "officialDomains": [
        "tronscan.org"
      ],
      "links": {
        "website": "https://tronscan.org",
        "helpCenter": "https://support.tronscan.org/hc/en-us"
      },
      "integration": "integrated",
      "explorer": {
        "chainId": "tron",
        "addressUrlTemplate": "https://tronscan.org/#/address/{address}"
      },
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://developers.tron.network/docs/data-and-analysis-blockchain-browser",
        "https://support.tronscan.org/hc/en-us/articles/360041878551-How-to-View-TRON-Addresses-on-TRONSCAN"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。模板与 ow_domain 一致（#/address 形式）；但搜索结果里 Tronscan 的地址页形如 tronscan.org/address/{address}（无 #/），旧形式是否仍可用待核对。"
    },
    {
      "id": "uniswap-wallet",
      "kind": "wallet",
      "name": "Uniswap Wallet",
      "aliases": [
        "Uniswap 钱包"
      ],
      "officialDomains": [
        "uniswap.org"
      ],
      "links": {
        "website": "https://uniswap.org",
        "helpCenter": "https://support.uniswap.org/hc/en-us",
        "exportKeyGuide": "https://support.uniswap.org/hc/en-us/articles/11386716842253-How-to-back-up-your-recovery-phrase-manually"
      },
      "integration": "integrated",
      "wallet": {
        "custody": "selfCustody",
        "exportable": true,
        "families": [
          "evm"
        ]
      },
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://support.uniswap.org/hc/en-us/articles/11386716842253-How-to-back-up-your-recovery-phrase-manually"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。website 为域名根地址，未单独确认；支持的链族仅填 evm，其余待核对。"
    },
    {
      "id": "metamask",
      "kind": "wallet",
      "name": "MetaMask",
      "aliases": [
        "小狐狸"
      ],
      "officialDomains": [
        "metamask.io"
      ],
      "links": {
        "website": "https://metamask.io",
        "helpCenter": "https://support.metamask.io",
        "exportKeyGuide": "https://support.metamask.io/configure/wallet/how-to-reveal-your-secret-recovery-phrase/"
      },
      "integration": "integrated",
      "wallet": {
        "custody": "selfCustody",
        "exportable": true,
        "families": [
          "evm"
        ]
      },
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://support.metamask.io/configure/wallet/how-to-reveal-your-secret-recovery-phrase/"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。website 为域名根地址；支持的链族仅填 evm，其余待核对。"
    },
    {
      "id": "okx-web3-wallet",
      "kind": "wallet",
      "name": "OKX Web3 Wallet",
      "aliases": [
        "OKX 钱包",
        "欧易钱包"
      ],
      "officialDomains": [
        "okx.com"
      ],
      "links": {
        "website": "https://web3.okx.com",
        "exportKeyGuide": "https://web3.okx.com/help/how-do-i-manage-my-wallet-app"
      },
      "integration": "integrated",
      "wallet": {
        "custody": "selfCustody",
        "exportable": true,
        "families": [
          "evm",
          "bitcoin",
          "solana",
          "tron"
        ]
      },
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://web3.okx.com/help/how-do-i-manage-my-wallet-app",
        "https://web3.okx.com/help/what-is-a-private-key-seed-phrase"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。OKX 帮助页指出无密钥（keyless）钱包无法备份助记词，此类钱包对本应用的备份清单应按无助记词处理。website 为 web3.okx.com 根地址。"
    },
    {
      "id": "bitget-wallet",
      "kind": "wallet",
      "name": "Bitget Wallet",
      "aliases": [
        "币记",
        "BitKeep"
      ],
      "officialDomains": [
        "bitget.com"
      ],
      "links": {
        "website": "https://web3.bitget.com",
        "exportKeyGuide": "https://web3.bitget.com/helpCenter/360"
      },
      "integration": "integrated",
      "wallet": {
        "custody": "selfCustody",
        "exportable": true,
        "families": [
          "evm",
          "bitcoin",
          "solana",
          "tron"
        ]
      },
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://web3.bitget.com/helpCenter/360",
        "https://web3.bitget.com/en/academy/how-to-use-an-mpc-wallet-or-a-mnemonic-wallet"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。同时提供助记词钱包和无助记词的 MPC 钱包，后者没有可导出的助记词；custody 按助记词钱包填写。别名 BitKeep 为其旧名，未单独核对。"
    },
    {
      "id": "trust-wallet",
      "kind": "wallet",
      "name": "Trust Wallet",
      "aliases": [
        "信任钱包"
      ],
      "officialDomains": [
        "trustwallet.com"
      ],
      "links": {
        "website": "https://trustwallet.com",
        "exportKeyGuide": "https://trustwallet.com/blog/product/how-to-backup-your-recovery-phrase-and-export-private-keys-in-trust-wallet"
      },
      "integration": "integrated",
      "wallet": {
        "custody": "selfCustody",
        "exportable": true,
        "families": [
          "evm",
          "bitcoin",
          "solana",
          "tron"
        ]
      },
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://trustwallet.com/blog/product/how-to-backup-your-recovery-phrase-and-export-private-keys-in-trust-wallet"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。exportKeyGuide 是官方博客文章而非帮助中心文章；导出私钥需先在开发者设置中开启。website 为域名根地址。"
    },
    {
      "id": "coinbase",
      "kind": "exchange",
      "name": "Coinbase",
      "aliases": [],
      "officialDomains": [
        "coinbase.com"
      ],
      "links": {
        "website": "https://www.coinbase.com",
        "helpCenter": "https://help.coinbase.com"
      },
      "integration": "none",
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://www.coinbase.com/",
        "https://help.coinbase.com/en/coinbase/trading-and-funding/cb-advanced/fee-upgrade-incentive"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。helpCenter 为 help.coinbase.com 根地址。"
    },
    {
      "id": "kraken",
      "kind": "exchange",
      "name": "Kraken",
      "aliases": [],
      "officialDomains": [
        "kraken.com"
      ],
      "links": {
        "website": "https://www.kraken.com"
      },
      "integration": "none",
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://www.kraken.com/"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。"
    },
    {
      "id": "kucoin",
      "kind": "exchange",
      "name": "KuCoin",
      "aliases": [
        "库币"
      ],
      "officialDomains": [
        "kucoin.com"
      ],
      "links": {
        "website": "https://www.kucoin.com"
      },
      "integration": "none",
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://www.kucoin.com/"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。"
    },
    {
      "id": "gate",
      "kind": "exchange",
      "name": "Gate",
      "aliases": [
        "Gate.io",
        "芝麻开门"
      ],
      "officialDomains": [
        "gate.com",
        "gate.io"
      ],
      "links": {
        "website": "https://www.gate.com"
      },
      "integration": "none",
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://www.gate.com/"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。gate.io 为旧域名，未确认是否仍属官方，仅 gate.com 有来源。"
    },
    {
      "id": "htx",
      "kind": "exchange",
      "name": "HTX",
      "aliases": [
        "火币",
        "Huobi"
      ],
      "officialDomains": [
        "htx.com"
      ],
      "links": {
        "website": "https://www.htx.com"
      },
      "integration": "none",
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://www.htx.com/"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。"
    },
    {
      "id": "mexc",
      "kind": "exchange",
      "name": "MEXC",
      "aliases": [
        "抹茶"
      ],
      "officialDomains": [
        "mexc.com"
      ],
      "links": {
        "website": "https://www.mexc.com"
      },
      "integration": "none",
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://www.mexc.com/"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。"
    },
    {
      "id": "bitfinex",
      "kind": "exchange",
      "name": "Bitfinex",
      "aliases": [],
      "officialDomains": [
        "bitfinex.com"
      ],
      "links": {
        "website": "https://www.bitfinex.com",
        "helpCenter": "https://support.bitfinex.com/hc/en-us"
      },
      "integration": "none",
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://www.bitfinex.com/",
        "https://support.bitfinex.com/hc/en-us"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。"
    },
    {
      "id": "bitstamp",
      "kind": "exchange",
      "name": "Bitstamp",
      "aliases": [],
      "officialDomains": [
        "bitstamp.net"
      ],
      "links": {
        "website": "https://www.bitstamp.net"
      },
      "integration": "none",
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://www.bitstamp.net/"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。"
    },
    {
      "id": "bingx",
      "kind": "exchange",
      "name": "BingX",
      "aliases": [],
      "officialDomains": [
        "bingx.com"
      ],
      "links": {
        "website": "https://bingx.com/en"
      },
      "integration": "none",
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://bingx.com/en"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。"
    },
    {
      "id": "lbank",
      "kind": "exchange",
      "name": "LBank",
      "aliases": [],
      "officialDomains": [
        "lbank.com"
      ],
      "links": {
        "website": "https://www.lbank.com",
        "helpCenter": "https://www.lbank.com/support"
      },
      "integration": "none",
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://www.lbank.com/",
        "https://www.lbank.com/support"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。"
    },
    {
      "id": "bitmart",
      "kind": "exchange",
      "name": "BitMart",
      "aliases": [],
      "officialDomains": [
        "bitmart.com"
      ],
      "links": {
        "website": "https://www.bitmart.com"
      },
      "integration": "none",
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://www.bitmart.com/"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。"
    },
    {
      "id": "deribit",
      "kind": "exchange",
      "name": "Deribit",
      "aliases": [],
      "officialDomains": [
        "deribit.com"
      ],
      "links": {
        "website": "https://www.deribit.com",
        "helpCenter": "https://support.deribit.com/hc/en-us"
      },
      "integration": "none",
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://support.deribit.com/hc/en-us"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。Deribit 帮助中心声明官方站点只有 deribit.com、asia.deribit.com、test.deribit.com。website 为域名根地址。"
    },
    {
      "id": "hyperliquid",
      "kind": "exchange",
      "name": "Hyperliquid",
      "aliases": [],
      "officialDomains": [
        "hyperliquid.xyz"
      ],
      "links": {
        "website": "https://hyperliquid.xyz"
      },
      "integration": "none",
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://hyperliquid.xyz/"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。去中心化永续合约交易所，没有传统意义的 API Key。"
    },
    {
      "id": "crypto-com",
      "kind": "exchange",
      "name": "Crypto.com",
      "aliases": [],
      "officialDomains": [
        "crypto.com"
      ],
      "links": {},
      "integration": "none",
      "verifiedAt": null,
      "sources": [],
      "notes": "待核对：候选域名来自记忆，本次检索未返回其官网"
    },
    {
      "id": "gemini",
      "kind": "exchange",
      "name": "Gemini",
      "aliases": [],
      "officialDomains": [
        "gemini.com"
      ],
      "links": {},
      "integration": "none",
      "verifiedAt": null,
      "sources": [],
      "notes": "待核对：候选域名来自记忆，本次检索未返回其官网"
    },
    {
      "id": "upbit",
      "kind": "exchange",
      "name": "Upbit",
      "aliases": [],
      "officialDomains": [
        "upbit.com"
      ],
      "links": {},
      "integration": "none",
      "verifiedAt": null,
      "sources": [],
      "notes": "待核对：候选域名来自记忆，本次检索未返回其官网"
    },
    {
      "id": "bithumb",
      "kind": "exchange",
      "name": "Bithumb",
      "aliases": [],
      "officialDomains": [
        "bithumb.com"
      ],
      "links": {},
      "integration": "none",
      "verifiedAt": null,
      "sources": [],
      "notes": "待核对：候选域名来自记忆，本次检索未返回其官网"
    },
    {
      "id": "phantom",
      "kind": "wallet",
      "name": "Phantom",
      "aliases": [],
      "officialDomains": [
        "phantom.com",
        "phantom.app"
      ],
      "links": {
        "helpCenter": "https://help.phantom.com/hc/en-us"
      },
      "integration": "none",
      "wallet": {
        "custody": "selfCustody",
        "exportable": null,
        "families": [
          "evm",
          "bitcoin",
          "solana"
        ]
      },
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://help.phantom.com/hc/en-us"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。仅确认了帮助中心 help.phantom.com，主站地址待补充；链族与可导出性待核对。"
    },
    {
      "id": "rabby",
      "kind": "wallet",
      "name": "Rabby Wallet",
      "aliases": [
        "Rabby"
      ],
      "officialDomains": [
        "rabby.io"
      ],
      "links": {},
      "integration": "none",
      "wallet": {
        "custody": "selfCustody",
        "exportable": null,
        "families": [
          "evm"
        ]
      },
      "verifiedAt": null,
      "sources": [],
      "notes": "待核对：仅在 rabbykit.rabby.io 的结果中见到该域名，官网未确认"
    },
    {
      "id": "rainbow",
      "kind": "wallet",
      "name": "Rainbow",
      "aliases": [],
      "officialDomains": [
        "rainbow.me"
      ],
      "links": {},
      "integration": "none",
      "wallet": {
        "custody": "selfCustody",
        "exportable": null,
        "families": [
          "evm"
        ]
      },
      "verifiedAt": null,
      "sources": [],
      "notes": "待核对：候选域名来自记忆，本次检索未返回其官网"
    },
    {
      "id": "coinbase-wallet",
      "kind": "wallet",
      "name": "Coinbase Wallet（Base app）",
      "aliases": [
        "Base app"
      ],
      "officialDomains": [
        "coinbase.com",
        "wallet.coinbase.com"
      ],
      "links": {},
      "integration": "none",
      "wallet": {
        "custody": "selfCustody",
        "exportable": null,
        "families": [
          "evm"
        ]
      },
      "verifiedAt": null,
      "sources": [],
      "notes": "待核对：官网与产品名称（Coinbase Wallet 已更名为 Base app）均未确认"
    },
    {
      "id": "imtoken",
      "kind": "wallet",
      "name": "imToken",
      "aliases": [
        "IMToken"
      ],
      "officialDomains": [
        "token.im"
      ],
      "links": {
        "website": "https://token.im"
      },
      "integration": "none",
      "wallet": {
        "custody": "selfCustody",
        "exportable": null,
        "families": [
          "evm",
          "bitcoin",
          "tron"
        ]
      },
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://token.im/?locale=en-us"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。imToken 官方文章建议收藏 token.im；链族与可导出性待核对。"
    },
    {
      "id": "tokenpocket",
      "kind": "wallet",
      "name": "TokenPocket",
      "aliases": [
        "TP 钱包"
      ],
      "officialDomains": [
        "tokenpocket.pro",
        "tp.xyz",
        "tpwallet.io"
      ],
      "links": {
        "website": "https://www.tokenpocket.pro",
        "helpCenter": "https://help.tokenpocket.pro/en"
      },
      "integration": "none",
      "wallet": {
        "custody": "selfCustody",
        "exportable": null,
        "families": [
          "evm",
          "solana",
          "tron"
        ]
      },
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://help.tokenpocket.pro/en"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。其帮助页声明官方域名为 tp.xyz、tpwallet.io、tokenpocket.pro；链族与可导出性待核对。"
    },
    {
      "id": "safepal",
      "kind": "hardwareWallet",
      "name": "SafePal",
      "aliases": [],
      "officialDomains": [
        "safepal.com"
      ],
      "links": {},
      "integration": "none",
      "wallet": {
        "custody": "selfCustody",
        "exportable": null,
        "families": [
          "evm",
          "bitcoin",
          "solana",
          "tron"
        ]
      },
      "verifiedAt": null,
      "sources": [],
      "notes": "待核对：同时有硬件钱包与软件钱包，官网未确认"
    },
    {
      "id": "exodus",
      "kind": "wallet",
      "name": "Exodus",
      "aliases": [],
      "officialDomains": [
        "exodus.com"
      ],
      "links": {},
      "integration": "none",
      "wallet": {
        "custody": "selfCustody",
        "exportable": null,
        "families": [
          "evm",
          "bitcoin",
          "solana",
          "tron"
        ]
      },
      "verifiedAt": null,
      "sources": [],
      "notes": "待核对：候选域名来自记忆，本次检索未返回其官网"
    },
    {
      "id": "zerion",
      "kind": "wallet",
      "name": "Zerion",
      "aliases": [],
      "officialDomains": [
        "zerion.io"
      ],
      "links": {
        "website": "https://app.zerion.io",
        "helpCenter": "https://help.zerion.io/en/"
      },
      "integration": "none",
      "wallet": {
        "custody": "selfCustody",
        "exportable": null,
        "families": [
          "evm",
          "solana"
        ]
      },
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://help.zerion.io/en/collections/3056746-wallet-management",
        "https://help.zerion.io/en/articles/4290567-how-to-connect-your-wallet-to-zerion-web-app"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。website 为其 Web 应用 app.zerion.io；helpCenter 为 help.zerion.io 根路径；官网首页未确认。"
    },
    {
      "id": "backpack",
      "kind": "wallet",
      "name": "Backpack",
      "aliases": [],
      "officialDomains": [
        "backpack.app"
      ],
      "links": {},
      "integration": "none",
      "wallet": {
        "custody": "selfCustody",
        "exportable": null,
        "families": [
          "solana",
          "evm"
        ]
      },
      "verifiedAt": null,
      "sources": [],
      "notes": "待核对：仅在 Zerion 的帮助文章中见到该钱包名，官网未确认"
    },
    {
      "id": "solflare",
      "kind": "wallet",
      "name": "Solflare",
      "aliases": [],
      "officialDomains": [
        "solflare.com"
      ],
      "links": {
        "website": "https://www.solflare.com",
        "helpCenter": "https://docs.solflare.com/solflare"
      },
      "integration": "none",
      "wallet": {
        "custody": "selfCustody",
        "exportable": true,
        "families": [
          "solana"
        ]
      },
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://docs.solflare.com/solflare/overview/official-links-and-how-to-avoid-fakes"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。其文档声明唯一官方站点是 solflare.com 及其子域。"
    },
    {
      "id": "tronlink",
      "kind": "wallet",
      "name": "TronLink",
      "aliases": [
        "波场钱包"
      ],
      "officialDomains": [
        "tronlink.org"
      ],
      "links": {
        "website": "https://www.tronlink.org"
      },
      "integration": "none",
      "wallet": {
        "custody": "selfCustody",
        "exportable": null,
        "families": [
          "tron",
          "evm"
        ]
      },
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://www.tronlink.org/"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。其页面声明唯一官网是 tronlink.org。"
    },
    {
      "id": "keplr",
      "kind": "wallet",
      "name": "Keplr",
      "aliases": [],
      "officialDomains": [
        "keplr.app"
      ],
      "links": {
        "helpCenter": "https://help.keplr.app/"
      },
      "integration": "none",
      "wallet": {
        "custody": "selfCustody",
        "exportable": null,
        "families": []
      },
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://help.keplr.app/"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。Cosmos 生态钱包，本应用暂不支持其链族（families 为空）；仅确认了帮助中心，主站待补充。"
    },
    {
      "id": "argent",
      "kind": "wallet",
      "name": "Argent（Ready）",
      "aliases": [
        "Ready"
      ],
      "officialDomains": [
        "argent.xyz",
        "ready.co"
      ],
      "links": {},
      "integration": "none",
      "wallet": {
        "custody": "selfCustody",
        "exportable": null,
        "families": []
      },
      "verifiedAt": null,
      "sources": [],
      "notes": "待核对：Starknet 钱包，已更名 Ready，官网未确认"
    },
    {
      "id": "safe",
      "kind": "wallet",
      "name": "Safe",
      "aliases": [
        "Gnosis Safe"
      ],
      "officialDomains": [
        "safe.global"
      ],
      "links": {},
      "integration": "none",
      "wallet": {
        "custody": "selfCustody",
        "exportable": false,
        "families": [
          "evm"
        ]
      },
      "verifiedAt": null,
      "sources": [],
      "notes": "待核对：多签智能合约钱包，官网未确认（无助记词，exportable 是依据其产品类型的推断，需核对）"
    },
    {
      "id": "binance-web3-wallet",
      "kind": "wallet",
      "name": "Binance Web3 Wallet",
      "aliases": [
        "币安 Web3 钱包"
      ],
      "officialDomains": [
        "binance.com"
      ],
      "links": {},
      "integration": "none",
      "wallet": {
        "custody": "mpc",
        "exportable": null,
        "families": [
          "evm",
          "bitcoin",
          "solana",
          "tron"
        ]
      },
      "verifiedAt": null,
      "sources": [],
      "notes": "待核对：官网与托管方式（MPC）均未确认"
    },
    {
      "id": "bybit-wallet",
      "kind": "wallet",
      "name": "Bybit Wallet",
      "aliases": [],
      "officialDomains": [
        "bybit.com"
      ],
      "links": {},
      "integration": "none",
      "wallet": {
        "custody": "selfCustody",
        "exportable": null,
        "families": [
          "evm"
        ]
      },
      "verifiedAt": null,
      "sources": [],
      "notes": "待核对：官网与托管方式均未确认"
    },
    {
      "id": "electrum",
      "kind": "wallet",
      "name": "Electrum",
      "aliases": [],
      "officialDomains": [
        "electrum.org"
      ],
      "links": {},
      "integration": "none",
      "wallet": {
        "custody": "selfCustody",
        "exportable": true,
        "families": [
          "bitcoin"
        ]
      },
      "verifiedAt": null,
      "sources": [],
      "notes": "待核对：候选域名来自记忆，本次检索未返回其官网"
    },
    {
      "id": "sparrow",
      "kind": "wallet",
      "name": "Sparrow Wallet",
      "aliases": [
        "Sparrow"
      ],
      "officialDomains": [
        "sparrowwallet.com"
      ],
      "links": {
        "website": "https://sparrowwallet.com"
      },
      "integration": "none",
      "wallet": {
        "custody": "selfCustody",
        "exportable": true,
        "families": [
          "bitcoin"
        ]
      },
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://sparrowwallet.com/"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。比特币桌面钱包。"
    },
    {
      "id": "bluewallet",
      "kind": "wallet",
      "name": "BlueWallet",
      "aliases": [],
      "officialDomains": [
        "bluewallet.io"
      ],
      "links": {
        "website": "https://bluewallet.io"
      },
      "integration": "none",
      "wallet": {
        "custody": "selfCustody",
        "exportable": true,
        "families": [
          "bitcoin"
        ]
      },
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://bluewallet.io/features/"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。"
    },
    {
      "id": "unisat",
      "kind": "wallet",
      "name": "UniSat Wallet",
      "aliases": [
        "UniSat"
      ],
      "officialDomains": [
        "unisat.io"
      ],
      "links": {
        "website": "https://unisat.io"
      },
      "integration": "none",
      "wallet": {
        "custody": "selfCustody",
        "exportable": true,
        "families": [
          "bitcoin"
        ]
      },
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://unisat.io/",
        "https://docs.unisat.io/products/unisat-wallet"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。"
    },
    {
      "id": "xverse",
      "kind": "wallet",
      "name": "Xverse",
      "aliases": [],
      "officialDomains": [
        "xverse.app"
      ],
      "links": {
        "website": "https://www.xverse.app",
        "helpCenter": "https://support.xverse.app/hc/en-us",
        "download": "https://www.xverse.app/download"
      },
      "integration": "none",
      "wallet": {
        "custody": "selfCustody",
        "exportable": true,
        "families": [
          "bitcoin"
        ]
      },
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://support.xverse.app/hc/en-us/articles/16468845199501-How-to-Import-Your-Wallet-into-Xverse"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。download 地址由 Xverse 帮助文章给出；helpCenter 为 support.xverse.app 根路径。"
    },
    {
      "id": "leather",
      "kind": "wallet",
      "name": "Leather",
      "aliases": [],
      "officialDomains": [
        "leather.io"
      ],
      "links": {
        "website": "https://leather.io"
      },
      "integration": "none",
      "wallet": {
        "custody": "selfCustody",
        "exportable": true,
        "families": [
          "bitcoin"
        ]
      },
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://leather.io/wallet"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。"
    },
    {
      "id": "ledger",
      "kind": "hardwareWallet",
      "name": "Ledger",
      "aliases": [
        "Ledger Nano"
      ],
      "officialDomains": [
        "ledger.com"
      ],
      "links": {
        "website": "https://www.ledger.com"
      },
      "integration": "none",
      "wallet": {
        "custody": "selfCustody",
        "exportable": true,
        "families": [
          "evm",
          "bitcoin",
          "solana",
          "tron"
        ]
      },
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://www.ledger.com/"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。托管方式为硬件自持；exportable 指助记词备份，按其产品性质填写，待核对。"
    },
    {
      "id": "trezor",
      "kind": "hardwareWallet",
      "name": "Trezor",
      "aliases": [],
      "officialDomains": [
        "trezor.io"
      ],
      "links": {
        "website": "https://trezor.io"
      },
      "integration": "none",
      "wallet": {
        "custody": "selfCustody",
        "exportable": true,
        "families": [
          "evm",
          "bitcoin",
          "solana",
          "tron"
        ]
      },
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://trezor.io/"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。"
    },
    {
      "id": "onekey",
      "kind": "hardwareWallet",
      "name": "OneKey",
      "aliases": [],
      "officialDomains": [
        "onekey.so"
      ],
      "links": {
        "website": "https://onekey.so"
      },
      "integration": "none",
      "wallet": {
        "custody": "selfCustody",
        "exportable": true,
        "families": [
          "evm",
          "bitcoin",
          "solana",
          "tron"
        ]
      },
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://onekey.so/"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。"
    },
    {
      "id": "keystone",
      "kind": "hardwareWallet",
      "name": "Keystone",
      "aliases": [],
      "officialDomains": [
        "keyst.one"
      ],
      "links": {
        "website": "https://keyst.one"
      },
      "integration": "none",
      "wallet": {
        "custody": "selfCustody",
        "exportable": true,
        "families": [
          "evm",
          "bitcoin",
          "solana",
          "tron"
        ]
      },
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://keyst.one/firmware"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。仅在其固件页面（keyst.one/firmware）确认域名，website 为域名根地址。"
    },
    {
      "id": "tangem",
      "kind": "hardwareWallet",
      "name": "Tangem",
      "aliases": [],
      "officialDomains": [
        "tangem.com"
      ],
      "links": {
        "website": "https://tangem.com"
      },
      "integration": "none",
      "wallet": {
        "custody": "selfCustody",
        "exportable": false,
        "families": [
          "evm",
          "bitcoin",
          "solana",
          "tron"
        ]
      },
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://tangem.com/en/"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。无助记词的卡片式硬件钱包（其页面称 seedless），对本应用的备份清单应按无助记词处理；exportable 为依据其页面描述的推断。"
    },
    {
      "id": "coldcard",
      "kind": "hardwareWallet",
      "name": "Coldcard",
      "aliases": [],
      "officialDomains": [
        "coldcard.com"
      ],
      "links": {
        "website": "https://coldcard.com"
      },
      "integration": "none",
      "wallet": {
        "custody": "selfCustody",
        "exportable": true,
        "families": [
          "bitcoin"
        ]
      },
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://coldcard.com/"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。仅支持比特币。"
    },
    {
      "id": "bitbox",
      "kind": "hardwareWallet",
      "name": "BitBox",
      "aliases": [
        "BitBox02"
      ],
      "officialDomains": [
        "bitbox.swiss"
      ],
      "links": {
        "website": "https://bitbox.swiss",
        "download": "https://bitbox.swiss/download/"
      },
      "integration": "none",
      "wallet": {
        "custody": "selfCustody",
        "exportable": true,
        "families": [
          "evm",
          "bitcoin"
        ]
      },
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://bitbox.swiss/bitbox02/",
        "https://bitbox.swiss/download/"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。备份方式为 microSD 卡或 BIP-39 助记词；链族待核对。"
    },
    {
      "id": "gridplus",
      "kind": "hardwareWallet",
      "name": "GridPlus",
      "aliases": [
        "Lattice1"
      ],
      "officialDomains": [
        "gridplus.io"
      ],
      "links": {
        "website": "https://gridplus.io",
        "helpCenter": "https://docs.gridplus.io/"
      },
      "integration": "none",
      "wallet": {
        "custody": "selfCustody",
        "exportable": true,
        "families": [
          "evm",
          "bitcoin"
        ]
      },
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://gridplus.io/",
        "https://docs.gridplus.io/lattice1/"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。helpCenter 指向文档站 docs.gridplus.io 根地址。"
    },
    {
      "id": "infura",
      "kind": "dataProvider",
      "name": "Infura",
      "aliases": [],
      "officialDomains": [
        "infura.io"
      ],
      "links": {},
      "integration": "none",
      "verifiedAt": null,
      "sources": [],
      "notes": "待核对：候选域名来自记忆，本次检索未返回其官网"
    },
    {
      "id": "quicknode",
      "kind": "dataProvider",
      "name": "QuickNode",
      "aliases": [],
      "officialDomains": [
        "quicknode.com"
      ],
      "links": {
        "website": "https://www.quicknode.com"
      },
      "integration": "none",
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://www.quicknode.com/builders-guide/best/best-blockchain-node-providers-in-web3"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。website 为域名根地址。"
    },
    {
      "id": "ankr",
      "kind": "dataProvider",
      "name": "Ankr",
      "aliases": [],
      "officialDomains": [
        "ankr.com"
      ],
      "links": {
        "website": "https://www.ankr.com"
      },
      "integration": "none",
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://www.ankr.com/blog/blockchain-infrastructure-rpc-providers-compared-in-2026/"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。website 为域名根地址。"
    },
    {
      "id": "moralis",
      "kind": "dataProvider",
      "name": "Moralis",
      "aliases": [],
      "officialDomains": [
        "moralis.com"
      ],
      "links": {
        "website": "https://moralis.com"
      },
      "integration": "none",
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://moralis.com/infura-alternatives-and-blockchain-node-providers/"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。website 为域名根地址。"
    },
    {
      "id": "goldrush",
      "kind": "dataProvider",
      "name": "Covalent（GoldRush）",
      "aliases": [
        "GoldRush",
        "Covalent"
      ],
      "officialDomains": [
        "goldrush.dev",
        "covalenthq.com"
      ],
      "links": {
        "website": "https://goldrush.dev"
      },
      "integration": "none",
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://goldrush.dev/guides/comparing-covalent-s-transactions-api-to-rpc-providers/"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。covalenthq.com 为旧域名，未确认，仅 goldrush.dev 有来源。"
    },
    {
      "id": "debank",
      "kind": "dataProvider",
      "name": "DeBank",
      "aliases": [],
      "officialDomains": [
        "debank.com"
      ],
      "links": {},
      "integration": "none",
      "verifiedAt": null,
      "sources": [],
      "notes": "待核对：候选域名来自记忆，本次检索未返回其官网"
    },
    {
      "id": "coinmarketcap",
      "kind": "dataProvider",
      "name": "CoinMarketCap",
      "aliases": [
        "CMC"
      ],
      "officialDomains": [
        "coinmarketcap.com"
      ],
      "links": {
        "website": "https://coinmarketcap.com"
      },
      "integration": "none",
      "verifiedAt": "2026-11-11",
      "sources": [
        "https://coinmarketcap.com/academy/it/article/understanding-crypto-api-subscription-models-for-traders-in-2026"
      ],
      "notes": "仅依据搜索结果摘要，未能直接打开页面。域名由其官方 Academy 页面确认；website 为域名根地址。"
    }
  ]
}
''';
