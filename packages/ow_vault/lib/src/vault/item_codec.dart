import 'dart:typed_data';

import 'package:ow_domain/ow_domain.dart';

import 'vault_item_secret.dart';

/// 条目明文的规范编码（SECURITY_DESIGN 5.1）。
///
/// 明文是一段固定字段顺序、无空白的 JSON，所有密钥内容写成原始字节的小写十六进制：
///
/// ```text
/// {"v":1,"kind":"mnemonic","mnemonic":"<hex>","passphrase":null}
/// {"v":1,"kind":"mnemonic","mnemonic":"<hex>","passphrase":"<hex>"}
/// {"v":1,"kind":"private_key","family":"evm|bitcoin|solana|tron","key":"<hex>"}
/// ```
///
/// 编码与解码都直接在字节上进行，不经过 Dart `String`，因此明文不会以无法清零的
/// 字符串形式留在堆上；中间缓冲由调用方或本类用完清零。解码只接受上述规范形式，
/// 其余一律视为损坏。查重指纹也以这段字节为输入。
abstract final class ItemCodec {
  /// 助记词原文的字节数上限。
  static const maxMnemonicBytes = 1024;

  /// 附加密码的字节数上限。
  static const maxPassphraseBytes = 1024;

  /// 私钥的字节数上限。
  static const maxPrivateKeyBytes = 256;

  /// [secret] 不合法时返回原因标记（写入 `ValidationFailure.detail`），合法返回 null。
  ///
  /// 规则：助记词与私钥不能为空，各字段不超过上限；附加密码可以为空字节串。
  static String? invalidReason(VaultItemSecret secret) => switch (secret) {
    MnemonicSecret(:final mnemonic, :final passphrase) =>
      _lengthOf(mnemonic) == 0 || _lengthOf(mnemonic) > maxMnemonicBytes
          ? 'mnemonic_length'
          : passphrase != null && _lengthOf(passphrase) > maxPassphraseBytes
          ? 'passphrase_length'
          : null,
    PrivateKeySecret(:final key) =>
      _lengthOf(key) == 0 || _lengthOf(key) > maxPrivateKeyBytes
          ? 'private_key_length'
          : null,
  };

  /// 编码 [secret]。返回的缓冲含明文，调用方用完必须清零。
  ///
  /// [secret] 不合法（见 [invalidReason]）时抛出 [ArgumentError]。
  static Uint8List encode(VaultItemSecret secret) {
    if (invalidReason(secret) != null) {
      throw ArgumentError('保险库条目内容不合法');
    }
    final measure = _Measure();
    _write(secret, measure);
    final writer = _Writer(measure.length);
    _write(secret, writer);
    return writer.buffer;
  }

  /// 解码规范形式的明文。不合法时返回 null。
  ///
  /// 返回对象中的字节是新分配的，归调用方所有；[bytes] 不被修改，由调用方清零。
  static VaultItemSecret? decode(Uint8List bytes) {
    final r = _Reader(bytes);
    if (!r.literal('{"v":1,"kind":"')) return null;
    if (r.literal('mnemonic","mnemonic":"')) return _decodeMnemonic(r);
    if (r.literal('private_key","family":"')) return _decodePrivateKey(r);
    return null;
  }

  static VaultItemSecret? _decodeMnemonic(_Reader r) {
    final mnemonic = r.hexThenQuote(maxMnemonicBytes);
    if (mnemonic == null || mnemonic.isEmpty) return null;
    Uint8List? passphrase;
    var ok = r.literal(',"passphrase":');
    if (ok && !r.literal('null')) {
      ok = r.literal('"');
      passphrase = ok ? r.hexThenQuote(maxPassphraseBytes) : null;
      ok = passphrase != null;
    }
    ok = ok && r.literal('}') && r.atEnd;
    if (!ok) {
      mnemonic.fillRange(0, mnemonic.length, 0);
      passphrase?.fillRange(0, passphrase.length, 0);
      return null;
    }
    return MnemonicSecret(
      mnemonic: Sensitive(mnemonic),
      passphrase: passphrase == null ? null : Sensitive(passphrase),
    );
  }

  static VaultItemSecret? _decodePrivateKey(_Reader r) {
    final family = _familyFromName(r.asciiThenQuote());
    if (family == null || !r.literal(',"key":"')) return null;
    final key = r.hexThenQuote(maxPrivateKeyBytes);
    if (key == null) return null;
    if (key.isEmpty || !(r.literal('}') && r.atEnd)) {
      key.fillRange(0, key.length, 0);
      return null;
    }
    return PrivateKeySecret(family: family, key: Sensitive(key));
  }

