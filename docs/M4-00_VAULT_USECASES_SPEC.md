# M4-00 保险库与加密备份的用例层：实现规格

> 版本 1 · 2026-11-15 · 状态：已确认
> 这是任务 M4-00 的**唯一权威规格**。与其他文档有出入时：安全红线与 `SECURITY_DESIGN` 优先；其余以本文为准，并在交付说明中指出出入。
> 本文没有规定的细节，执行者可以自行决定，但必须在交付说明的"自行决定的事项"里逐条列出。
> 本文规定了的内容（名字、签名、失败类型、顺序、规则），**不得改动**。确实无法照做时停下来说明原因，不要自行变通。

## 0. 为什么要这一层

保险库核心（`packages/ow_vault`）已经完成：加解密、文件格式、地址派生、备份编解码。但页面不能直接调用它们，否则每个页面都要自己处理"解锁、取明文、用完清零、写元数据、关联账户"，任何一处疏漏都会泄露或丢失助记词。

这一层把每个用户操作封装成一个用例。完成后：

- 保险库页面（M4-05 至 M4-09）与备份页面（M5-03、M5-04）**只调用这些用例**；
- 页面代码里**不出现**任何加解密、密钥清零、保险库文件读写、助记词校验的代码。

## 1. 范围

**要做**

1. 在 `packages/ow_application/lib/src/vault/` 与 `lib/src/backup/` 实现第 4、5 节列出的全部用例与辅助类型。
2. 在 `packages/ow_application/lib/src/security/attempt_limiter.dart` 实现第 3.3 节的错误次数限制器（应用锁 M3-01 以后会复用它）。
3. 在 `packages/ow_vault/lib/src/derivation/` **新增**私钥格式校验与从私钥派生地址的函数（第 3.5 节）。
4. 在 `packages/ow_domain/lib/src/core/failure.dart` 新增第 2.3 节的两个失败类型，并同步所有穷尽判断。
5. 在 `app/lib/bootstrap/` 提供第 6 节列出的 provider。
6. 第 7 节的全部测试。
7. 第 8 节的文档同步。

**不要做**

- 任何页面、控制器、界面文案之外的界面代码（页面是 M4-05 至 M4-09、M5-03、M5-04）。
- 硬件密钥的原生实现（M0-11）。本任务只调用 `HardwareKeyStore` 接口，测试用假实现。
- 修改 `packages/ow_vault` 中已有的任何文件的行为、文件格式、备份格式、算法、参数。第 3.5 节只允许**新增**文件与新增函数。
- 修改已有用例的行为（`AddWalletAccount`、`SyncAccount` 等）。
- 引入任何新的第三方依赖。
- 放宽 `tools/ci/check_deps.dart` 的任何规则（`ow_application → ow_vault` 的依赖已由协调者开放，见第 9 节）。

## 2. 共通约定

### 2.1 用例的形态

照 `packages/ow_application/lib/src/accounts/add_wallet_account.dart` 的写法：

- 每个用例一个类，一个公开方法 `call(...)`，依赖全部通过构造函数注入。
- 可预期的失败返回 `Result<T>`；程序缺陷（参数违反文档写明的前置条件）抛 `ArgumentError` 或 `StateError`。
- 当前时间只用注入的 `Clock`；标识只用注入的 `IdGenerator`；不直接调用 `DateTime.now()`。
- 不写 `print`；不用 `dynamic`；单文件不超过 400 行、单函数不超过 60 行。

### 2.2 敏感数据的所有权（最重要）

| 规则 | 说明 |
|---|---|
| 密码、主密钥、助记词、私钥、passphrase、交易所 Secret 一律用 `Sensitive` 传递 | 不转成 Dart `String` 长期持有。确实需要 `String` 的地方只有两处：调用 `AddressDeriver.isValidMnemonic` 与派生地址，见 3.4、3.5；那两处的 `String` 必须是函数内的局部变量，函数返回前不再被引用 |
| **谁创建谁清零**；传给用例的 `Sensitive` 归调用方，用例**不清零**它 | 与 `ow_vault` 的约定一致 |
| 用例内部产生的明文（从保险库读出的条目、导出的主密钥、种子、解码出的备份载荷），用例在 `finally` 中清零 | 返回给调用方的除外，见下一行 |
| 用例**返回**的明文（只有 `RevealVaultItem` 返回明文），所有权转给调用方 | 文档注释写明"调用方用完必须 `wipe()`" |
| 每个用例打开的 `VaultSession` 在同一个用例调用内 `close()`，放在 `finally` 里 | 不存在跨调用存活的会话（PRD R24） |
| 敏感数据不进入：日志、`Failure.detail`、异常消息、`toString()`、任何返回给界面的普通值对象 | 用例的结果类型（如 `ImportedItem`）只含 id、名称、类型、指纹等非敏感字段 |

### 2.3 新增的失败类型

加在 `packages/ow_domain/lib/src/core/failure.dart` 的封闭集合里：

