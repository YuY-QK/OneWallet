# ADR 005：libsodium 的接入方式

状态：已决定（任务 M4-01 的结论，TECH_DESIGN 第 9 节 T7）· 2026-11-13。桌面环境（Linux x64，`dart test`）已验证；iOS 与 Android 设备上尚未验证（见"未验证事项"）。

## 背景

保险库的全部密码学原语来自 libsodium（ADR_003、SECURITY_DESIGN 第 4 节）：`randombytes_buf`、`crypto_pwhash`（Argon2id）、`crypto_aead_xchacha20poly1305_ietf_*`、`crypto_kdf_derive_from_key`、`crypto_generichash`。需要确定 Dart 侧用哪个绑定、原生库如何进入应用、在纯 Dart 的单元测试里如何加载，以及它对 `ow_vault` 依赖白名单的影响。

原定在 M0-12（真机技术验证）中确认；真机验证推迟到整体测试（TASKS M0 门禁），本 ADR 先记录桌面环境下的结论，Argon2id 的真机定标仍归 M0-12。

## 候选

| 候选 | 情况（2026-11-13 查询 pub.dev 与包内源码） | 结论 |
|---|---|---|
| `sodium` 4.1.2+1 | 2026-10-27 发布，BSD-3 许可，作者 Skycoder42。纯 Dart 绑定（`dart:ffi`），不依赖 Flutter。4.x 起用 Dart **构建钩子**从包内随附的 libsodium **源码**（`3rdparty/libsodium-1.0.22-stable.tar.gz`，附 minisign 签名）就地编译原生库，覆盖 Android、iOS、macOS、Linux、Windows；Web 端另有 JS 加载方式 | 选用 |
| `sodium_libs` | 3.x 时代为 Flutter 提供预编译库的配套插件；已停止维护（HANDOFF 2.3） | 不选 |
| 直接用 `dart:ffi` 绑定系统 libsodium 的少数函数 | 可控、代码量小；但要自己解决 iOS/Android 上库的来源与打包，等于重做 `sodium` 包的构建钩子 | 不选；保留为 `sodium` 包出问题时的出路（仍只调用 libsodium 高层接口，届时另写 ADR） |
| 纯 Dart 的密码学实现（`cryptography`、`pointycastle` 等） | 非 libsodium，违背 ADR_003 与 SECURITY_DESIGN 第 4 节 | 不选 |

## 决定

1. `ow_vault` 依赖 `sodium`，版本锁定为确切的 **4.1.2+1**。所用 libsodium 版本为 **1.0.22**（`SodiumVaultCrypto.libraryVersion` 可查）。
2. **原生库的来源**：`sodium` 的构建钩子（`hook/build.dart`）在构建时解压包内随附的源码包，用本机 C 工具链编译：
   - 桌面测试（Linux）：`./configure && make`，需要 `gcc`/`cc` 与 `make`（`ubuntu-latest` 自带）。首次约 25 秒，结果缓存在 `.dart_tool/`；
   - Android：使用 Flutter 传入的 NDK 工具链（找不到时尝试经 `flutter` 工具探测 NDK 路径）；
   - iOS：使用 Xcode 工具链按真机/模拟器分别编译；
   - **构建时不联网**：源码随包分发（pub 对整个包做 sha256 校验）。与 `sqlite3` 的钩子（下载预编译库）不同，不需要 `hooks.user_defines` 配置，根 `pubspec.yaml` 无需改动。
   - 随附源码包的签名已在本机用 libsodium 的发布公钥（`RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3`，即包内 `HookConstants.libsodiumSigningKey`）核对通过：`minisign` 预哈希签名（`ED`）与全局签名均有效，可信注释为 `file:libsodium-stable.tar.gz`，源码包 sha256 为 `5d829f95ea7be72eedf373b197f01df765171da80619b1291692d3f854e10e46`。核对用的是 PyNaCl 的 Ed25519 验证；该公钥与 libsodium 官方文档公布的一致这一点依据的是已有知识，本环境无法访问 libsodium 网站再次比对。
