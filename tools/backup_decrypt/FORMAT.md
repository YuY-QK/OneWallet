# OneWallet 加密备份文件格式（`.owbak`）

> 容器版本 1 · 载荷版本 1 · 2026-11-14
>
> 本文是 `.owbak` 格式**面向公众的权威说明**。它的目的是：即使 OneWallet 应用不复存在，任何人都能只凭本文和备份密码，用任意编程语言写出解密程序，取回其中的助记词与私钥。
> 本文与项目内部文档（`docs/SECURITY_DESIGN_v1.0.md` 5.2 节）有出入时，以本文为准。参考实现：解密工具 `owbak_decrypt.py`（同目录，Python + PyNaCl）；应用内的实现 `packages/ow_vault/lib/src/backup/`。

## 1. 概览

```
文件 = 魔数 "OWBK" ‖ 容器版本 ‖ 头部长度 L ‖ 头部 JSON ‖ 密文
K    = Argon2id(备份密码, salt, 参数)                       —— 32 字节
载荷 = XChaCha20-Poly1305-IETF 解密(K, nonce, 密文, AAD)      —— UTF-8 JSON
AAD  = 文件的前 9 + L 个字节（魔数、版本、长度、头部 JSON，原样）
```

- 文件自成一体：解密只需要备份密码，不需要任何设备、硬件密钥或账号。
- 载荷**不压缩**。
- 所用算法都是 libsodium 的标准接口，主流语言都有现成的库（Python：PyNaCl；JavaScript：libsodium-wrappers-sumo；Go：`golang.org/x/crypto/argon2` 与 `chacha20poly1305`；Rust：`argon2` 与 `chacha20poly1305` crate 等）。
- 文中的"字节"均为 8 位；多字节整数为**大端**。

## 2. 容器结构

| 偏移 | 长度 | 内容 |
|---|---|---|
| 0 | 4 | 魔数，ASCII `OWBK`，即 `4f 57 42 4b` |
| 4 | 1 | 容器版本，无符号整数。当前为 `01` |
| 5 | 4 | 头部 JSON 的字节数 L，32 位大端无符号整数 |
| 9 | L | 头部 JSON，UTF-8 编码（第 3 节） |
| 9 + L | 文件其余全部字节 | 密文：XChaCha20-Poly1305-IETF 的输出，即与载荷等长的密文后接 16 字节认证标签 |

读取时必须依次检查，任一不满足即视为"不是备份文件或已损坏"，**不得**继续派生密钥：

1. 文件至少 9 字节，前 4 字节为 `OWBK`；
2. 容器版本不为 0。**大于本程序支持的版本（当前 1）时报告"版本过新"**，不做其余检查——新版本的结构可能不同；
3. 2 ≤ L ≤ 4096，且文件长度 ≥ 9 + L + 17（密文至少包含 16 字节标签与 1 字节内容）；
4. 头部 JSON 合法且字段符合第 3 节。

密文一直延续到文件末尾，没有额外的长度字段或结束标记。因此截断文件或在末尾追加任何字节都会使认证失败。

## 3. 头部 JSON

一个 JSON 对象（RFC 8259，UTF-8，不允许重复的键）。应用写出的是紧凑形式、键顺序如下，但读取方不应依赖键顺序或空白——认证覆盖的是原始字节（第 4 节），不需要重新序列化。

```json
{"kdf":{"alg":"argon2id","salt":"<Base64>","mem_kib":262144,"iters":3,"parallelism":1},
 "nonce":"<Base64>","created_at":"2026-11-13T08:30:00.000Z","app_version":"1.0.0+1"}
```

| 字段 | 类型 | 含义与取值 |
|---|---|---|
| `kdf.alg` | 字符串 | 固定 `"argon2id"`（Argon2id 版本 1.3，即 libsodium 的 `crypto_pwhash_ALG_ARGON2ID13`） |
| `kdf.salt` | 字符串 | 16 字节 salt 的标准 Base64（RFC 4648 第 4 节，带 `=` 填充）。解码后必须恰好 16 字节，且重新编码与原文一致 |
| `kdf.mem_kib` | 整数 | 内存用量，单位 KiB（1024 字节）。允许 8 – 1048576（8 KiB – 1 GiB）。应用默认 262144（256 MiB） |
| `kdf.iters` | 整数 | 迭代次数（libsodium 的 `opslimit`，即 Argon2 的 t）。允许 1 – 32。应用默认 3 |
| `kdf.parallelism` | 整数 | 并行度（Argon2 的 lanes / p）。只能为 1 |
| `nonce` | 字符串 | 24 字节 nonce 的标准 Base64（规则同 salt） |
| `created_at` | 字符串 | 文件创建时间，见第 6 节的时间格式。只供显示 |
| `app_version` | 字符串 | 写入此文件的应用版本。只供显示 |