```dart
/// 生物识别不可用、被取消，或硬件包裹已失效（例如新增了指纹）。调用方应改用主密码。
final class BiometricUnavailableFailure extends Failure { const BiometricUnavailableFailure([super.detail]); }

/// 连续输错次数过多，在 [until] 之前不接受验证。
final class LockedOutFailure extends Failure {
  const LockedOutFailure(this.until, [super.detail]);
  final DateTime until;   // UTC
}
```

同步更新（缺一处都会编译失败或测试不全）：`app/lib/widgets/failure_text.dart` 的穷尽 switch、`app/lib/l10n/app_zh.arb` 的文案（运行 `flutter pub get` 重新生成并提交本地化文件）、`app/test/widgets/failure_text_test.dart`、`packages/ow_application/lib/src/sync/failure_type_name.dart` 及其测试、`app/lib/features/shared/sync_failure.dart` 的 `failureFromTypeName`（如果它对其他失败类型有映射）。

文案：`BiometricUnavailableFailure` → "无法使用生物识别，请输入主密码。"；`LockedOutFailure` → "输错次数过多，请在 {时间} 之后再试。"（时间用 `formatRelativeTime` 或 `HH:mm`，由你决定并说明）。

### 2.4 主密码的规则

- 创建与修改主密码时：去掉首尾空白后长度不少于 10 个字符（按 Unicode 码点计），否则 `ValidationFailure('master_password_too_short')`。**不做**其他强度校验（强度提示是页面的事）。
- 主密码与备份密码都**按输入的 UTF-8 字节原样**使用，不做 Unicode 规范化（与 `SECURITY_DESIGN` 5.2 一致）。
- 解锁时空密码直接返回 `WrongPasswordFailure`，不计入错误次数，不执行 Argon2id。

## 3. 共用组件

### 3.1 解锁凭据

```dart
/// 打开保险库的方式。
sealed class VaultCredential { const VaultCredential(); }
final class PasswordCredential extends VaultCredential {
  const PasswordCredential(this.password);
  final Sensitive password;           // 归调用方
}
final class BiometricCredential extends VaultCredential {
  const BiometricCredential({required this.reason});
  final String reason;                // 系统生物识别弹窗上的说明文字
}
```

### 3.2 `VaultAccess`：唯一的开会话入口

`lib/src/vault/vault_access.dart`。**所有用例都通过它打开会话**，不直接调用 `Vault.unlockWith*`。

```dart
final class VaultAccess {
  VaultAccess({
    required Vault vault,
    required HardwareKeyStore hardwareKeyStore,
    required SecretStore secretStore,
    required PlatformCapabilities capabilities,
    required SettingsRepository settings,
    required AttemptLimiter passwordLimiter,   // 键前缀 'ow.vault.unlock'
  });

  Future<bool> exists();

  /// 打开会话，执行 [body]，无论成败都在 finally 中关闭会话。
  /// [allowBiometric] 为 false 时，传入 BiometricCredential 直接返回 ValidationFailure('password_required')。
  Future<Result<T>> withSession<T>(
    VaultCredential credential,
    Future<Result<T>> Function(VaultSession session) body, {
    bool allowBiometric = true,
  });

  /// 用会话的主密钥生成硬件包裹并保存；会话由调用方提供，本方法不关闭它。
  Future<Result<void>> enableHardwareWrap(VaultSession session);

  /// 删除硬件包裹（别名与保存的包裹字节）。幂等。
  Future<void> disableHardwareWrap();
}
```

**硬件包裹的保存约定**

| 项 | 值 |
|---|---|
| `HardwareKeyStore` 的别名 | `ow.vault.vmk` |
| 包裹后的字节保存在 | `SecretStore` 键 `ow.vault.hw_wrapped`，值为 Base64 |
| 生成包裹 | `session.exportMasterKey()` → `hardwareKeyStore.wrap(别名, 主密钥字节)` → 保存包裹 → 在 `finally` 中清零导出的主密钥 |

**`withSession` 的流程**（照此顺序，不要增删步骤）

`PasswordCredential`：

1. 密码为空 → `WrongPasswordFailure`，结束（不计次数）。
2. `passwordLimiter.check()` 处于锁定 → `LockedOutFailure(until)`，结束。
3. `vault.unlockWithPassword(password)`。
4. 结果为 `WrongPasswordFailure` → `passwordLimiter.recordFailure()`，返回它当前给出的结果（可能是 `WrongPasswordFailure`，也可能因本次达到阈值而变为 `LockedOutFailure`，规则见 3.3）。
5. 其他失败（`VaultNotFoundFailure`、`VaultCorruptedFailure`、`VaultVersionUnsupportedFailure`、`UnknownFailure`）→ 原样返回，**不计**错误次数。
6. 成功 → `passwordLimiter.recordSuccess()`。
7. **生物识别恢复（PRD R30）**：如果 `settings.vaultBiometrics` 为真、`capabilities.hardwareKeystore` 为真、而 `SecretStore` 中没有 `ow.vault.hw_wrapped`（被上次的失效处理删除了），则调用 `enableHardwareWrap(session)`。它失败**不影响**本次操作，只是不恢复。
8. 执行 `body(session)`；无论 `body` 成败或抛异常，`finally` 中 `session.close()`。

