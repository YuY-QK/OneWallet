import 'dart:convert';
import 'dart:typed_data';

import 'package:ow_domain/ow_domain.dart';

import '../crypto/vault_crypto.dart';
import 'vault_format.dart';

/// 文件中的一条密文条目。只含密文与公开字段。
final class VaultFileItem {
  const VaultFileItem({
    required this.id,
    required this.kind,
    required this.nonce,
    required this.ciphertext,
  });

  final String id;
  final VaultItemKind kind;
  final Uint8List nonce;
  final Uint8List ciphertext;
}

/// 保险库文件 `vault.owv` 的内存模型（SECURITY_DESIGN 5.1）。不可变。
///
/// 只包含公开数据与密文，所以可以用 `dart:convert` 的 JSON 编解码。
final class VaultFile {
  const VaultFile({
    required this.version,
    required this.salt,
    required this.kdfParams,
    required this.wrapNonce,
    required this.wrapCiphertext,
    required this.items,
  });

  final int version;
  final Uint8List salt;
  final KdfParams kdfParams;
  final Uint8List wrapNonce;
  final Uint8List wrapCiphertext;
  final List<VaultFileItem> items;

  /// 合法条目 id：1–64 个 ASCII 字母、数字、`-`、`_`（UUID 符合）。
  static final itemIdPattern = RegExp(r'^[0-9A-Za-z_-]{1,64}$');

  /// 按 id 查找条目。
  VaultFileItem? item(String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  /// 追加一条后的新文件。
  VaultFile withItem(VaultFileItem item) => _copy(items: [...items, item]);

  /// 去掉 [id] 后的新文件。
  VaultFile withoutItem(String id) => _copy(
    items: [
      for (final i in items)
        if (i.id != id) i,
    ],
  );

  /// 换成新的密码包裹（改密码）。条目不变。
  VaultFile withPasswordWrap({
    required Uint8List salt,
    required KdfParams kdfParams,
    required Uint8List wrapNonce,
    required Uint8List wrapCiphertext,
  }) => VaultFile(
    version: version,
    salt: salt,
    kdfParams: kdfParams,
    wrapNonce: wrapNonce,
    wrapCiphertext: wrapCiphertext,
    items: items,
  );

  VaultFile _copy({required List<VaultFileItem> items}) => VaultFile(
    version: version,
    salt: salt,
    kdfParams: kdfParams,
    wrapNonce: wrapNonce,
    wrapCiphertext: wrapCiphertext,
    items: List.unmodifiable(items),
  );

  /// 序列化为 UTF-8 JSON，字段顺序固定。
  Uint8List encode() => utf8.encode(
    jsonEncode({
      'format': vaultFormatId,
      'version': version,
      'kdf': {
        'alg': 'argon2id',
        'salt': base64.encode(salt),
        'mem_kib': kdfParams.memKib,
        'iters': kdfParams.iterations,
        'parallelism': kdfParams.parallelism,
      },
      'wrapped_vmk_pw': {
        'nonce': base64.encode(wrapNonce),
        'ct': base64.encode(wrapCiphertext),
      },
      'items': [
        for (final item in items)
          {
            'id': item.id,
            'kind': vaultItemKindName(item.kind),
            'nonce': base64.encode(item.nonce),
            'ct': base64.encode(item.ciphertext),
          },
      ],
    }),
  );

  /// 解析文件内容。
  ///
  /// - 不是 UTF-8 JSON 对象、`format` 不对、结构或字段不合法 → `VaultCorruptedFailure`；
  /// - `version` 高于 [vaultFormatVersion] → `VaultVersionUnsupportedFailure`
  ///   （在检查其余结构之前判断，因为新版本的结构可能不同）。
  ///
  /// 只校验结构；密文是否被篡改由解密时的认证发现。`detail` 只含固定的原因标记。
  static Result<VaultFile> decode(Uint8List bytes) {
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      return const Err(VaultCorruptedFailure('not_json'));
    }
    if (json is! Map<String, Object?>) {
      return const Err(VaultCorruptedFailure('not_object'));
    }
    if (json['format'] != vaultFormatId) {
      return const Err(VaultCorruptedFailure('format'));
    }
    final version = json['version'];
    if (version is! int || version < 1) {
      return const Err(VaultCorruptedFailure('version'));
    }
    if (version > vaultFormatVersion) {
      return Err(VaultVersionUnsupportedFailure('version_$version'));
    }
    final file = _decodeV1(json, version);
    return file == null
        ? const Err(VaultCorruptedFailure('structure'))
        : Ok(file);
  }

