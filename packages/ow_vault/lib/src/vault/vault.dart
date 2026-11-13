import 'dart:typed_data';

import 'package:ow_domain/ow_domain.dart';

import '../crypto/vault_crypto.dart';
import 'vault_core.dart';
import 'vault_file.dart';
import 'vault_format.dart';
import 'vault_session.dart';

/// 保险库（SECURITY_DESIGN 第 3、5.1 节）：创建与解锁，得到 [VaultSession]。
///
/// 密钥层级：随机 32 字节 VMK；`KEK_pw = Argon2id(主密码, 16 字节 salt)`；用 `KEK_pw`
/// 以 XChaCha20-Poly1305 包裹 VMK 存入文件头；`K_item = KDF(VMK, "ow_items")` 加密
/// 条目，`K_fp = KDF(VMK, "ow_fprnt")` 计算查重指纹，`K_mac = KDF(VMK, "ow_fmac_")`
/// 计算文件整体校验值 `mac`（覆盖除 `mac` 外的全部内容）。任何解锁路径都在取得
/// VMK 之后、返回会话之前校验 `mac`；每次写入都重新计算。硬件包裹不在本类中（应用层用
/// [VaultSession.exportMasterKey] 与 [unlockWithMasterKey] 完成）。
///
/// 并发约定：一个保险库文件在进程内只由一个 [Vault] 实例管理。本实例上的创建、
/// 解锁与全部会话的写操作串行执行（见 `VaultCore`）。所有修改都构造完整的新文件
/// 交给 [VaultStorage.writeAtomic]，不做原地修改。
///
/// 传入的密码与主密钥不被清除，仍由调用方负责；本类内部的副本（KEK、VMK）
/// 在失败路径上立即清零，成功时交给会话持有，由 [VaultSession.close] 清零。
final class Vault {
  Vault({
    required VaultCrypto crypto,
    required VaultStorage storage,
    required KdfParams defaultParams,
  }) : _core = VaultCore(
         crypto: crypto,
         storage: storage,
         defaultParams: defaultParams,
       );

  final VaultCore _core;

  VaultCrypto get _crypto => _core.crypto;

  /// 保险库文件是否存在。读取失败时抛出存储层的异常。
  Future<bool> exists() async => (await _core.storage.read()) != null;

  /// 用主密码 [password] 创建新的保险库，返回已解锁的会话。
  ///
  /// 失败：密码为空 → `ValidationFailure`；文件已存在 → `VaultAlreadyExistsFailure`
  /// （绝不覆盖）；读写存储失败 → `UnknownFailure`。
  Future<Result<VaultSession>> create(Sensitive password) async {
    if (password.use((b) => b.isEmpty)) {
      return const Err(ValidationFailure('empty_password'));
    }
    return _core.mutex.run(() async {
      final existing = await _core.read();
      switch (existing) {
        case Err(:final failure):
          return Err(failure);
        case Ok(value: final Uint8List _):
          return const Err(VaultAlreadyExistsFailure());
        case Ok():
          break;
      }
      final vmk = _crypto.randomBytes(vmkLength);
      try {
        final file = await _newFile(vmk, password);
        final macKey = _macKey(vmk);
        final Result<void> written;
        try {
          written = await _core.commit(file, macKey);
        } finally {
          wipeBytes(macKey);
        }
        if (written case Err(:final failure)) {
          wipeBytes(vmk);
          return Err(failure);
        }
      } on Object {
        wipeBytes(vmk);
        rethrow;
      }
      _core.epoch++;
      return Ok(VaultSessionImpl(_core, vmk));
    });
  }

  Future<VaultFile> _newFile(Uint8List vmk, Sensitive password) async {
    final params = _core.defaultParams;
    final salt = _crypto.randomBytes(saltLength);
    final kek = await _crypto.argon2id(password, salt, params);
    try {
      final nonce = _crypto.randomBytes(nonceLength);
      return VaultFile(
        version: vaultFormatVersion,
        salt: salt,
        kdfParams: params,
        wrapNonce: nonce,
        wrapCiphertext: _crypto.aeadEncrypt(
          kek,
          nonce,
          vmk,
          vmkWrapAad(vaultFormatVersion),
        ),
        items: const [],
        mac: Uint8List(0),
      );
    } finally {
      wipeBytes(kek);
    }
  }

