import 'dart:convert';
import 'dart:typed_data';

import 'package:ow_domain/ow_domain.dart';

// 保险库文件格式的常量与关联数据（AAD）的编码。精确定义见 SECURITY_DESIGN 5.1；
// 这是备份互操作与日后兼容的依据，全部集中在本文件，别处不得另行拼接。

/// 文件头 `format` 字段的固定值。
const vaultFormatId = 'onewallet-vault';

/// 本应用写入与能读取的最高格式版本。
const vaultFormatVersion = 1;

/// 条目加密子密钥 `K_item` 的 `crypto_kdf` 上下文（8 字节）。
const itemKeyContext = 'ow_items';

/// 查重指纹子密钥 `K_fp` 的 `crypto_kdf` 上下文（8 字节）。
const fingerprintKeyContext = 'ow_fprnt';

/// 两个子密钥共用的 `crypto_kdf` 子密钥编号（上下文已经区分用途）。
const vaultSubkeyId = 1;

/// 保险库主密钥 VMK 的长度。
const vmkLength = 32;

/// Argon2id salt 的长度。
const saltLength = 16;

/// XChaCha20-Poly1305 nonce 的长度。
const nonceLength = 24;

/// 认证标签的长度。
const tagLength = 16;

/// 查重指纹的长度（BLAKE2b 输出截取 16 字节）。
const fingerprintLength = 16;

/// 条目类型在文件与 AAD 中的写法。
String vaultItemKindName(VaultItemKind kind) => switch (kind) {
  VaultItemKind.mnemonic => 'mnemonic',
  VaultItemKind.privateKey => 'private_key',
};

/// [vaultItemKindName] 的逆映射；无法识别时返回 null。
VaultItemKind? vaultItemKindFromName(String name) => switch (name) {
  'mnemonic' => VaultItemKind.mnemonic,
  'private_key' => VaultItemKind.privateKey,
  _ => null,
};

/// 密码包裹 `wrapped_vmk_pw` 的关联数据：
/// `lp("onewallet-vault") ‖ lp("wrapped_vmk_pw") ‖ u16be(version)`。
///
/// `lp(x)` 为 `u16be(x 的字节数) ‖ x`，字符串按 UTF-8 编码。
Uint8List vmkWrapAad(int version) =>
    _concat([_lp(vaultFormatId), _lp('wrapped_vmk_pw'), _u16(version)]);

/// 条目密文的关联数据：
/// `lp("onewallet-vault") ‖ lp("item") ‖ u16be(version) ‖ lp(id) ‖ lp(kind)`。
///
/// [id] 与 [kind] 写法与文件中的 `id`、`kind` 字段完全相同，所以互换两条密文、
/// 改动条目的 id 或 kind，都会使认证失败。
Uint8List itemAad(int version, String id, VaultItemKind kind) => _concat([
  _lp(vaultFormatId),
  _lp('item'),
  _u16(version),
  _lp(id),
  _lp(vaultItemKindName(kind)),
]);

Uint8List _lp(String value) {
  final bytes = utf8.encode(value);
  if (bytes.length > 0xffff) throw ArgumentError('AAD 字段过长');
  return _concat([_u16(bytes.length), bytes]);
}

Uint8List _u16(int value) {
  if (value < 0 || value > 0xffff) throw ArgumentError.value(value, 'value');
  return Uint8List.fromList([value >> 8, value & 0xff]);
}

Uint8List _concat(List<List<int>> parts) {
  final out = Uint8List(parts.fold(0, (n, p) => n + p.length));
  var offset = 0;
  for (final part in parts) {
    out.setRange(offset, offset + part.length, part);
    offset += part.length;
  }
  return out;
}