  static VaultFile? _decodeV1(Map<String, Object?> json, int version) {
    if (!_exactKeys(json, const {
      'format',
      'version',
      'kdf',
      'wrapped_vmk_pw',
      'items',
    })) {
      return null;
    }
    final kdf = json['kdf'];
    final wrap = json['wrapped_vmk_pw'];
    final items = json['items'];
    if (kdf is! Map<String, Object?> ||
        wrap is! Map<String, Object?> ||
        items is! List<Object?>) {
      return null;
    }
    final params = _decodeKdf(kdf);
    final salt = params == null ? null : _b64(kdf['salt'], saltLength);
    if (params == null || salt == null) return null;
    if (!_exactKeys(wrap, const {'nonce', 'ct'})) return null;
    final wrapNonce = _b64(wrap['nonce'], nonceLength);
    final wrapCt = _b64(wrap['ct'], vmkLength + tagLength);
    final decodedItems = _decodeItems(items);
    if (wrapNonce == null || wrapCt == null || decodedItems == null) {
      return null;
    }
    return VaultFile(
      version: version,
      salt: salt,
      kdfParams: params,
      wrapNonce: wrapNonce,
      wrapCiphertext: wrapCt,
      items: List.unmodifiable(decodedItems),
    );
  }

  static KdfParams? _decodeKdf(Map<String, Object?> kdf) {
    if (!_exactKeys(kdf, const {
      'alg',
      'salt',
      'mem_kib',
      'iters',
      'parallelism',
    })) {
      return null;
    }
    final memKib = kdf['mem_kib'];
    final iters = kdf['iters'];
    final parallelism = kdf['parallelism'];
    if (kdf['alg'] != 'argon2id' ||
        memKib is! int ||
        iters is! int ||
        parallelism is! int ||
        !KdfParams.isValid(
          memKib: memKib,
          iterations: iters,
          parallelism: parallelism,
        )) {
      return null;
    }
    return KdfParams(
      memKib: memKib,
      iterations: iters,
      parallelism: parallelism,
    );
  }

  static List<VaultFileItem>? _decodeItems(List<Object?> raw) {
    final seen = <String>{};
    final out = <VaultFileItem>[];
    for (final entry in raw) {
      if (entry is! Map<String, Object?> ||
          !_exactKeys(entry, const {'id', 'kind', 'nonce', 'ct'})) {
        return null;
      }
      final id = entry['id'];
      final kindName = entry['kind'];
      final kind = kindName is String ? vaultItemKindFromName(kindName) : null;
      final nonce = _b64(entry['nonce'], nonceLength);
      final ct = _b64(entry['ct'], null);
      if (id is! String ||
          !itemIdPattern.hasMatch(id) ||
          !seen.add(id) ||
          kind == null ||
          nonce == null ||
          ct == null ||
          ct.length <= tagLength) {
        return null;
      }
      out.add(VaultFileItem(id: id, kind: kind, nonce: nonce, ciphertext: ct));
    }
    return out;
  }

  static bool _exactKeys(Map<String, Object?> map, Set<String> keys) =>
      map.length == keys.length && map.keys.every(keys.contains);

  /// 严格的标准 Base64（带填充）：重新编码必须与原文一致，长度符合 [length]。
  static Uint8List? _b64(Object? value, int? length) {
    if (value is! String) return null;
    final Uint8List bytes;
    try {
      bytes = base64.decode(value);
    } on FormatException {
      return null;
    }
    if (base64.encode(bytes) != value) return null;
    if (length != null && bytes.length != length) return null;
    return bytes;
  }
}