  Uint8List _macKey(Uint8List vmk) =>
      _crypto.deriveSubkey(vmk, macKeyContext, vaultSubkeyId);

  /// 用 [vmk] 校验 [file] 的整体校验值。
  bool _macValid(VaultFile file, Uint8List vmk) {
    final macKey = _macKey(vmk);
    try {
      return _core.verifyMac(file, macKey);
    } finally {
      wipeBytes(macKey);
    }
  }

  /// 用主密码解锁。
  ///
  /// 失败：文件不存在 → `VaultNotFoundFailure`；不是保险库文件或结构损坏 →
  /// `VaultCorruptedFailure`；版本过新 → `VaultVersionUnsupportedFailure`；
  /// 密码错误（包裹解不开）→ `WrongPasswordFailure`；包裹解开但整体校验值
  /// 不符（条目被删改、调换、插入，或 `mac` 被改）→ `VaultCorruptedFailure`。
  /// 认证加密无法区分"密码错"与"文件头里的 salt、参数或包裹被篡改"——它们会
  /// 先让包裹解不开——所以后者同样报告为 `WrongPasswordFailure`。
  /// 失败信息不含密码，也不透露密码"接近"与否。
  Future<Result<VaultSession>> unlockWithPassword(Sensitive password) async {
    if (password.use((b) => b.isEmpty)) {
      return const Err(WrongPasswordFailure());
    }
    return _core.mutex.run(() async {
      final loaded = await _load();
      if (loaded case Err(:final failure)) return Err(failure);
      final (file, bytes) = loaded.valueOrNull!;
      final kek = await _crypto.argon2id(password, file.salt, file.kdfParams);
      final Result<Uint8List> opened;
      try {
        opened = _crypto.aeadDecrypt(
          kek,
          file.wrapNonce,
          file.wrapCiphertext,
          vmkWrapAad(file.version),
        );
      } finally {
        wipeBytes(kek);
      }
      final vmk = opened.valueOrNull;
      if (vmk == null) return const Err(WrongPasswordFailure());
      if (vmk.length != vmkLength) {
        wipeBytes(vmk);
        return const Err(VaultCorruptedFailure('vmk_length'));
      }
      if (!_macValid(file, vmk)) {
        wipeBytes(vmk);
        return const Err(VaultCorruptedFailure('mac_mismatch'));
      }
      _core.adopt(file, bytes);
      return Ok(VaultSessionImpl(_core, vmk));
    });
  }

  /// 用硬件解包得到的主密钥 [masterKey] 解锁（`HardwareKeyStore.unwrap` 之后调用）。
  ///
  /// 用文件的整体校验值 `mac` 判定主密钥是否正确（空保险库同样可以校验）。
  /// 长度不是 32 字节或 `mac` 校验不通过 → `WrongPasswordFailure`：此时无法区分
  /// "主密钥不对"（例如过期的硬件包裹）与"文件被改"，对调用方而言都应退回
  /// 主密码解锁——若是文件被改，主密码解锁会报告 `VaultCorruptedFailure`。
  /// 其余失败与 [unlockWithPassword] 相同。[masterKey] 不被清除。
  Future<Result<VaultSession>> unlockWithMasterKey(Sensitive masterKey) async {
    final vmk = masterKey.use(Uint8List.fromList);
    if (vmk.length != vmkLength) {
      wipeBytes(vmk);
      return const Err(WrongPasswordFailure('master_key_length'));
    }
    final result = await _core.mutex.run(() async {
      final loaded = await _load();
      if (loaded case Err(:final failure)) return Err<VaultSession>(failure);
      final (file, bytes) = loaded.valueOrNull!;
      if (!_macValid(file, vmk)) {
        return const Err<VaultSession>(
          WrongPasswordFailure('master_key_mismatch'),
        );
      }
      _core.adopt(file, bytes);
      return Ok<VaultSession>(VaultSessionImpl(_core, vmk));
    });
    if (!result.isOk) wipeBytes(vmk);
    return result;
  }

  /// 读取并解析文件（在互斥内调用）。
  Future<Result<(VaultFile, Uint8List)>> _load() async {
    final read = await _core.read();
    switch (read) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        if (value == null) return const Err(VaultNotFoundFailure());
        return VaultFile.decode(value).map((file) => (file, value));
    }
  }
}