- 头部在认证之前就要使用，所以 KDF 参数**必须**先按上表的范围检查，超出即视为损坏，防止被改成耗尽内存或时间的值。
- 头部中未知的字段忽略。
- 头部明文可见：不含任何敏感信息。

## 4. 密钥派生与解密

**密钥**

```
K = Argon2id(
      password = 备份密码的 UTF-8 字节（原样，不做 Unicode 规范化，不去除首尾空白）,
      salt     = kdf.salt 解码后的 16 字节,
      t        = kdf.iters,
      m        = kdf.mem_kib（KiB）,
      p        = 1,
      版本     = 0x13,
      输出长度 = 32 字节)
```

libsodium 的写法：`crypto_pwhash(K, 32, password, password_len, salt, opslimit = kdf.iters, memlimit = kdf.mem_kib × 1024, crypto_pwhash_ALG_ARGON2ID13)`。PyNaCl：`nacl.pwhash.argon2id.kdf(32, password, salt, opslimit=iters, memlimit=mem_kib*1024)`。用其他 Argon2 库时注意：内存参数单位多为 KiB，并行度为 1，不使用 secret（key）与 associated data（X）参数，输出为原始 32 字节（不是编码后的 `$argon2id$…` 字符串）。

备份密码不能为空。用户输入的字符若可能有不同的 Unicode 形式（如带重音的字母），参考实现在原样解不开时还会依次尝试 NFC、NFD 两种规范化形式。

**解密**

```
载荷 = crypto_aead_xchacha20poly1305_ietf_decrypt(
         c     = 文件偏移 9 + L 起到文件末尾的全部字节,
         ad    = 文件偏移 0 到 9 + L（不含）的全部字节,
         npub  = nonce 解码后的 24 字节,
         k     = K)
```

- 算法为 XChaCha20-Poly1305（IETF 变体，draft-irtf-cfrg-xchacha）：HChaCha20 由 nonce 前 16 字节导出子密钥，再以 `00 00 00 00 ‖ nonce 后 8 字节` 作为 ChaCha20-Poly1305-IETF（RFC 8439）的 12 字节 nonce。密文最后 16 字节是 Poly1305 标签。
- **AAD 是文件里的原始字节**，长度 9 + L：魔数、版本字节、4 字节长度、头部 JSON，一字不改。不要把解析后的头部重新序列化再计算。因此头部的任何改动（参数、salt、nonce、时间、版本号、长度字段）都会使认证失败。
- 认证失败时**不得输出任何内容**。认证加密无法区分"密码错误"与"文件被改动、截断、追加"，应提示"密码不正确或文件已损坏"。

## 5. 载荷 JSON

解密得到的是一个 UTF-8 编码的 JSON 对象（RFC 8259，不允许重复的键）。应用写出的是紧凑、键顺序固定的形式；读取方不应依赖键顺序、空白或转义写法（例如非 ASCII 字符写成 `\u` 转义同样合法）。

**通用规则**

- 字段名为下划线小写。"必需"字段缺失或类型不对视为损坏；"可空"字段可以是 `null` 或缺失，两者含义相同。
- 未知的字段一律忽略（向前兼容）。
- 枚举写成下表中的字符串。读取方遇到**不认识的枚举值**时，应跳过该条目（账户、地址、保险库条目）并告知用户跳过了几项，而不是放弃整份备份；设置项不认识时取默认值。
- 时间格式见第 6 节；id 是不透明的字符串（应用使用 UUID）。

### 5.1 顶层

