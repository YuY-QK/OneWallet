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
/// 条目，`K_fp = KDF(VMK, "ow_fprnt")` 计算查重指纹。硬件包裹不在本类中（应用层用
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
        final written = await _core.commit(file);
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
      );
    } finally {
      wipeBytes(kek);
    }
  }

  /// 用主密码解锁。
  ///
  /// 失败：文件不存在 → `VaultNotFoundFailure`；不是保险库文件或结构损坏 →
  /// `VaultCorruptedFailure`；版本过新 → `VaultVersionUnsupportedFailure`；
  /// 密码错误 → `WrongPasswordFailure`。认证加密无法区分"密码错"与"文件头里的
  /// salt、参数或包裹被篡改"，后者同样报告为 `WrongPasswordFailure`。
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
      _core.adopt(file, bytes);
      return Ok(VaultSessionImpl(_core, vmk));
    });
  }

  /// 用硬件解包得到的主密钥 [masterKey] 解锁（`HardwareKeyStore.unwrap` 之后调用）。
  ///
  /// 保险库文件中没有可直接校验 VMK 的字段，所以用"至少一个条目能以它派生的
  /// `K_item` 通过认证解密"来确认主密钥正确。因此：
  /// - 长度不是 32 字节，或没有任何条目能解开 → `WrongPasswordFailure`
  ///   （应用层据此改为要求主密码）；
  /// - **保险库里一个条目都没有时无法校验，同样返回 `WrongPasswordFailure`**，
  ///   必须用主密码解锁。否则一个过期的硬件包裹（例如保险库被重建后）会让
  ///   新条目用错误的密钥写入，日后用主密码也读不出来。
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
      if (file.items.isEmpty) {
        return const Err<VaultSession>(
          WrongPasswordFailure('master_key_unverifiable'),
        );
      }
      if (!_verifiesAnyItem(vmk, file)) {
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

  bool _verifiesAnyItem(Uint8List vmk, VaultFile file) {
    final itemKey = _crypto.deriveSubkey(vmk, itemKeyContext, vaultSubkeyId);
    try {
      for (final item in file.items) {
        final opened = _crypto.aeadDecrypt(
          itemKey,
          item.nonce,
          item.ciphertext,
          itemAad(file.version, item.id, item.kind),
        );
        final plaintext = opened.valueOrNull;
        if (plaintext != null) {
          wipeBytes(plaintext);
          return true;
        }
      }
      return false;
    } finally {
      wipeBytes(itemKey);
    }
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