3. **初始化**：`SodiumVaultCrypto.load()` 调用 `SodiumSumoInit.init()`。不需要传入库路径——原生库作为"代码资产"随应用打包，由 `@Native` 绑定自动加载。`dart test` 与 `flutter test`、`flutter build` 都会执行构建钩子（`dart test` 输出中的 "Running build hooks..." 即此）。4.x 的公开初始化接口不接受外部动态库，因此**不使用系统自带的 libsodium**（本机的 `/usr/lib/x86_64-linux-gnu/libsodium.so.23` 未被用到）。
4. **用 Sumo 变体**：`crypto_pwhash` 在 `sodium` 包里只属于 `SodiumSumo` 接口。这一区分只对 Web 端（sodium.js 分标准版与 sumo 版）有意义；原生平台上是同一个库。
5. **Argon2id 不阻塞界面**：`argon2id` 经 `Sodium.runIsolated` 在新的 isolate 中计算。密码先复制进 libsodium 安全内存（`SecureKey`），以原生内存句柄转交给该 isolate，不在 Dart 堆上产生副本；结果同样以 `SecureKey` 句柄传回，取出字节后立即释放。AEAD、KDF、BLAKE2b 都是微秒级，同步执行。
6. **并行度**：libsodium 的 `crypto_pwhash_argon2id` 把 Argon2 的 lanes 固定为 1（`src/libsodium/crypto_pwhash/argon2/pwhash_argon2id.c`：`argon2id_hash_raw(opslimit, memlimit / 1024U, 1U, …)`）。SECURITY_DESIGN 第 4 节规定的就是"并行 1"，两者一致；`KdfParams.parallelism` 只接受 1，文件头里的 `parallelism` 不为 1 视为损坏。内存参数以 KiB 为单位传入，实现乘以 1024 交给 libsodium，libsodium 再整除 1024，所以没有取整误差。
7. **密钥材料的处理**：每次调用把传入的密钥复制进 `SecureKey`（`sodium_malloc` 分配、`mlock` 锁定），调用结束即 `dispose`（`sodium_free` 先清零再释放）。`VaultCrypto` 接口（IMPLEMENTATION_SPEC 第 6 节）以 `Uint8List` 收发密钥，所以 Dart 堆上的那一份由调用方负责清零（保险库会话在 `close()` 时清零）。

## 对 `tools/ci/check_deps.dart` 的影响

1. `vaultAllowed` 加入 `sodium`。
2. **扫描范围扩大到传递依赖**：原来只扫描白名单里直接列出的第三方包（`blockchain_utils` 零依赖，所以足够）；`sodium` 有传递依赖，现在沿各包 `pubspec.yaml` 的 `dependencies` 求出全部传递依赖，逐一扫描其 `lib/`。当前闭包：`sodium`、`blockchain_utils`、`archive`、`args`、`code_assets`、`collection`、`convert`、`crypto`、`csslib`、`ffi`、`freezed_annotation`、`hooks`、`html`、`json_annotation`、`logging`、`meta`、`path`、`posix`、`pub_semver`、`record_use`、`source_span`、`string_scanner`、`term_glyph`、`typed_data`、`yaml`。
3. **新增导入闭包检查**：从 `packages/ow_vault/lib` 出发，沿 `import`、`export`、`part`（**条件导入的全部分支都计入**，比任何一个平台实际编译的范围都大）求出可达源文件，逐一扫描联网迹象，并断言登记为例外的文件不在其中。当前闭包约 850 个文件，只涉及 `ow_vault`、`ow_domain`、`decimal`、`rational`、`blockchain_utils`、`sodium`、`meta`、`freezed_annotation`、`json_annotation`、`collection`、`ffi`。
4. **例外（共 1 条）**，登记在 `vaultNetworkSignExceptions`：

   | 包 | 文件 | 命中 | 为什么安全 |
   |---|---|---|---|
   | `sodium` | `lib/src/js/update_web/js_library_loader.dart` | `HttpClient()` | 这是 `dart run sodium:update_web` 命令行工具为 Web 端下载 `sodium.js` 的代码，只被 `bin/update_web.dart` 导入。`sodium.dart`、`sodium_sumo.dart` 及其所有条件导入分支（`ffi`、`js`、`fallback`）都不导入它；第 3 条的闭包检查每次 CI 都重新验证这一点。我们不运行该工具，也不构建 Web 端 |

   例外文件不存在时（依赖升级后改名或删除）脚本报错，迫使重新审阅；例外所属的包不再是保险库依赖时也报错。