`BiometricCredential`：

1. `allowBiometric` 为假 → `ValidationFailure('password_required')`。
2. `capabilities.hardwareKeystore` 为假，或 `settings.vaultBiometrics` 为假，或 `SecretStore` 中没有 `ow.vault.hw_wrapped` → `BiometricUnavailableFailure`。
3. `hardwareKeyStore.unwrap(别名, 包裹字节, reason: reason)`：用户取消（`USER_CANCELED`，通过 `BiometricUnavailableFailure.detail == 'user_canceled'` 区分）只返回 `BiometricUnavailableFailure`，**不删除**包裹；其他失败 → **删除**硬件包裹（`disableHardwareWrap()` 的删除部分，但**不改** `settings.vaultBiometrics`，这样下次主密码解锁时会按第 7 步自动恢复），返回 `BiometricUnavailableFailure`。
4. `vault.unlockWithMasterKey(主密钥)`；无论成败都在 `finally` 中清零解出的主密钥字节。失败（`WrongPasswordFailure`，即包裹过期，例如保险库被重建过）→ 同第 3 步删除包裹，返回 `BiometricUnavailableFailure`。
5. 生物识别解锁**不计**错误次数，也不清零错误次数。
6. 执行 `body(session)`，`finally` 中关闭会话。

### 3.3 `AttemptLimiter`：错误次数限制

`lib/src/security/attempt_limiter.dart`。实现 PRD R20、R31 与 `SECURITY_DESIGN` 第 7 节。应用锁（M3-01）以后用另一个键前缀复用它，所以**不要**写任何只适用于保险库的逻辑。

```dart
final class AttemptLimiter {
  AttemptLimiter({required SecretStore store, required Clock clock, required String keyPrefix});
  Future<LockState> check();          // 只读，不改变状态
  Future<Result<void>> recordFailure(); // 返回 Err(WrongPasswordFailure) 或 Err(LockedOutFailure)
  Future<void> recordSuccess();       // 清零
}
sealed class LockState {}
final class Unlocked extends LockState { final int failures; }
final class Locked extends LockState { final DateTime until; }
```

规则：

| 项 | 规则 |
|---|---|
| 持久化 | `SecretStore` 的三个键：`<前缀>.failures`（整数）、`<前缀>.lock_until`（UTC 毫秒）、`<前缀>.recorded_at`（写入时的 UTC 毫秒）。存在 SecretStore 而不是数据库，卸载重装与清空数据库都不能清掉 |
| 阈值 | 连续第 5 次失败时开始锁定 1 分钟；此后每多一次失败，锁定时长翻倍（2、4、8……分钟），上限 60 分钟 |
| 锁定期间 | `check()` 返回 `Locked`；`withSession` 直接返回 `LockedOutFailure`，不执行 Argon2id |
| 锁定结束后 | 失败次数**不清零**；下一次失败按"第 n 次"继续计算时长 |
| 成功 | 清零全部三个键 |
| 防改时间 | 如果当前时间早于 `recorded_at`（系统时间被往回调），按"锁定仍剩 `lock_until - recorded_at`"处理，即 `until = now + (lock_until - recorded_at)`，并把它写回 |
| 键值损坏或无法解析 | 视为已锁定 60 分钟（偏保守），并记一条不含数值的日志 |

### 3.4 助记词的规范化与校验

`lib/src/vault/mnemonic_input.dart`：

```dart
/// 把用户输入的助记词规范化并校验。成功时返回新的 Sensitive（归调用方）。
Result<Sensitive> normalizeMnemonic(Sensitive raw);
```

- 规范化：去掉首尾空白；任意空白序列合并为一个半角空格；ASCII 字母转小写。得到的 UTF-8 字节就是保存进保险库的字节。
- 校验：词数为 12、15、18、21、24 之一，且 `AddressDeriver.isValidMnemonic` 通过（BIP39 英文词表与校验和）。失败 → `ValidationFailure('mnemonic_invalid')`。
- 只支持英文词表（与 `AddressDeriver` 一致）。其他语言的助记词按校验失败处理，写进文档的已知局限。
- passphrase **不做**任何规范化，原样保存；空字符串与"没有 passphrase"不同（前者保存为空字节，后者为 null）。

### 3.5 私钥的格式与派生（在 `ow_vault` 中**新增**）

在 `packages/ow_vault/lib/src/derivation/` 新增文件 `private_key_format.dart`，并从 `ow_vault.dart` 导出。只用 `blockchain_utils`（已是 ow_vault 的依赖），不新增依赖，不改动已有文件的行为。

```dart
abstract final class PrivateKeyFormat {
  /// 校验并规范化用户输入的私钥文本。成功返回规范化后的 UTF-8 字节（新的 Sensitive，归调用方）。
  static Result<Sensitive> normalize(ChainFamily family, Sensitive raw);
  /// 由已规范化的私钥文本派生该链的地址（EVM 返回 EIP-55 形式）。
  static String addressOf(ChainFamily family, Sensitive normalized, {DerivationScheme? bitcoinScheme});
}
```

