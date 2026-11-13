import 'dart:typed_data';

import 'package:ow_domain/ow_domain.dart';

import 'item_codec.dart';
import 'vault_core.dart';
import 'vault_file.dart';
import 'vault_format.dart';
import 'vault_item_secret.dart';

/// 已解锁的保险库会话。用完必须 [close]，会清除内存中的主密钥与子密钥。
///
/// [close] 之后（或保险库文件被替换导致会话失效后）调用任何方法都抛出
/// [StateError]。写操作在所属 `Vault` 上串行执行，只有写入存储成功后内存状态
/// 才改变；写入失败返回 `Err`，会话与存储都保持原样。
abstract interface class VaultSession {
  /// 主密钥 VMK 的副本，仅用于生成硬件包裹。
  ///
  /// 返回的 [Sensitive] 归调用方，用完须 `wipe()`；清除它不影响本会话。
  Sensitive exportMasterKey();

  /// 解密并返回条目 [id] 的明文。返回的对象归调用方，用完须 `wipe()`。
  ///
  /// 失败：没有该条目 → `VaultItemNotFoundFailure`；密文认证失败（被篡改、与其他
  /// 条目互换、id 或 kind 被改）或明文不是规范编码 → `VaultCorruptedFailure`。
  Future<Result<VaultItemSecret>> readItem(String id);

  /// 加密保存 [secret]，成功返回查重指纹（32 位小写十六进制）。
  ///
  /// [secret] 仍归调用方，本方法不清除它。失败：[id] 不合法或已存在、内容为空
  /// 或过长 → `ValidationFailure`；写入存储失败 → `UnknownFailure`。
  Future<Result<String>> addItem(String id, VaultItemSecret secret);

  /// 删除条目 [id]。没有该条目 → `VaultItemNotFoundFailure`；写入失败 → `UnknownFailure`。
  Future<Result<void>> deleteItem(String id);

  /// [secret] 在本保险库下的查重指纹：带密钥的 BLAKE2b（密钥 `K_fp` 派生自 VMK），
  /// 输出截取 16 字节。同一保险库内同一内容的指纹相同；不同保险库互不相同，
  /// 不能跨库关联。[secret] 不合法时抛出 [ArgumentError]。
  String fingerprintOf(VaultItemSecret secret);

  /// 改主密码：生成新 salt，用默认参数重新派生 `KEK_pw` 并重新包裹 VMK。
  ///
  /// VMK 不变，所以条目不需要重新加密。新密码为空 → `ValidationFailure`；
  /// 写入失败 → `UnknownFailure`（旧密码仍然有效）。[newPassword] 不被清除。
  Future<Result<void>> changePassword(Sensitive newPassword);

  /// 清零主密钥与子密钥并结束会话。可重复调用。
  void close();
}

/// [VaultSession] 的实现（不导出）。持有 VMK、`K_item`、`K_fp`、`K_mac` 四份
/// 32 字节密钥，由 [close] 清零。
final class VaultSessionImpl implements VaultSession {
  /// 接管 [vmk] 的所有权，并派生两个子密钥。
  VaultSessionImpl(this._core, Uint8List vmk)
    : _vmk = vmk,
      _epoch = _core.epoch,
      _itemKey = _core.crypto.deriveSubkey(vmk, itemKeyContext, vaultSubkeyId),
      _fingerprintKey = _core.crypto.deriveSubkey(
        vmk,
        fingerprintKeyContext,
        vaultSubkeyId,
      ),
      _macKey = _core.crypto.deriveSubkey(vmk, macKeyContext, vaultSubkeyId);

  final VaultCore _core;
  final int _epoch;
  final Uint8List _vmk;
  final Uint8List _itemKey;
  final Uint8List _fingerprintKey;
  final Uint8List _macKey;
  var _closed = false;

  void _ensureOpen() {
    if (_closed) throw StateError('保险库会话已关闭');
    if (_core.epoch != _epoch) {
      close();
      throw StateError('保险库文件已被替换，会话已失效');
    }
  }

  @override
  Sensitive exportMasterKey() {
    _ensureOpen();
    return Sensitive(Uint8List.fromList(_vmk));
  }