| 字段 | 类型 | 说明 |
|---|---|---|
| `format` | 字符串，必需 | 固定 `"onewallet-backup"` |
| `payload_version` | 整数，必需 | 当前 1。大于程序支持的版本时报告"版本过新"；小于 1 视为损坏 |
| `exported_at` | 时间，必需 | 导出时间 |
| `accounts` | 数组，必需 | 账户（5.2） |
| `addresses` | 数组，必需 | 观察地址（5.3） |
| `vault_items` | 数组，必需 | 保险库中的密钥条目，含明文（5.4） |
| `settings` | 对象，必需 | 设置（5.5） |
| `exchange_credentials` | 数组，可空 | 交易所只读 API 凭据（5.6）。默认导出不包含，此时没有这个字段 |

备份**不包含**余额、价格、净值快照、同步记录，也不包含 PIN、生物识别开关、上次导出时间等与设备绑定的状态。

### 5.2 `accounts[]`

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | 字符串，必需 | |
| `type` | 枚举，必需 | `wallet`（钱包）、`exchange`（交易所） |
| `name` | 字符串，必需 | 显示名 |
| `color_index` | 整数，必需 | 头像颜色序号，0–7 |
| `note` | 字符串，必需 | 备注，可为空字符串 |
| `wallet_source` | 枚举，可空 | 仅钱包：`uniswap`、`metamask`、`okxWeb3`、`bitgetWallet`、`trustWallet`、`other` |
| `exchange` | 枚举，可空 | 仅交易所：`binance`、`okx`、`bybit`、`bitget` |
| `vault_item_id` | 字符串，可空 | 仅钱包：关联的保险库条目 id（关联关系以此为准） |
| `backup` | 对象，必需 | 用户标记的备份状态：`offline_backed_up`（布尔，必需，"有纸质或其他离线备份"）、`offline_verified_at`（时间，可空，上次核对离线备份的时间）、`keyless`（布尔，必需，"无助记词钱包"） |
| `created_at` | 时间，必需 | |

### 5.3 `addresses[]`

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | 字符串，必需 | |
| `account_id` | 字符串，必需 | 所属账户 |
| `family` | 枚举，必需 | 链家族：`evm`、`bitcoin`、`solana`、`tron` |
| `address` | 字符串，必需 | 规范化的地址（EVM 为小写） |
| `enabled_chains` | 字符串数组，必需 | 启用的链：`ethereum`、`bsc`、`arbitrum`、`optimism`、`base`、`polygon`、`bitcoin`、`solana`、`tron`。应用按字典序写出。含不认识的链时跳过整个地址 |
| `scheme` | 枚举，可空 | 由助记词派生时的派生方案，手动添加的地址为 null。取值与路径（`{i}` 为序号）：`evmStandard` `m/44'/60'/0'/0/{i}`；`evmLedgerLive` `m/44'/60'/{i}'/0/0`；`btcNativeSegwit` `m/84'/0'/0'/0/{i}`；`btcTaproot` `m/86'/0'/0'/0/{i}`；`btcNestedSegwit` `m/49'/0'/0'/0/{i}`；`btcLegacy` `m/44'/0'/0'/0/{i}`；`solanaStandard` `m/44'/501'/{i}'/0'`；`solanaLegacy` `m/44'/501'/{i}'`；`tronStandard` `m/44'/195'/0'/0/{i}` |
| `derivation_index` | 整数，可空 | 派生序号 |
| `note` | 字符串，必需 | 备注，可为空字符串 |

### 5.4 `vault_items[]`

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | 字符串，必需 | 1–64 个 ASCII 字母、数字、`-`、`_` |
| `name` | 字符串，必需 | 条目名称 |
| `kind` | 枚举，必需 | `mnemonic`（助记词）或 `private_key`（私钥） |
| `created_at` | 时间，必需 | |
| `linked_account_ids` | 字符串数组 | 关联了这个条目的账户 id，**只供人阅读**（与 `accounts[].vault_item_id` 一致，恢复时以后者为准；读取方可以忽略） |
| `encoding` | 字符串，可空 | 缺失表示本条目的密钥字段是文本；`"hex"` 表示本条目的**全部**密钥字段都是原始字节的十六进制。其他值视为损坏 |
| `mnemonic` | 字符串，`kind` 为 `mnemonic` 时必需 | 助记词原文：以空格分隔的单词（BIP39 日文词表等使用该词表规定的分隔符），可直接抄到其他钱包。不能为空，不超过 1024 字节 |
| `passphrase` | 字符串，可空 | BIP39 附加密码（"第 25 个词"）。缺失或 null 表示没有；空字符串 `""` 表示附加密码是空串（与"没有"在 BIP39 中等价，但应用会如实保留） |
| `family` | 枚举，`kind` 为 `private_key` 时必需 | 链家族，取值同 5.3 |
| `private_key` | 字符串，`kind` 为 `private_key` 时必需 | 私钥。应用保存的是用户导入时的形式：若它是可打印的 ASCII 文本（如 EVM 的 `0x…` 十六进制、Bitcoin 的 WIF、Solana 的 Base58），原样写出；否则（原始二进制私钥）写十六进制并标 `"encoding":"hex"`。不能为空，不超过 256 字节 |