| 家族 | 接受的输入 | 规范化后保存的形式 | 地址 |
|---|---|---|---|
| EVM | 64 位十六进制，可带 `0x` 前缀，大小写均可 | 去掉 `0x`、转小写的 64 位十六进制 | 以太坊地址 |
| Tron | 同 EVM | 同 EVM | Tron 地址 |
| Bitcoin | WIF（Base58Check，版本字节 0x80，压缩或非压缩） | WIF 原文 | 由 `bitcoinScheme` 决定编码（默认原生隔离见证）；非压缩 WIF 只允许传统地址，其他编码返回 `ValidationFailure` |
| Solana | Base58 编码的 64 字节密钥对（Phantom 等导出的形式）或 32 字节种子 | Base58 原文 | 公钥的 Base58 |

- 任何不符合 → `ValidationFailure('private_key_invalid')`；`detail` 里**不得**含有输入内容。
- 这是 2026-11-14 的决定：私钥保存**导入时的文本形式**（`TASKS.md` 的 M4-06 条目）。同步修改 `SECURITY_DESIGN` 5.1 中关于条目明文里私钥内容的描述。
- 测试：每个家族至少一个公开的测试向量（例如以太坊文档或 BIP 中公开的示例私钥及其地址、比特币 WIF 的公开示例）；向量出处写在测试文件注释里。**不得**使用任何可能对应真实资产的私钥；找不到公开向量时用明显的假值（如 32 个 `0x01` 字节）并用另一套独立实现（Python `bip_utils`，已在 `packages/ow_vault/test/fixtures/` 里用过）算出期望地址。

## 4. 保险库用例（`lib/src/vault/`）

所有用例都依赖 `VaultAccess`；修改了保险库内容的用例在成功后把 `AppSettings.vaultChangedAt` 更新为当前时间（PRD R38 的"有未备份的更改"依赖它）。

### 4.1 `CreateVault`

```dart
Future<Result<void>> call({required Sensitive masterPassword, required bool enableBiometrics});
```

1. 校验主密码（2.4）。
2. 保险库已存在 → `VaultAlreadyExistsFailure`。
3. `vault.create(masterPassword)` 得到会话。
4. `enableBiometrics` 为真且 `capabilities.hardwareKeystore` 为真：`enableHardwareWrap(session)`；成功则设 `settings.vaultBiometrics = true`；失败**不影响**创建，`settings.vaultBiometrics` 保持假，并在结果里体现（返回值改为 `Result<CreateVaultOutcome>`，含 `biometricsEnabled`）。
5. `enableBiometrics` 为真但平台不支持：同上，`biometricsEnabled` 为假。
6. `finally` 关闭会话。
7. 设 `vaultChangedAt`。

### 4.2 `ImportVaultItem`

```dart
Future<Result<ImportedItem>> call({
  required VaultCredential credential,
  required String name,                 // 去首尾空白后 1–30 个字符
  required VaultItemInput input,        // 见下
  String? linkToAccountId,              // 可选：导入后关联到这个钱包账户
});

sealed class VaultItemInput {}
final class MnemonicInput extends VaultItemInput { final Sensitive mnemonic; final Sensitive? passphrase; }
final class PrivateKeyInput extends VaultItemInput { final ChainFamily family; final Sensitive key; }

final class ImportedItem { final String id; final String fingerprint; final VaultItemKind kind; }
```

顺序（不得调换）：

1. 校验名称；`linkToAccountId` 非空时账户必须存在且是钱包账户，否则 `ValidationFailure`。
2. **在打开会话之前**完成格式校验与规范化（3.4 或 3.5），得到规范化后的 `Sensitive`；本用例在 `finally` 中清零它。这样输错格式不会白白执行一次 Argon2id。
3. `withSession(credential, ...)`（允许生物识别）。
4. 会话内：`fingerprint = session.fingerprintOf(secret)`；`vaultMeta.byFingerprint(fingerprint)` 存在 → `ValidationFailure('vault_item_duplicate')`，`detail` 写已有条目的 id（不是内容）。
5. `id = ids.newId()`；`session.addItem(id, secret)`。
6. 写元数据 `VaultItemMeta`（名称、类型、词数或家族、是否有 passphrase、指纹、创建时间）。**写元数据失败时补偿**：调用 `session.deleteItem(id)` 把刚加的条目删掉，然后返回 `UnknownFailure('vault_meta_write_failed')`。补偿本身也失败时，返回同一个失败并在 `detail` 中加 `compensation_failed`（只写标识，不写内容）。
7. 有 `linkToAccountId` 时把该账户的 `vaultItemId` 设为 `id`（该账户原来关联了别的条目也直接覆盖，文档注释写明）。
8. 设 `vaultChangedAt`。

### 4.3 `RevealVaultItem`

```dart
Future<Result<VaultItemSecret>> call({required String itemId, required VaultCredential credential});
```

- 允许生物识别。返回的明文所有权归调用方，**调用方用完必须 `wipe()`**——在类与方法的文档注释里用醒目的方式写明。
- 条目不存在 → `VaultItemNotFoundFailure`。
- 本用例**不缓存**任何东西；每次调用都重新走 `withSession`（PRD R24）。
- 不修改 `vaultChangedAt`。