  @override
  Future<Result<VaultItemSecret>> readItem(String id) async {
    _ensureOpen();
    final file = _core.current!;
    final item = file.item(id);
    if (item == null) return const Err(VaultItemNotFoundFailure());
    final opened = _core.crypto.aeadDecrypt(
      _itemKey,
      item.nonce,
      item.ciphertext,
      itemAad(file.version, item.id, item.kind),
    );
    final plaintext = opened.valueOrNull;
    if (plaintext == null) {
      return const Err(VaultCorruptedFailure('item_auth_failed'));
    }
    try {
      final secret = ItemCodec.decode(plaintext);
      if (secret == null) {
        return const Err(VaultCorruptedFailure('item_plaintext'));
      }
      if (secret.kind != item.kind) {
        secret.wipe();
        return const Err(VaultCorruptedFailure('item_kind_mismatch'));
      }
      return Ok(secret);
    } finally {
      wipeBytes(plaintext);
    }
  }

  @override
  Future<Result<String>> addItem(String id, VaultItemSecret secret) async {
    _ensureOpen();
    if (!VaultFile.itemIdPattern.hasMatch(id)) {
      return const Err(ValidationFailure('invalid_item_id'));
    }
    final invalid = ItemCodec.invalidReason(secret);
    if (invalid != null) return Err(ValidationFailure(invalid));
    final plaintext = ItemCodec.encode(secret);
    final String fingerprint;
    final VaultFileItem item;
    try {
      fingerprint = _fingerprint(plaintext);
      final nonce = _core.crypto.randomBytes(nonceLength);
      item = VaultFileItem(
        id: id,
        kind: secret.kind,
        nonce: nonce,
        ciphertext: _core.crypto.aeadEncrypt(
          _itemKey,
          nonce,
          plaintext,
          itemAad(vaultFormatVersion, id, secret.kind),
        ),
      );
    } finally {
      wipeBytes(plaintext);
    }
    return _core.mutex.run(() async {
      _ensureOpen();
      final file = _core.current!;
      if (file.item(id) != null) {
        return const Err(ValidationFailure('duplicate_item_id'));
      }
      final written = await _core.commit(file.withItem(item), _macKey);
      return written.map((_) => fingerprint);
    });
  }

  @override
  Future<Result<void>> deleteItem(String id) async {
    _ensureOpen();
    return _core.mutex.run(() async {
      _ensureOpen();
      final file = _core.current!;
      if (file.item(id) == null) return const Err(VaultItemNotFoundFailure());
      return _core.commit(file.withoutItem(id), _macKey);
    });
  }

  @override
  String fingerprintOf(VaultItemSecret secret) {
    _ensureOpen();
    final plaintext = ItemCodec.encode(secret);
    try {
      return _fingerprint(plaintext);
    } finally {
      wipeBytes(plaintext);
    }
  }

  String _fingerprint(Uint8List plaintext) => hexOf(
    _core.crypto.keyedHash(_fingerprintKey, plaintext, fingerprintLength),
  );

  @override
  Future<Result<void>> changePassword(Sensitive newPassword) async {
    _ensureOpen();
    if (newPassword.use((b) => b.isEmpty)) {
      return const Err(ValidationFailure('empty_password'));
    }
    final crypto = _core.crypto;
    final params = _core.defaultParams;
    final salt = crypto.randomBytes(saltLength);
    final kek = await crypto.argon2id(newPassword, salt, params);
    final Uint8List nonce;
    final Uint8List wrapped;
    try {
      _ensureOpen();
      nonce = crypto.randomBytes(nonceLength);
      wrapped = crypto.aeadEncrypt(
        kek,
        nonce,
        _vmk,
        vmkWrapAad(vaultFormatVersion),
      );
    } finally {
      wipeBytes(kek);
    }
    return _core.mutex.run(() async {
      _ensureOpen();
      final next = _core.current!.withPasswordWrap(
        salt: salt,
        kdfParams: params,
        wrapNonce: nonce,
        wrapCiphertext: wrapped,
      );
      return _core.commit(next, _macKey);
    });
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    wipeBytes(_vmk);
    wipeBytes(_itemKey);
    wipeBytes(_fingerprintKey);
    wipeBytes(_macKey);
  }
}