**文本形式与十六进制形式**：密钥字段（`mnemonic`、`passphrase`、`private_key`，以及 5.6 的凭据字段）是用户原始内容的字节。写入方的规则：当该对象所有密钥字段的字节都是合法 UTF-8、且不含控制字符（U+0000–U+001F、U+007F–U+009F；私钥另要求全部为 ASCII）时写成 JSON 字符串；否则该对象的全部密钥字段都写成小写十六进制，并加 `"encoding":"hex"`。读取方只需：有 `"encoding":"hex"` 时按十六进制（大小写均可，偶数个字符）解码，否则取字符串的 UTF-8 字节。两种形式都无损。

### 5.5 `settings`

| 字段 | 类型 | 取值（默认值） |
|---|---|---|
| `quote` | 枚举，必需 | 计价货币：`usd`（默认）、`cny` |
| `hide_small` | 布尔，必需 | 隐藏小额币种（默认 true） |
| `theme` | 枚举，必需 | 外观：`system`（默认）、`light`、`dark` |
| `auto_lock` | 枚举，必需 | 进入后台后多久需要重新解锁：`immediately`（默认）、`after1Min`、`after5Min` |

### 5.6 `exchange_credentials[]`

| 字段 | 类型 | 说明 |
|---|---|---|
| `account_id` | 字符串，必需 | 对应的交易所账户 |
| `encoding` | 字符串，可空 | 同 5.4 |
| `api_key` | 字符串，必需 | 只读 API Key |
| `api_secret` | 字符串，必需 | API Secret |
| `passphrase` | 字符串，可空 | 仅 OKX、Bitget 需要 |

## 6. 时间格式

UTC 的 ISO-8601 / RFC 3339：`YYYY-MM-DDTHH:MM:SS`，可带 1–6 位小数秒，**必须**带时区（`Z` 或 `±hh:mm`）。应用写出的形式是带 3 位毫秒的 UTC，如 `2026-11-13T08:30:00.000Z`；毫秒以下不为零时写 6 位。读取方接受上述任一形式并换算为 UTC；不带时区的时间视为损坏。

## 7. 完整示例

下面的文件是仓库中的 `packages/ow_vault/test/fixtures/backup_v1_format_example.owbak`（931 字节，SHA-256 `96939145c65b1bd98247855ff46d197fc054495ce1abde1df84beffefd3a747b`），测试断言应用对同样的输入总是写出这些字节。为便于手算，它使用了**测试用的极小参数**（8 KiB、迭代 1；真实文件为 256 MiB、迭代 3）和固定的 salt 与 nonce（真实文件中两者都是安全随机数）。内容全部是公开测试数据：

- 备份密码：`fake-backup-password`（UTF-8 字节 `66616b652d6261636b75702d70617373776f7264`）
- salt：`0102030405060708090a0b0c0d0e0f10`
- nonce：`202122232425262728292a2b2c2d2e2f3031323334353637`
- 助记词：BIP39 官方测试向量 `abandon … abandon about`

**定长部分（偏移 0–8）**

```
00000000  4f 57 42 4b                魔数 "OWBK"
00000004  01                         容器版本 1
00000005  00 00 00 cd                头部长度 L = 205
```

**头部 JSON（偏移 9–213，共 205 字节）**

