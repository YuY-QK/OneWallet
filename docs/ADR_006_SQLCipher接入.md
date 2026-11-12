# ADR 006：SQLCipher 的接入方式

状态：已决定（任务 M0-13 的结论）· 2026-11-12。桌面环境（Linux x64）已验证，iOS 与 Android 设备上尚未验证（见"未验证事项"）。

## 背景

主数据库 `onewallet.db` 必须用 SQLCipher 加密（TECH_DESIGN 6.1），密钥是随机生成的 32 字节，存在系统安全存储里。TECH_DESIGN 第 9 节 T6 把"接入包"留到本任务确认。

接入包的格局在 2026 年初变了：`sqlite3` 3.x 起改用 Dart 的**构建钩子**（build hooks）分发原生库，不再需要 `sqlite3_flutter_libs`、`sqlcipher_flutter_libs` 这类 Flutter 插件。

## 候选

| 候选 | 情况（2026-11-12 查询 pub.dev 与包内文档） | 结论 |
|---|---|---|
| `sqlcipher_flutter_libs` | 最新版 0.7.0+eol（2026-02-15），pub.dev 描述为"Not used anymore, update to version 3.x of package:sqlite3 instead"；与 `sqlite3` 3.x 不兼容 | 不选（已终止维护） |
| `sqlite3` 3.9.1 + 构建钩子 `source: sqlcipher` | 官方推荐的新方式（包内 `doc/hook.md`）。预编译的 SQLCipher 社区版，覆盖 Android（armv7a、aarch64、x86、x64）、iOS（真机、模拟器）、macOS、Linux、Windows；下载时校验 sha256；提供 SLSA 3 证明与 SBOM；drift 2.35 的 `NativeDatabase` 直接使用 | 选用 |
| `sqlite3` 3.9.1 + `source: sqlite3mc`（SQLite3 Multiple Ciphers） | 同一套机制，换一个加密实现 | 备选：SQLCipher 出现问题时可在一行配置内切换，但文件格式不同，需迁移 |
| `drift_flutter` | 0.3.1，封装了路径、isolate 与加密库的选择 | 不选：多一层封装，且它仍声明依赖已终止的 `sqlcipher_flutter_libs`/`sqlite3_flutter_libs` |
| 自行用 CMake/SwiftPM 静态链接 SQLCipher，配合 `source: executable` | 完全可控 | 不选：要为两个平台写并维护原生构建，成本远超收益；保留为日后供应链要求更严时的出路 |

## 决定

1. 依赖 `sqlite3` 3.9.1（确切版本）与 `drift` 2.35.4；在**工作区根** `pubspec.yaml` 中设置：

   ```yaml
   hooks:
     user_defines:
       sqlite3:
         source: sqlcipher
   ```

   放在根目录是因为 pub 工作区里构建钩子的用户定义取自工作区根；实测 `flutter test` 与 `dart test` 在各子包下都会据此使用 SQLCipher 构建。这也意味着全部使用 `NativeDatabase.memory()` 的测试跑在 SQLCipher 上，与生产一致。

2. 打开方式（`packages/ow_platform` 的 `SqlCipherDatabaseOpener`）：
   - 数据库文件放在 `path_provider` 的应用支持目录，名为 `onewallet.db`；
   - `NativeDatabase.createInBackground`（后台 isolate），`setup` 回调里依次执行：
     1. `PRAGMA key = "x'<64 位十六进制>'"`：原始密钥格式，跳过口令派生，因为密钥本身就是 256 位随机数；
     2. `PRAGMA cipher_version`：必须有返回，否则说明链接的是普通 SQLite，抛异常拒绝打开，避免写出未加密的库；
     3. 读一次 `sqlite_master`：密钥不匹配或文件损坏时在此失败；
   - 密钥格式不对时在打开前就拒绝；任何异常信息都不含密钥或 SQL 文本（SQLite 的异常会带出语句，所以在 `PRAGMA key` 外面包了一层）。
   - 启动流程再执行一条 `SELECT 1` 触发真正的打开，失败时显示错误页，**不删除、不重建数据库**。

3. **`DatabaseOpener` 放在 `ow_platform`**（而不是 `app/lib/bootstrap/`）。理由：它涉及文件路径与加密库，属于平台适配；放在包里可以在桌面环境直接做加密行为的单元测试（`packages/ow_platform/test/database_opener_test.dart`）。代价是 `ow_platform` 多了 `drift`、`sqlite3`、`path_provider`、`path` 四个第三方依赖。`ow_platform` 对内部包的依赖规则不变（仍只有 `ow_domain`），`tools/ci/check_deps.dart` 无需修改；DEV_GUIDELINES 第 2 节的表已补充说明。

4. 备份排除：
   - Android：清单设置 `allowBackup="false"`、`fullBackupContent="false"`，并以 `dataExtractionRules` 排除云备份与设备迁移的全部域。已写入 `app/android/app/src/main/AndroidManifest.xml` 与 `res/xml/data_extraction_rules.xml`，**未经构建与设备验证**。
   - iOS：数据库与保险库文件需要设置 `isExcludedFromBackup`。查到的现成插件只有 `darwin_file_attributes`（1.1.0，2026-10 发布，0 个点赞，月下载约 1300），不够成熟，且手写未编译的 Swift 违反本任务约束，所以**留给 M0-11 的原生插件一并实现**。在此之前的缓解：钥匙串条目带 `ThisDeviceOnly`，不随备份迁移，因此被备份并恢复到新设备的数据库文件没有密钥，无法解密；启动流程会显示"密钥缺失"错误页，不会静默重建。

## 后果

- 构建时需要访问 GitHub Releases 下载预编译库（sha256 校验）。需要离线构建时用 `url_pattern` 指向内部制品库，或改用自行编译。
- SQLCipher 社区版为 BSD 风格许可，Android 版本链接 OpenSSL；发布前要在应用的开源许可页补上它们的声明（SECURITY_DESIGN 第 9 节供应链）。
- 包内文档提示：包随附的 SQLCipher 构建所含的 SQLite 版本可能比默认构建旧。升级 `sqlite3` 前要核对。
- SQLCipher 的页大小、KDF 迭代数等沿用 SQLCipher 4 的默认值。因为使用原始密钥，KDF 迭代数不影响安全性。
- 需要关闭数据库连接（应用锁，SECURITY_DESIGN 第 7 节）时，调用 `OwDatabase.close()`；重新解锁时再走一遍打开流程。

## 已在桌面验证的事项（Linux x64，自动化测试）

- 带密钥打开后写入的文件，头部不是 `SQLite format 3`，且搜不到写入的明文；
- 相同密钥重新打开，数据仍在；
- 错误密钥打开失败，异常信息不含密钥；
- 密钥缺失（数据库在、密钥没有）与密钥不匹配时，启动流程返回失败，数据库文件字节不变。

## 未验证事项（需要设备，已记入 DEVICE_TEST_CHECKLIST 第 3 节）

- iOS、Android 上 SQLCipher 预编译库能被构建钩子取到并链接，应用能启动；
- 根 `pubspec.yaml` 的 `hooks.user_defines` 对 `flutter build apk/ios` 同样生效（桌面的 `flutter test` 已确认）；
- 设备上导出的数据库文件无法用普通 SQLite 工具打开；
- Android 清单与 `data_extraction_rules.xml` 的实际备份行为；
- iOS 的备份排除（M0-11 实现后）；
- 安装包体积增量；Android 的 16 KB 页大小设备上能否加载该库。
