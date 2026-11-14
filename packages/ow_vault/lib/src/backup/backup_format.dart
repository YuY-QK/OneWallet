import 'dart:convert';
import 'dart:typed_data';

import 'package:ow_domain/ow_domain.dart';

import '../crypto/vault_crypto.dart';
import '../vault/vault_format.dart' show nonceLength, saltLength, tagLength;
import 'json_bytes.dart';

// 加密备份文件 `.owbak` 的容器格式。权威定义见 tools/backup_decrypt/FORMAT.md，
// 设计理由见 SECURITY_DESIGN 5.2。
//
//   偏移 0  4 字节  魔数 "OWBK"（4f 57 42 4b）
//   偏移 4  1 字节  容器版本（当前 1）
//   偏移 5  4 字节  头部 JSON 的字节数 L，大端无符号，2 ≤ L ≤ 4096
//   偏移 9  L 字节  头部 JSON（UTF-8）
//   其后    其余全部字节为密文 = XChaCha20-Poly1305-IETF(K, nonce, 载荷, AAD)，含 16 字节标签
//
// AAD = 文件开头到头部 JSON 结束的全部原始字节（9 + L 字节）。

/// 魔数 `OWBK`。
const backupMagic = [0x4f, 0x57, 0x42, 0x4b];

/// 本应用写入与能读取的最高容器版本。
const backupContainerVersion = 1;

/// 定长部分（魔数、版本、头部长度）的字节数。
const backupFixedLength = 9;

/// 头部 JSON 的字节数上限。
const maxHeaderLength = 4096;

/// 载荷 `format` 字段的固定值。
const payloadFormatId = 'onewallet-backup';

/// 本应用写入与能读取的最高载荷版本。
const payloadVersion = 1;

/// 密钥字段写成十六进制时 `encoding` 字段的值。
const hexEncoding = 'hex';

/// 时间的写法：UTC 的 ISO-8601，如 `2026-11-13T08:30:00.000Z`。
String formatTimestamp(DateTime time) => time.toUtc().toIso8601String();

final _timestampPattern = RegExp(
  r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?(Z|[+-]\d{2}:\d{2})$',
);

/// 解析时间：要求带时区（`Z` 或 `±hh:mm`），小数秒最多 6 位，结果转为 UTC。
/// 不合法返回 null。
DateTime? parseTimestamp(String text) {
  if (!_timestampPattern.hasMatch(text)) return null;
  return DateTime.tryParse(text)?.toUtc();
}

/// 备份文件头部中的非敏感信息，[BackupContainer.parse] 与 `peekHeader` 的结果。
final class BackupHeader {
  const BackupHeader({
    required this.containerVersion,
    required this.kdfParams,
    required this.createdAt,
    required this.appVersion,
  });

  final int containerVersion;

  /// 解密需要的 Argon2id 参数（可据此提示"需要多少内存与时间"）。
  final KdfParams kdfParams;

  /// 文件创建时间（UTC）。
  final DateTime createdAt;

  /// 写入此文件的应用版本，只供显示。
  final String appVersion;
}

/// 解析后的容器：头部加密文。[aad] 与 [ciphertext] 是对原文件字节的视图。
final class BackupContainer {
  const BackupContainer._({
    required this.header,
    required this.salt,
    required this.nonce,
    required this.aad,
    required this.ciphertext,
  });

  final BackupHeader header;
  final Uint8List salt;
  final Uint8List nonce;

  /// 文件中魔数到头部 JSON 结束的原始字节（不重新序列化）。
  final Uint8List aad;
  final Uint8List ciphertext;