```
00000009  7b 22 6b 64 66 22 3a 7b 22 61 6c 67 22 3a 22 61
00000019  72 67 6f 6e 32 69 64 22 2c 22 73 61 6c 74 22 3a
00000029  22 41 51 49 44 42 41 55 47 42 77 67 4a 43 67 73
00000039  4d 44 51 34 50 45 41 3d 3d 22 2c 22 6d 65 6d 5f
00000049  6b 69 62 22 3a 38 2c 22 69 74 65 72 73 22 3a 31
00000059  2c 22 70 61 72 61 6c 6c 65 6c 69 73 6d 22 3a 31
00000069  7d 2c 22 6e 6f 6e 63 65 22 3a 22 49 43 45 69 49
00000079  79 51 6c 4a 69 63 6f 4b 53 6f 72 4c 43 30 75 4c
00000089  7a 41 78 4d 6a 4d 30 4e 54 59 33 22 2c 22 63 72
00000099  65 61 74 65 64 5f 61 74 22 3a 22 32 30 32 36 2d
000000a9  31 31 2d 31 33 54 30 38 3a 33 30 3a 30 30 2e 30
000000b9  30 30 5a 22 2c 22 61 70 70 5f 76 65 72 73 69 6f
000000c9  6e 22 3a 22 31 2e 30 2e 30 2b 31 22 7d
```

即：

```json
{"kdf":{"alg":"argon2id","salt":"AQIDBAUGBwgJCgsMDQ4PEA==","mem_kib":8,"iters":1,"parallelism":1},"nonce":"ICEiIyQlJicoKSorLC0uLzAxMjM0NTY3","created_at":"2026-11-13T08:30:00.000Z","app_version":"1.0.0+1"}
```

**派生出的密钥**

```
K = Argon2id("fake-backup-password", salt, t=1, m=8 KiB, p=1) =
    f19a304178f58424ea2f6152fac511dc7dc8a7ae19417219fa61da771f14ecee
AAD = 文件偏移 0 到 213 的 214 个字节（上面两段，原样）
```

**密文（偏移 214 到文件末尾，共 717 字节 = 701 字节密文 + 16 字节标签）**

```
000000d6  75 18 bc 70 c3 97 af 2d 17 f3 68 d1 f0 80 5b b9
000000e6  1f 5f 84 04 46 af 61 e6 48 fd ab 64 14 79 2f 52
000000f6  04 50 e9 0e 43 a8 c7 f8 12 2d 52 ac 1e 46 31 1d
00000106  95 8a 0f d2 24 7a 4d 34 ae 89 59 14 97 34 1d 1f
00000116  d2 0b 3e f1 93 e9 05 a9 15 12 aa 81 0b fc ba e7
00000126  89 ef ce 5d cb 06 6d 71 b2 42 a4 d3 75 8a 30 7e
00000136  c3 25 ab 10 e6 4d 13 cb ce 19 ba 85 3f 68 89 cd
00000146  8b a2 f4 13 d7 ab f5 64 ad 3d 5c 58 a2 32 1b ae
00000156  e4 b2 16 33 cd 11 af 8c 61 51 11 14 fd 94 63 3a
00000166  c5 9a af 4d f4 bc 36 42 35 0a 64 dd da e2 55 ba
00000176  b7 23 65 87 de 0b e1 52 e0 5a c3 44 a7 41 4a ff
00000186  5a 34 d3 c8 6b ce 84 58 1a b8 b0 96 67 79 9f 03
00000196  4e 0c 9f c4 60 b9 14 39 5b f8 f6 5f 7a 8b bd 7a
000001a6  6c af c0 9d de b7 dc 05 f5 02 75 11 29 e7 a9 c3
000001b6  2e fa 44 16 de bf 78 f8 86 d3 0a 6d d4 a8 b4 8c
000001c6  43 f4 2b e2 71 15 71 4e 0c 3b a7 88 61 d1 2b b8
000001d6  4f 9e 09 b1 42 e9 06 ee e5 2a 9f d0 7d bb 99 5e
000001e6  90 cb e9 49 3b 08 1f 9d dc 97 b8 40 15 a1 ff f0
000001f6  98 1e 56 60 19 2b c4 5b 63 ec e0 c9 e9 86 8e d2
00000206  8e 47 cb 63 f7 a9 bd 1d d5 d3 06 dd 42 d2 90 f7
00000216  61 29 97 c1 58 58 25 b2 3a 2f 72 36 d6 a6 e5 d4
00000226  f4 af 6a b9 90 a2 eb 5c 7f 41 dc ec c7 6e 8e 2e
00000236  2b 07 12 3a 0e 79 aa 4a 77 a9 7d e3 29 9a cc eb
00000246  49 cf 47 45 f8 72 ed 9b 79 b2 7a 7f c9 00 7f b2
00000256  54 c7 9b 81 49 0a 08 67 23 1b 8c 26 79 7c 19 2c
00000266  11 b1 73 b6 77 a9 5c 42 17 b3 fd 29 fe e8 cd 44
00000276  ef 98 af 58 43 65 5e fa 25 e1 08 c6 73 3e 93 ae
00000286  e5 ff 1d 60 28 d9 2d 79 40 5b e1 ed 67 47 0d 33
00000296  0d 14 10 f6 fe 59 6c ee c6 94 6b 7c 9f a2 94 ef
000002a6  72 c6 ba c6 ee da fb f9 1e 5e ab 47 ca 57 59 9f
000002b6  7f 7e 53 ee 7e 71 3f fa d0 72 b2 43 92 c2 12 9f
000002c6  8a 33 33 87 e9 22 02 b4 79 5b 4b be 65 c3 de e6
000002d6  6a ba ab 73 32 47 af 79 28 c6 52 d8 00 e4 d2 3f
000002e6  6c 2c 0a 4a f2 1b 97 30 54 9e ab 3d 85 88 6b 7e
000002f6  a5 c0 f8 94 d6 5a 8e 08 b1 02 20 ae 86 38 23 d9
00000306  81 d1 8f 3d 21 5c d8 21 61 ec bf 27 7a fe 35 92
00000316  d7 ed 61 f5 ff 6e 02 c2 00 af c5 e4 82 2e 4d 5b
00000326  1b ac c9 3a 9b fa f5 08 6f 45 15 ef de 1c 81 ee
00000336  ea 79 f1 63 bc b9 dc 42 56 32 0e 89 fb 5a 2f ff
00000346  25 2d e4 36 25 e0 7b 00 84 08 86 2e a5 f7 97 50
00000356  64 90 62 e2 31 68 73 90 0a 33 81 cb 97 49 30 ca
00000366  bd 85 49 90 00 33 8c 38 a7 49 05 f4 ad 0f c0 55
00000376  33 36 bf 7e ab 50 21 36 bb 8b 24 cb 42 71 30 c7
00000386  29 c5 ed 57 6a 7e fe 77 6a 5d 5f 81 0c 53 63 de
00000396  d8 e5 37 e1 a8 04 a3 63 58 5f a6 2f 0c
```