  static void _write(VaultItemSecret secret, _Sink out) {
    out.ascii('{"v":1,"kind":"');
    switch (secret) {
      case MnemonicSecret(:final mnemonic, :final passphrase):
        out.ascii('mnemonic","mnemonic":"');
        mnemonic.use(out.hex);
        out.ascii('","passphrase":');
        if (passphrase == null) {
          out.ascii('null');
        } else {
          out.ascii('"');
          passphrase.use(out.hex);
          out.ascii('"');
        }
      case PrivateKeySecret(:final family, :final key):
        out.ascii('private_key","family":"');
        out.ascii(_familyName(family));
        out.ascii('","key":"');
        key.use(out.hex);
        out.ascii('"');
    }
    out.ascii('}');
  }

  static int _lengthOf(Sensitive value) => value.use((b) => b.length);

  static String _familyName(ChainFamily family) => switch (family) {
    ChainFamily.evm => 'evm',
    ChainFamily.bitcoin => 'bitcoin',
    ChainFamily.solana => 'solana',
    ChainFamily.tron => 'tron',
  };

  static ChainFamily? _familyFromName(String? name) => switch (name) {
    'evm' => ChainFamily.evm,
    'bitcoin' => ChainFamily.bitcoin,
    'solana' => ChainFamily.solana,
    'tron' => ChainFamily.tron,
    _ => null,
  };
}

/// 编码的输出端：先用 [_Measure] 算出长度，再用 [_Writer] 一次写入定长缓冲，
/// 避免可增长缓冲在扩容时留下无法清零的旧副本。
sealed class _Sink {
  void ascii(String literal);
  void hex(Uint8List bytes);
}

final class _Measure extends _Sink {
  int length = 0;

  @override
  void ascii(String literal) => length += literal.length;

  @override
  void hex(Uint8List bytes) => length += bytes.length * 2;
}

final class _Writer extends _Sink {
  _Writer(int length) : buffer = Uint8List(length);

  final Uint8List buffer;
  var _pos = 0;

  static const _digits = '0123456789abcdef';

  @override
  void ascii(String literal) {
    for (final c in literal.codeUnits) {
      buffer[_pos++] = c;
    }
  }

  @override
  void hex(Uint8List bytes) {
    for (final b in bytes) {
      buffer[_pos++] = _digits.codeUnitAt(b >> 4);
      buffer[_pos++] = _digits.codeUnitAt(b & 0x0f);
    }
  }
}

final class _Reader {
  _Reader(this._buf);

  final Uint8List _buf;
  var _pos = 0;

  static const _quote = 0x22;

  bool get atEnd => _pos == _buf.length;

  /// 当前位置是否正好是 [s]（ASCII）；是则越过它。
  bool literal(String s) {
    if (_pos + s.length > _buf.length) return false;
    for (var i = 0; i < s.length; i++) {
      if (_buf[_pos + i] != s.codeUnitAt(i)) return false;
    }
    _pos += s.length;
    return true;
  }

  /// 读取小写十六进制直到 `"`（并越过它），解码为新缓冲。
  ///
  /// 不是偶数个小写十六进制字符或超过 [maxBytes] 字节时返回 null。
  Uint8List? hexThenQuote(int maxBytes) {
    final end = _indexOfQuote();
    if (end < 0) return null;
    final digits = end - _pos;
    if (digits.isOdd || digits ~/ 2 > maxBytes) return null;
    final out = Uint8List(digits ~/ 2);
    for (var i = 0; i < out.length; i++) {
      final hi = _nibble(_buf[_pos + 2 * i]);
      final lo = _nibble(_buf[_pos + 2 * i + 1]);
      if (hi < 0 || lo < 0) {
        out.fillRange(0, out.length, 0);
        return null;
      }
      out[i] = hi << 4 | lo;
    }
    _pos = end + 1;
    return out;
  }

  /// 读取由小写字母组成的短标记直到 `"`（并越过它）。只用于非敏感的链家族名。
  String? asciiThenQuote() {
    final end = _indexOfQuote();
    if (end < 0 || end - _pos > 16) return null;
    final token = _buf.sublist(_pos, end);
    if (token.any((c) => c < 0x61 || c > 0x7a)) return null;
    _pos = end + 1;
    return String.fromCharCodes(token);
  }

  int _indexOfQuote() {
    for (var i = _pos; i < _buf.length; i++) {
      if (_buf[i] == _quote) return i;
    }
    return -1;
  }

  static int _nibble(int c) => c >= 0x30 && c <= 0x39
      ? c - 0x30
      : c >= 0x61 && c <= 0x66
      ? c - 0x61 + 10
      : -1;
}
