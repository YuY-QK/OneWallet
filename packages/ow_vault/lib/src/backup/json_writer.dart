import 'dart:convert';
import 'dart:typed_data';

import 'json_bytes.dart';

/// 在字节上写紧凑 JSON（无空白）。见 json_bytes.dart 开头的说明。
///
/// 用 [build] 把同一段写入逻辑执行两遍：第一遍只计长度，第二遍写入恰好大小的
/// 缓冲。密钥内容经 [secretText] 或 [secretHex] 直接从字节写入，不产生 `String`。
final class JsonWriter {
  JsonWriter._(this._buf);

  /// 执行 [write] 两遍得到 JSON 字节。返回的缓冲归调用方，含密钥内容时须清零。
  ///
  /// [write] 必须是确定性的（两遍写出相同内容），否则抛出 [StateError]。
  static Uint8List build(void Function(JsonWriter w) write) {
    final measure = JsonWriter._(null);
    write(measure);
    final out = Uint8List(measure._len);
    final writer = JsonWriter._(out);
    try {
      write(writer);
    } on RangeError {
      out.fillRange(0, out.length, 0);
      throw StateError('两遍写入的长度不一致');
    }
    if (writer._len != out.length) {
      out.fillRange(0, out.length, 0);
      throw StateError('两遍写入的长度不一致');
    }
    return out;
  }

  final Uint8List? _buf;
  var _len = 0;

  /// 每层容器是否还没写过元素（决定是否先写逗号）。
  final _first = <bool>[];

  static const _hexDigits = '0123456789abcdef';

  void _byte(int b) {
    final buf = _buf;
    if (buf != null) buf[_len] = b;
    _len++;
  }

  void _bytes(List<int> bytes) {
    for (final b in bytes) {
      _byte(b);
    }
  }

  void _comma() {
    if (_first.isEmpty) return;
    if (_first.last) {
      _first[_first.length - 1] = false;
    } else {
      _byte(0x2c);
    }
  }

  /// 写一个对象；[body] 里用 [field] 写各字段。
  void object(void Function() body) {
    _byte(0x7b);
    _first.add(true);
    body();
    _first.removeLast();
    _byte(0x7d);
  }

  /// 写一个数组，[each] 写每个元素（每个元素恰好写一个值）。
  void array<T>(Iterable<T> items, void Function(T item) each) {
    _byte(0x5b);
    _first.add(true);
    for (final item in items) {
      _comma();
      each(item);
    }
    _first.removeLast();
    _byte(0x5d);
  }

  /// 写字段名与冒号，之后必须恰好写一个值。
  void field(String name) {
    _comma();
    _bytes(utf8.encode(jsonEncode(name)));
    _byte(0x3a);
  }

  /// 非敏感字符串（经 `jsonEncode` 转义）。
  void string(String value) => _bytes(utf8.encode(jsonEncode(value)));

  /// 可空的非敏感字符串。
  void stringOrNull(String? value) =>
      value == null ? nullValue() : string(value);

  void integer(int value) => _bytes(utf8.encode('$value'));

  void integerOrNull(int? value) =>
      value == null ? nullValue() : integer(value);

  void boolean(bool value) => _bytes(utf8.encode(value ? 'true' : 'false'));

  void nullValue() => _bytes(const [0x6e, 0x75, 0x6c, 0x6c]);

  /// 把合法 UTF-8 的 [bytes] 写成 JSON 字符串：只转义 `"` 与 `\`，其余原样。
  ///
  /// 调用方须先用 [isPlainText] 确认内容可以写成文本，否则抛出 [ArgumentError]。
  void secretText(Uint8List bytes) {
    if (_buf == null && !isPlainText(bytes)) {
      throw ArgumentError('内容不能写成 JSON 文本');
    }
    _byte(0x22);
    for (final b in bytes) {
      if (b == 0x22 || b == 0x5c) _byte(0x5c);
      _byte(b);
    }
    _byte(0x22);
  }

  /// 把 [bytes] 写成带引号的小写十六进制字符串。
  void secretHex(Uint8List bytes) {
    _byte(0x22);
    for (final b in bytes) {
      _byte(_hexDigits.codeUnitAt(b >> 4));
      _byte(_hexDigits.codeUnitAt(b & 0x0f));
    }
    _byte(0x22);
  }

  /// [bytes] 能否以"文本形式"写入载荷：合法 UTF-8，且不含控制字符
  /// （U+0000–U+001F、U+007F–U+009F）。[asciiOnly] 为真时还要求全部是 ASCII。
  ///
  /// 私钥用 [asciiOnly]：各链私钥通行的文本形式（十六进制、WIF、Base58）都是
  /// ASCII，原始二进制私钥偶然构成合法 UTF-8 时不应被当成文本输出。
  static bool isPlainText(Uint8List bytes, {bool asciiOnly = false}) {
    if (!isValidUtf8(bytes)) return false;
    for (var i = 0; i < bytes.length; i++) {
      final b = bytes[i];
      if (b < 0x20 || b == 0x7f) return false;
      if (b >= 0x80 && asciiOnly) return false;
      // U+0080–U+009F 的 UTF-8 编码是 C2 80 – C2 9F。
      if (b == 0xc2 && i + 1 < bytes.length && bytes[i + 1] <= 0x9f) {
        return false;
      }
    }
    return true;
  }
}