最后 16 字节 `5363ded8e537e1a804a363585fa62f0c` 是认证标签。

**解密得到的载荷（701 字节，原样）**

```json
{"format":"onewallet-backup","payload_version":1,"exported_at":"2026-11-13T08:30:00.000Z","accounts":[{"id":"acc-1","type":"wallet","name":"Test","color_index":0,"note":"","wallet_source":null,"exchange":null,"vault_item_id":"item-1","backup":{"offline_backed_up":false,"offline_verified_at":null,"keyless":false},"created_at":"2026-11-13T08:30:00.000Z"}],"addresses":[],"vault_items":[{"id":"item-1","name":"Test","kind":"mnemonic","created_at":"2026-11-13T08:30:00.000Z","linked_account_ids":["acc-1"],"mnemonic":"abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"}],"settings":{"quote":"usd","hide_small":true,"theme":"system","auto_lock":"immediately"}}
```

仓库中还有一个内容更全的样本 `packages/ow_vault/test/fixtures/backup_v1_sample.owbak`（含带附加密码的助记词、文本与二进制私钥、多个地址、交易所凭据；密码同上），以及一个由 Python 按本文独立写出的样本 `backup_v1_python.owbak`（生成脚本 `generate_python_backup.py`，密码 `python-generated-password`）。

## 8. 版本与兼容规则

- **容器版本**（偏移 4）：容器结构、密钥派生或加密算法、AAD 的定义改变时加一。
- **载荷版本**（`payload_version`）：载荷中既有字段的含义或必需性改变时加一。只是**新增**字段或新增枚举值不升版本——读取方按第 5 节的规则忽略未知字段、跳过含未知枚举的条目。
- 读取方遇到高于自己支持的版本，应提示"请更新程序后再读取"，而不是猜测。
- 应用承诺：**任何新版本都能读取所有旧版本的文件**。版本 1 的固定样本随仓库保存，自动测试保证它始终能被读出。

| 容器版本 | 载荷版本 | 说明 |
|---|---|---|
| 1 | 1 | 首个版本（2026-11） |