### 4.4 `DeleteVaultItem`

```dart
Future<Result<void>> call({required String itemId, required PasswordCredential credential});
```

- **只接受主密码**（PRD R32；签名上就限定为 `PasswordCredential`，并以 `allowBiometric: false` 调用 `withSession`）。
- 顺序：`session.deleteItem(itemId)` → 删除元数据 → 所有 `vaultItemId == itemId` 的账户把 `vaultItemId` 置为 null（它们的备份状态随之回落，R34）。
- 保险库里已经没有这个条目、但元数据还在（上次中途失败）时：视为成功，继续清理元数据与账户关联（幂等）。
- 设 `vaultChangedAt`。

### 4.5 `DeriveAddresses`

```dart
Future<Result<List<DerivedAddress>>> call({
  required String itemId,
  required VaultCredential credential,
  required DerivationScheme scheme,     // 私钥条目：EVM/Tron/Solana 忽略；Bitcoin 用于决定编码
  required int startIndex,              // ≥ 0
  required int count,                   // 1–20
});
final class DerivedAddress {
  final ChainFamily family; final String address;           // 地址按各家族的规范化形式
  final DerivationScheme? scheme; final int? index;          // 私钥条目为 null
  final bool alreadyWatched;                                 // 地址簿里已有
}
```

- 允许生物识别。
- 助记词条目：`scheme.family` 决定家族；用 `AddressDeriver` 从 `startIndex` 起派生 `count` 个。passphrase 参与种子计算。
- 私钥条目：只返回 1 个地址，家族取条目自己的家族；`scheme` 与家族不符时返回 `ValidationFailure`。
- **派生在独立 isolate 中进行**（`Isolate.run`）：把条目明文的字节**副本**传进去，在 isolate 内算种子与地址、清零，只把地址字符串传回。主 isolate 中读出的条目在 `finally` 中清零。理由与要求写在 `SECURITY_DESIGN` 6.5。
- `alreadyWatched` 通过 `AddressRepository.find(family, normalized)` 判断。
- 不访问网络。"检测余额"是页面另调链适配器的 `hasActivity`，不在本用例里。

### 4.6 `AttachDerivedAddresses`

```dart
Future<Result<Account>> call({
  required String itemId,
  required List<DerivedAddress> addresses,     // 来自 DeriveAddresses，至少 1 个
  String? existingAccountId,                   // 给已有钱包账户添加
  String? newAccountName,                      // 或者新建账户（二者必须且只能给一个）
  WalletSource? walletSource,
});
```

- **不需要解锁**（只写地址，不碰明文）。
- `itemId` 必须存在于元数据中，否则 `VaultItemNotFoundFailure`。
- 地址查重规则与 `AddWalletAccount` 一致（返回 `DuplicateAddressFailure`）；跳过 `alreadyWatched` 为真的地址，全部都已存在时返回 `ValidationFailure('nothing_to_attach')`。
- EVM 地址启用全部 6 条 EVM 链（PRD R3），其余家族固定一条。
- `WatchAddress.scheme`、`derivationIndex` 按 `DerivedAddress` 填写。
- 新建账户：用 `AccountRepository.insertWithAddresses`（单事务）；账户的 `vaultItemId = itemId`。
- 已有账户：账户必须是钱包账户；逐个 `AddressRepository.upsert`；并把账户的 `vaultItemId` 设为 `itemId`（原来为 null 或不同都覆盖）。
- 不触发同步（与 `AddWalletAccount` 一致，由调用方决定）。

### 4.7 `ChangeMasterPassword`

```dart
Future<Result<void>> call({required Sensitive currentPassword, required Sensitive newPassword});
```

- 只接受主密码（`withSession(PasswordCredential(current), ..., allowBiometric: false)`）；新密码按 2.4 校验，在打开会话**之前**校验。
- `session.changePassword(newPassword)`。主密钥不变，所以硬件包裹**不需要**重新生成。
- 设 `vaultChangedAt`（备份需要按新密码重新导出的提示由页面决定，不在本用例）。

### 4.8 `SetVaultBiometrics`

```dart
Future<Result<void>> call({required bool enable, PasswordCredential? credential});
```

- 开启：必须提供 `credential`（主密码），平台不支持 → `UnsupportedFailure()`（原因为 platform）。在会话内 `enableHardwareWrap`；成功后设 `settings.vaultBiometrics = true`。
- 关闭：不需要密码；`disableHardwareWrap()`，设 `settings.vaultBiometrics = false`。幂等。

### 4.9 `WatchVaultItems`

```dart
Stream<List<VaultItemSummary>> call();
final class VaultItemSummary { final VaultItemMeta meta; final List<String> linkedAccountIds; final List<String> linkedAccountNames; }
```

- 组合 `VaultMetaRepository.watchAll()` 与 `AccountRepository.watchAll()`，不解锁（PRD R23：看条目名称不需要验证）。
- 按创建时间升序。

## 5. 加密备份用例（`lib/src/backup/`）

### 5.1 `ExportBackup`