  /// 解析 [file] 的容器结构，不需要密码，不做任何密码学运算。
  ///
  /// - 魔数不对、版本为 0、头部长度不合法、头部不是合法 JSON 或字段不合法、
  ///   KDF 参数超出 `KdfParams.isValid` 的范围、密文短于标签加 1 字节
  ///   → `BackupCorruptedFailure`；
  /// - 容器版本高于 [backupContainerVersion] → `BackupVersionUnsupportedFailure`
  ///   （在检查其余结构之前判断，因为新版本的结构可能不同）。
  ///
  /// `detail` 只含固定的原因标记。
  static Result<BackupContainer> parse(Uint8List file) {
    if (file.length < backupFixedLength || !_startsWithMagic(file)) {
      return const Err(BackupCorruptedFailure('magic'));
    }
    final version = file[4];
    if (version == 0) return const Err(BackupCorruptedFailure('version'));
    if (version > backupContainerVersion) {
      return Err(BackupVersionUnsupportedFailure('container_$version'));
    }
    final length = ByteData.sublistView(file).getUint32(5);
    if (length < 2 ||
        length > maxHeaderLength ||
        file.length < backupFixedLength + length + tagLength + 1) {
      return const Err(BackupCorruptedFailure('length'));
    }
    final end = backupFixedLength + length;
    final json = JsonBytes.parse(Uint8List.sublistView(file, 9, end));
    final parsed = json is JsonObject ? _header(json, version) : null;
    if (parsed == null) return const Err(BackupCorruptedFailure('header'));
    final (header, salt, nonce) = parsed;
    return Ok(
      BackupContainer._(
        header: header,
        salt: salt,
        nonce: nonce,
        aad: Uint8List.sublistView(file, 0, end),
        ciphertext: Uint8List.sublistView(file, end),
      ),
    );
  }

  static bool _startsWithMagic(Uint8List file) {
    for (var i = 0; i < backupMagic.length; i++) {
      if (file[i] != backupMagic[i]) return false;
    }
    return true;
  }

  static (BackupHeader, Uint8List, Uint8List)? _header(
    JsonObject json,
    int version,
  ) {
    final kdf = json['kdf'];
    if (kdf is! JsonObject || _text(kdf['alg']) != 'argon2id') return null;
    final memKib = _int(kdf['mem_kib']);
    final iters = _int(kdf['iters']);
    final parallelism = _int(kdf['parallelism']);
    if (memKib == null ||
        iters == null ||
        parallelism == null ||
        !KdfParams.isValid(
          memKib: memKib,
          iterations: iters,
          parallelism: parallelism,
        )) {
      return null;
    }
    final salt = _base64(kdf['salt'], saltLength);
    final nonce = _base64(json['nonce'], nonceLength);
    final createdText = _text(json['created_at']);
    final createdAt = createdText == null ? null : parseTimestamp(createdText);
    final appVersion = _text(json['app_version']);
    if (salt == null ||
        nonce == null ||
        createdAt == null ||
        appVersion == null) {
      return null;
    }
    final header = BackupHeader(
      containerVersion: version,
      kdfParams: KdfParams(memKib: memKib, iterations: iters),
      createdAt: createdAt,
      appVersion: appVersion,
    );
    return (header, salt, nonce);
  }

  static String? _text(JsonNode? node) => node is JsonString ? node.text : null;

  static int? _int(JsonNode? node) => node is JsonNumber ? node.asInt : null;

  /// 严格的标准 Base64（带填充）：重新编码须与原文一致，且恰好 [length] 字节。
  static Uint8List? _base64(JsonNode? node, int length) {
    final text = _text(node);
    if (text == null) return null;
    final Uint8List bytes;
    try {
      bytes = base64.decode(text);
    } on FormatException {
      return null;
    }
    return base64.encode(bytes) == text && bytes.length == length
        ? bytes
        : null;
  }
}

/// 写入用的文件开头部分（定长部分加头部 JSON），同时就是加密的 AAD。
///
/// 头部 JSON 紧凑、字段顺序固定。超过 [maxHeaderLength] 字节（[appVersion]
/// 过长）时抛出 [ArgumentError]。
Uint8List encodeBackupPrefix({
  required Uint8List salt,
  required Uint8List nonce,
  required KdfParams params,
  required DateTime createdAt,
  required String appVersion,
}) {
  final header = utf8.encode(
    jsonEncode({
      'kdf': {
        'alg': 'argon2id',
        'salt': base64.encode(salt),
        'mem_kib': params.memKib,
        'iters': params.iterations,
        'parallelism': params.parallelism,
      },
      'nonce': base64.encode(nonce),
      'created_at': formatTimestamp(createdAt),
      'app_version': appVersion,
    }),
  );
  if (header.length > maxHeaderLength) {
    throw ArgumentError('备份文件头部过长');
  }
  final out = Uint8List(backupFixedLength + header.length);
  out.setRange(0, 4, backupMagic);
  out[4] = backupContainerVersion;
  ByteData.sublistView(out).setUint32(5, header.length);
  out.setRange(backupFixedLength, out.length, header);
  return out;
}