5. 其他传递依赖的用途（逐包核对 `import` 得出）：`archive`、`posix`、`crypto`、`code_assets`、`hooks`、`path` 只被构建钩子（`hook/build.dart` 与 `lib/src/hooks/`）使用，在开发机的构建过程中运行，不编进应用；`html`、`args`、`convert` 只被 `bin/update_web.dart` 及上述 JS 下载代码使用。这些包本身的 `lib/` 也在第 2 条的扫描范围内，均无命中。
6. 没有放宽任何已有规则：`vaultForbiddenImports`（保险库自身代码不得导入 `dart:io` 等）不变；`networkSigns` 正则不变。

## 测试向量

| 原语 | 官方向量 | 独立实现对照 |
|---|---|---|
| Argon2id | libsodium 测试套件 `test/default/pwhash_argon2id.c` 的 `tv()` 8 组（含 1 组"输出长度过短必须失败"），由 `packages/ow_vault/test/fixtures/extract_libsodium_vectors.py` 从随附源码包提取 | PyNaCl（自带并绑定 libsodium，与 Dart 绑定是两套代码）计算 32 字节输出的 5 组，含默认参数 64 MiB/3 |
| XChaCha20-Poly1305-IETF | draft-irtf-cfrg-xchacha-03 附录 A.3.1（本环境无法访问 IETF 站点，按草案转录；生成脚本断言 PyNaCl 得出逐字节相同的密文与标签）；libsodium `aead_xchacha20poly1305` 测试 | — |
| `crypto_kdf` | libsodium `kdf` 测试（上下文 `KDF test`，长度 16–64、id 0–65 共 59 组） | Python 标准库 `hashlib.blake2b`（CPython 自带实现）按 libsodium 文档的等价定义计算本项目上下文 `ow_items`、`ow_fprnt` |
| 带密钥的 BLAKE2b | libsodium `generichash` 测试表（即 BLAKE2 官方 keyed KAT）13 组 | `hashlib.blake2b` 计算 32 字节密钥、16 字节输出 |

样本文件：`libsodium_vectors.json`（官方）、`crosscheck_vectors.json`（对照，非官方），生成脚本与之同目录。

## 后果

- 构建应用与运行 `ow_vault` 的测试需要 C 工具链；Android 需要 NDK（Flutter 工程本来就需要），iOS 需要 Xcode。
- 每次构建（缓存失效时）从源码编译 libsodium，首次增加约半分钟。
- 升级 `sodium` 时：审阅代码差异（SECURITY_DESIGN 第 9 节）；重跑 `extract_libsodium_vectors.py`；重新核对随附源码包的 minisign 签名；`check_deps` 的例外若失效会报错。
- libsodium 与 `sodium` 包均为 ISC/BSD 类许可，发布前在开源许可页补上声明。
- `Uint8List` 形式的密钥位于 Dart 堆，垃圾回收移动对象时可能留下无法清除的旧副本。这属于 SECURITY_DESIGN 6.5 记载的已知局限的一部分；接口改为直接传递 `SecureKey` 可以缓解，但要改 IMPLEMENTATION_SPEC 的签名，本任务不做，记为后续可选改进。

## 未验证事项（需要设备，已记入 DEVICE_TEST_CHECKLIST）

- Android（armv7a、arm64、x86_64）与 iOS（真机、模拟器）上构建钩子能用各自工具链编出 libsodium 并随应用打包，`SodiumVaultCrypto.load()` 成功；
- `Sodium.runIsolated` 在设备上正常工作，Argon2id 计算期间界面不卡顿；
- Argon2id 在两台真机上的耗时与参数定标（M0-12）；
- Android 16 KB 页大小设备上能否加载该库；安装包体积增量。