```dart
Future<Result<ExportedBackup>> call({
  required PasswordCredential masterCredential,   // 只接受主密码（PRD P17：此处不接受生物识别）
  required Sensitive backupPassword,              // 可以与主密码相同；按 2.4 校验长度
  required bool includeExchangeCredentials,       // 默认由页面传 false（R39）
  KdfParams? kdfParams,                           // null 时用 KdfParams.backupDefault
});
final class ExportedBackup {
  final Uint8List bytes;
  final String suggestedFileName;                 // OneWallet-备份-YYYYMMDD-HHmm.owbak（本地时间）
  final BackupSummary summary;                    // 账户数、地址数、条目数、是否含凭据
}
```

1. 在会话内逐条 `readItem` 读出全部条目（以元数据为清单）；组装 `BackupPayload`：账户、地址、条目（含元数据里的名称与创建时间）、`BackupSettings.of(当前设置)`、按需从 `CredentialRepository` 读出的交易所凭据。
2. 元数据里有、保险库里读不到的条目（`VaultItemNotFoundFailure`）：**整次导出失败**，返回该失败并在 `detail` 写条目 id。不要静默跳过——一份缺了条目的备份比没有备份更危险。
3. `BackupCodec.encode(...)`，`createdAt` 用注入的时钟，`appVersion` 由构造函数注入。
4. `finally` 中：`payload.wipe()`，并清零所有读出的条目。
5. **不**更新 `lastBackupExportedAt`（R41：用户确认已保存后才更新，见 5.2）。
6. `bytes` 是加密后的文件，不属于敏感数据，可以正常返回。

### 5.2 `ConfirmBackupSaved`

```dart
Future<void> call();   // 设 settings.lastBackupExportedAt = 现在
```

### 5.3 `OpenBackup` 与 `PendingRestore`

```dart
Future<Result<PendingRestore>> call({required Uint8List file, required Sensitive backupPassword});

final class PendingRestore {
  BackupPreview get preview;     // 创建时间、应用版本、账户数、地址数、条目数、是否含凭据、被跳过的条目数
  void dispose();                // 清零其中的载荷；之后再用抛 StateError
}
```

- 先 `BackupCodec.peekHeader` 做结构检查（不需要密码、不做 Argon2id），再 `decode`。
- 只解码一次；预览与恢复都用同一个 `PendingRestore`。页面离开时必须 `dispose()`（文档注释写明）。
- `PendingRestore` 不实现 `toString` 以外的任何能把内容转成字符串的方法；`toString()` 返回 `PendingRestore(***)`。

### 5.4 `RestoreBackup`

```dart
Future<Result<RestoreReport>> call({
  required PendingRestore pending,
  required RestoreMode mode,
  Sensitive? newMasterPassword,        // 本地没有保险库时必须提供（可由页面默认填备份密码）
  PasswordCredential? existingVault,   // 本地已有保险库时必须提供（只接受主密码）
});
enum RestoreMode { fresh, merge }      // fresh：首次引导；merge：设置里的"导入备份"
final class RestoreReport {
  final int accountsAdded, accountsSkipped;
  final int addressesAdded, addressesSkipped;
  final int itemsAdded, itemsSkipped;
  final int credentialsAdded;
  final List<BackupSkipped> unreadable; // 解码时就被跳过的（来自 BackupPayload.skipped）
}
```

**前置条件**

- `fresh`：本地数据库里没有任何账户、本地没有保险库，否则 `ValidationFailure('restore_target_not_empty')`。备份里有条目时必须给 `newMasterPassword`（按 2.4 校验）；备份里没有保险库条目且本地没有保险库时，不创建保险库、不要求 `newMasterPassword`。
- `merge`：本地有保险库且备份里有条目时必须给 `existingVault`；没有保险库但备份里有条目时必须给 `newMasterPassword`。备份里没有保险库条目且本地没有保险库时，不创建保险库、不要求 `newMasterPassword`。

**顺序与合并规则**（照做，不要"优化"）

1. **保险库条目**（先做，因为账户要引用条目 id；备份里没有保险库条目且本地没有保险库时，跳过本步直接跳到第 2 步）：
   - 本地没有保险库（且备份里有条目）：`vault.create(newMasterPassword)`。
   - 对备份里的每个条目，在同一个会话内：计算指纹；本地元数据已有相同指纹 → 跳过，并记下"备份条目 id → 本地已有条目 id"的映射；否则用**新 id**（`ids.newId()`）`addItem` 并写元数据（失败时按 4.2 第 6 步补偿），映射为"备份 id → 新 id"。
   - 名称冲突**不处理**（条目名称允许重复）。
2. **账户与地址**：
   - 备份里的每个账户：本地已有**相同 id** → 跳过整个账户（含其地址），计入 `accountsSkipped`。
   - 否则检查它的每个地址：本地已有相同 `(family, address)` → 跳过该地址；剩下的地址为空 → 跳过整个账户。
   - 名称与本地账户重名 → 名称后加" (2)"，仍重名则" (3)"，依此类推。
   - `vaultItemId` 按第 1 步的映射改写；映射里没有（备份里的条目被跳过且未映射，不应发生）→ 置为 null。
   - 用 `AccountRepository.insertWithAddresses` 写入（每个账户一个事务）。
3. **交易所凭据**：只为第 2 步**新加入**的交易所账户写入 `CredentialRepository`。
4. **设置**：只在 `fresh` 模式下 `BackupSettings.applyTo(本地设置)`；`merge` 模式保留本地设置。
5. 设 `vaultChangedAt`（有条目加入时）。

**失败与重试**

- 这个过程跨越保险库文件与数据库，**不是**全有或全无。中途失败时返回失败，已写入的部分保留。
- 因此恢复必须**幂等**：用同一个 `PendingRestore` 再执行一次，已写入的部分全部按上面的规则被跳过，剩余部分补上，最终结果与一次成功相同。测试必须覆盖这一点（第 7 节）。
- `RestoreBackup` 不调用 `pending.dispose()`；由页面在完成后调用。

## 6. 依赖装配（`app/lib/bootstrap/`）

新增一个文件 `vault_providers.dart`（并从 `providers.dart` 导出），提供：

| provider | 类型与说明 |
|---|---|
| `vaultCryptoProvider` | `FutureProvider<VaultCrypto>`，`SodiumVaultCrypto.load()` |
| `vaultStorageProvider` | `Provider<VaultStorage>`，`FileVaultStorage()` |
| `hardwareKeyStoreProvider` | `Provider<HardwareKeyStore>`。M0-11 完成前用一个"不支持"的占位实现：`wrap`、`unwrap` 返回 `Err(UnsupportedFailure())`；同时 `platformCapabilitiesProvider` 的 `hardwareKeystore` 已经是假，所以界面不会提供生物识别选项 |
| `vaultProvider` | `FutureProvider<Vault>`，`defaultParams: KdfParams.vaultDefault` |
| `vaultPasswordLimiterProvider` | `Provider<AttemptLimiter>`，键前缀 `ow.vault.unlock` |
| `vaultAccessProvider` | `FutureProvider<VaultAccess>` |
| 每个用例一个 provider | 名字为用例名首字母小写加 `Provider`，例如 `importVaultItemProvider`。依赖异步对象的用例用 `FutureProvider` |
| `vaultItemsProvider` | `StreamProvider<List<VaultItemSummary>>` |
| `appVersionProvider` | 如果还没有：`Provider<String>`，先返回 pubspec 里的版本号常量，并在注释里写明 M6-05 会接入真实版本 |

- 这些 provider 都必须能在测试中 override。
- **任何 provider 的状态值都不得包含明文**。`RevealVaultItem` 的结果由页面在调用处拿到、在页面自身的生命周期内持有，不放进 provider。

## 7. 测试（必须全部有）

放在 `packages/ow_application/test/vault/`、`test/backup/`、`test/security/`，`packages/ow_vault/test/derivation/`，`app/test/bootstrap/`。

**测试环境**：使用真实的 `SodiumVaultCrypto` 与很小的 KDF 参数（`KdfParams(memKib: 8, iterations: 1)`），保险库存储用内存假实现，硬件密钥、SecretStore、仓储用假实现（照 `packages/ow_application/test/fakes/` 的写法补充）。助记词只用 BIP39 公开测试向量（`abandon … about`、`legal winner … yellow`）；私钥只用 3.5 节规定的公开向量或明显的假值；交易所凭据用 `test-api-key` 之类。

| 编号 | 测试 |
|---|---|
| T1 | `AttemptLimiter`：第 1–4 次失败返回 `WrongPasswordFailure`；第 5 次返回 `LockedOutFailure` 且锁 1 分钟；锁定期间 `check` 为 `Locked`；锁定结束后第 6 次锁 2 分钟、第 7 次 4 分钟；上限 60 分钟；成功后清零；把时钟往回调不能提前解锁；键值损坏时锁 60 分钟。全部用假时钟 |
| T2 | `VaultAccess` 主密码路径：空密码不计次数且不执行 Argon2id（用包装过的 `VaultCrypto` 计数）；锁定期间不执行 Argon2id；`VaultCorruptedFailure` 不计次数；成功清零次数；`body` 抛异常时会话仍被关闭（用一个记录 `close` 的包装断言） |
| T3 | `VaultAccess` 生物识别路径：平台不支持、设置未开、没有包裹 → `BiometricUnavailableFailure`；`unwrap` 失败 → 删除包裹、设置保持开启、下次主密码解锁后自动重新包裹（R30）；包裹过期（保险库重建后）→ 同样处理；`allowBiometric: false` 时拒绝；生物识别成功不改变错误次数 |
| T4 | `CreateVault`：密码过短；已存在；开启生物识别成功与失败两种结果；平台不支持时创建仍成功 |
| T5 | `ImportVaultItem`：助记词（带与不带 passphrase、空 passphrase）与 4 种家族的私钥各一次往返（导入后 `RevealVaultItem` 读出的字节等于规范化后的字节）；格式错误时**不执行** Argon2id；重复导入返回 `vault_item_duplicate`；元数据写入失败时保险库里的条目被删掉（补偿）；`linkToAccountId` 生效；`vaultChangedAt` 被更新 |
| T6 | `RevealVaultItem`：条目不存在；两次调用都各自走一次解锁（用计数断言没有缓存） |
| T7 | `DeleteVaultItem`：签名只接受主密码；删除后元数据与账户关联被清理；保险库里已无条目而元数据还在时幂等成功 |
| T8 | `DeriveAddresses`：助记词条目的 9 种派生方案各取前 3 个地址，与 `packages/ow_vault/test/fixtures/derivation_vectors.json` 一致；私钥条目返回 1 个地址；`alreadyWatched` 正确；`count` 越界被拒绝 |
| T9 | `AttachDerivedAddresses`：新建账户（单事务）与加入已有账户两种；重复地址；全部已存在；EVM 启用 6 条链；`vaultItemId` 被设置 |
| T10 | `ChangeMasterPassword`：旧密码错误计次数；新密码过短在解锁前被拒绝；改后旧密码失效、新密码可用、硬件包裹仍可用 |
| T11 | `SetVaultBiometrics`：开启需要主密码；平台不支持；关闭幂等 |
| T12 | `ExportBackup` → `OpenBackup` → `RestoreBackup(fresh)` 全程往返：恢复后的账户、地址、条目明文、设置与原来一致；备份密码与主密码不同时各自生效；不含凭据与含凭据两种；元数据有而保险库缺条目时导出失败；导出后 `lastBackupExportedAt` 不变，`ConfirmBackupSaved` 后才变 |
| T13 | `RestoreBackup(merge)`：相同指纹的条目被跳过且账户的 `vaultItemId` 指向本地已有条目；相同 id 的账户被跳过；相同地址被跳过；地址全被跳过的账户被跳过；重名账户加后缀；凭据只为新账户写入；本地设置不变 |
| T14 | **幂等**：让存储或仓储在恢复中途第 k 步抛异常（k 取多个值），再用同一个 `PendingRestore` 重试，最终状态与一次成功完全相同，没有重复的账户、地址或条目 |
| T15 | `PendingRestore.dispose()` 后再用抛 `StateError`；`toString` 不含内容 |
| T16 | `PrivateKeyFormat`：每个家族的合法与非法输入；`detail` 不含输入；地址与公开向量或独立实现一致 |
| T17 | 泄露检查：对 T5、T12 中用到的助记词单词与私钥文本，断言它们不出现在任何 `Failure.detail`、任何结果对象的 `toString()`、假日志收集到的任何一行里 |
| T18 | `app/test/bootstrap/`：所有新 provider 在 override 了存储与平台能力后都能构造；`vaultItemsProvider` 能发出列表 |

覆盖率：`ow_application` 不低于 85%，`ow_vault` 保持 90% 以上（在交付说明里写出数字与测法）。

## 8. 文档同步

- `docs/IMPLEMENTATION_SPEC_v1.0.md` 第 4 节：把 M4、M5 行的用例名改成本文第 4、5 节的实际名称，并引用本文。
- `docs/SECURITY_DESIGN_v1.0.md`：5.1 节私钥条目内容改为"导入时的规范化文本形式"；6.5 节写明派生在独立 isolate 中进行、主密码与错误次数的存放位置；第 7 节写明 `AttemptLimiter` 的规则与键名。
- `docs/TASKS.md`：M4-00 标为 `[x]`，写明完成日期。
- `docs/DEVICE_TEST_CHECKLIST.md`：追加一节（编号顺延），列出只能在真机上确认的项：Argon2id 与派生时界面是否卡顿；生物识别相关流程（等 M0-11 完成后）。
- 本文件本身不要修改；发现本文有错误或无法实现的地方，写在交付说明里。

## 9. 协调者已经做好的准备

- `tools/ci/check_deps.dart` 已允许 `ow_application` 依赖 `ow_vault`；`docs/DEV_GUIDELINES_v1.0.md` 第 2 节已同步。`ow_application` 的 pubspec 由你加上 `ow_vault` 的路径依赖。
- `TASKS.md` 中 M4-00 已改为交给执行者。

## 10. 必须停下来问用户的情况

- 本文的规定与已有代码的接口无法对上（例如某个仓储缺少需要的方法）。**不要**为此修改 `ow_domain` 的已有接口签名；先停下来说明缺什么、建议怎么补。
- 需要修改 `packages/ow_vault` 中已有文件的行为。
- 发现本文的规则会导致丢失数据或泄露明文。
- 需要新增任何第三方依赖。

## 11. 交付

- 分支：从默认分支建 `feat/M4-00-vault-usecases`，开工前与交付前各同步一次默认分支。
- 提交按小块拆分，每块都能通过 `tools/check.sh`。建议顺序：失败类型与限制器 → `VaultAccess` → 私钥格式 → 保险库用例 → 备份用例 → provider 与文档。
- 交付说明按 `docs/EXECUTION_GUIDE.md` 第 8 节的格式，另外必须包含：第 7 节每个测试编号对应的测试文件与用例名；覆盖率数字；"自行决定的事项"逐条；对本文的疑问或发现的问题。
