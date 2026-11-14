import 'dart:convert';
import 'dart:typed_data';

import 'utf8_bytes.dart';

export 'utf8_bytes.dart';

// 直接在 UTF-8 字节上读写 JSON，供备份载荷使用（SECURITY_DESIGN 6.5）。
//
// 载荷里有助记词、私钥等密钥内容。用 `dart:convert` 的 jsonDecode/jsonEncode 会把
// 它们变成无法清零的 Dart `String`；这里的解析器把每个 JSON 字符串保存为字节
// （[JsonString.bytes]），由调用方决定哪些字段转成 `String`（非敏感字段）、哪些
// 复制进 `Sensitive`，用完调用 [JsonNode.wipe] 清零整棵树。写入端同样先量长度再
// 一次写入定长缓冲，避免可增长缓冲扩容时留下旧副本。

/// 解析结果的节点。
sealed class JsonNode {
  const JsonNode();

  /// 清零本节点及其子节点里的字符串字节。可重复调用。
  void wipe() {}
}

/// JSON 对象。键是非敏感的字段名，已解码为 `String`；不允许重复的键。
final class JsonObject extends JsonNode {
  JsonObject(this.fields);

  final Map<String, JsonNode> fields;

  JsonNode? operator [](String key) => fields[key];

  @override
  void wipe() {
    for (final value in fields.values) {
      value.wipe();
    }
  }
}

/// JSON 数组。
final class JsonArray extends JsonNode {
  JsonArray(this.items);

  final List<JsonNode> items;

  @override
  void wipe() {
    for (final item in items) {
      item.wipe();
    }
  }
}

/// JSON 字符串，以转义还原后的 UTF-8 字节持有（已校验为合法 UTF-8）。
final class JsonString extends JsonNode {
  JsonString(this.bytes);

  final Uint8List bytes;

  /// 解码为 `String`。只能用于非敏感字段。
  String get text => utf8.decode(bytes);

  @override
  void wipe() => bytes.fillRange(0, bytes.length, 0);
}

/// JSON 数字，保留原文（本格式只用到整数）。
final class JsonNumber extends JsonNode {
  const JsonNumber(this.literal);

  final String literal;

  /// 原文是不带小数与指数的整数且绝对值不超过 2^53 时返回其值，否则 null。
  int? get asInt {
    if (literal.contains(RegExp('[.eE]'))) return null;
    final value = int.tryParse(literal);
    const limit = 1 << 53;
    return value != null && value <= limit && value >= -limit ? value : null;
  }
}

/// `true` 或 `false`。
final class JsonBool extends JsonNode {
  const JsonBool(this.value);

  final bool value;
}

/// `null`。
final class JsonNull extends JsonNode {
  const JsonNull();
}

/// 严格的 JSON 解析器（RFC 8259），输入为 UTF-8 字节。
///
/// 不接受：BOM、重复的键、未转义的控制字符、孤立的代理项转义、顶层值之后的
/// 多余内容、超过 [maxDepth] 层的嵌套。任何不合法都返回 null，失败时已分配的
/// 字符串字节被清零。
abstract final class JsonBytes {
  /// 最大嵌套层数。
  static const maxDepth = 32;

  /// 解析 [input]。[input] 不被修改，由调用方清零。
  static JsonNode? parse(Uint8List input) {
    final parser = _Parser(input);
    try {
      final node = parser.value(0);
      parser.skipWhitespace();
      if (!parser.atEnd) {
        node.wipe();
        return null;
      }
      return node;
    } on _Invalid {
      parser.wipeAll();
      return null;
    }
  }
}

final class _Invalid implements Exception {
  const _Invalid();
}

final class _Parser {
  _Parser(this._b);

  final Uint8List _b;
  var _pos = 0;

  /// 已分配的全部字符串，失败时统一清零。
  final _strings = <JsonString>[];

  bool get atEnd => _pos == _b.length;

  void wipeAll() {
    for (final s in _strings) {
      s.wipe();
    }
  }

  Never _fail() => throw const _Invalid();

  void skipWhitespace() {
    while (_pos < _b.length) {
      final c = _b[_pos];
      if (c != 0x20 && c != 0x09 && c != 0x0a && c != 0x0d) return;
      _pos++;
    }
  }

  int _peek() => _pos < _b.length ? _b[_pos] : _fail();

  void _expect(String literal) {
    for (final c in literal.codeUnits) {
      if (_pos >= _b.length || _b[_pos] != c) _fail();
      _pos++;
    }
  }

  JsonNode value(int depth) {
    if (depth > JsonBytes.maxDepth) _fail();
    skipWhitespace();
    return switch (_peek()) {
      0x7b => _object(depth),
      0x5b => _array(depth),
      0x22 => _string(),
      0x74 => _literal('true', const JsonBool(true)),
      0x66 => _literal('false', const JsonBool(false)),
      0x6e => _literal('null', const JsonNull()),
      _ => _number(),
    };
  }

  JsonNode _literal(String text, JsonNode node) {
    _expect(text);
    return node;
  }

  JsonObject _object(int depth) {
    _pos++;
    final fields = <String, JsonNode>{};
    skipWhitespace();
    if (_peek() == 0x7d) {
      _pos++;
      return JsonObject(fields);
    }
    while (true) {
      skipWhitespace();
      if (_peek() != 0x22) _fail();
      final key = _string();
      final name = key.text;
      skipWhitespace();
      _expect(':');
      final item = value(depth + 1);
      if (fields.containsKey(name)) _fail();
      fields[name] = item;
      skipWhitespace();
      final c = _peek();
      _pos++;
      if (c == 0x7d) return JsonObject(fields);
      if (c != 0x2c) _fail();
    }
  }

  JsonArray _array(int depth) {
    _pos++;
    final items = <JsonNode>[];
    skipWhitespace();
    if (_peek() == 0x5d) {
      _pos++;
      return JsonArray(items);
    }
    while (true) {
      items.add(value(depth + 1));
      skipWhitespace();
      final c = _peek();
      _pos++;
      if (c == 0x5d) return JsonArray(items);
      if (c != 0x2c) _fail();
    }
  }

  JsonNumber _number() {
    final start = _pos;
    if (_pos < _b.length && _b[_pos] == 0x2d) _pos++;
    if (_peek() == 0x30) {
      _pos++;
    } else {
      _digits();
    }
    if (_pos < _b.length && _b[_pos] == 0x2e) {
      _pos++;
      _digits();
    }
    if (_pos < _b.length && (_b[_pos] == 0x65 || _b[_pos] == 0x45)) {
      _pos++;
      if (_pos < _b.length && (_b[_pos] == 0x2b || _b[_pos] == 0x2d)) _pos++;
      _digits();
    }
    return JsonNumber(String.fromCharCodes(_b, start, _pos));
  }

  void _digits() {
    final start = _pos;
    while (_pos < _b.length && _b[_pos] >= 0x30 && _b[_pos] <= 0x39) {
      _pos++;
    }
    if (_pos == start) _fail();
  }

  /// 读取一个字符串（当前位置是 `"`）。还原后的字节不会比原文长，
  /// 所以先分配原文长度的缓冲，写完再复制成精确长度并清零临时缓冲。
  JsonString _string() {
    _pos++;
    final end = _closingQuote();
    final tmp = Uint8List(end - _pos);
    var n = 0;
    try {
      while (_pos < end) {
        final c = _b[_pos];
        if (c == 0x5c) {
          n = _escape(tmp, n);
        } else if (c < 0x20) {
          _fail();
        } else {
          final len = utf8SequenceLength(_b, _pos);
          if (len == 0 || _pos + len > end) _fail();
          tmp.setRange(n, n + len, _b, _pos);
          n += len;
          _pos += len;
        }
      }
      _pos = end + 1;
      final out = JsonString(
        Uint8List.fromList(Uint8List.sublistView(tmp, 0, n)),
      );
      _strings.add(out);
      return out;
    } finally {
      tmp.fillRange(0, tmp.length, 0);
    }
  }

  /// 收尾引号的位置（跳过 `\` 转义的字符）。
  int _closingQuote() {
    var i = _pos;
    while (i < _b.length) {
      final c = _b[i];
      if (c == 0x22) return i;
      i += c == 0x5c ? 2 : 1;
    }
    _fail();
  }

  int _escape(Uint8List out, int n) {
    if (_pos + 1 >= _b.length) _fail();
    final c = _b[_pos + 1];
    _pos += 2;
    final simple = switch (c) {
      0x22 => 0x22,
      0x5c => 0x5c,
      0x2f => 0x2f,
      0x62 => 0x08,
      0x66 => 0x0c,
      0x6e => 0x0a,
      0x72 => 0x0d,
      0x74 => 0x09,
      _ => -1,
    };
    if (simple >= 0) {
      out[n] = simple;
      return n + 1;
    }
    if (c != 0x75) _fail();
    var cp = _hex4();
    if (cp >= 0xdc00 && cp <= 0xdfff) _fail();
    if (cp >= 0xd800 && cp <= 0xdbff) {
      _expect(r'\u');
      final low = _hex4();
      if (low < 0xdc00 || low > 0xdfff) _fail();
      cp = 0x10000 + ((cp - 0xd800) << 10) + (low - 0xdc00);
    }
    return _writeCodePoint(out, n, cp);
  }

  int _hex4() {
    if (_pos + 4 > _b.length) _fail();
    var v = 0;
    for (var k = 0; k < 4; k++) {
      final c = _b[_pos + k];
      final d = c >= 0x30 && c <= 0x39
          ? c - 0x30
          : c >= 0x61 && c <= 0x66
          ? c - 0x57
          : c >= 0x41 && c <= 0x46
          ? c - 0x37
          : _fail();
      v = v << 4 | d;
    }
    _pos += 4;
    return v;
  }

  static int _writeCodePoint(Uint8List out, int n, int cp) {
    if (cp < 0x80) {
      out[n] = cp;
      return n + 1;
    }
    if (cp < 0x800) {
      out[n] = 0xc0 | cp >> 6;
      out[n + 1] = 0x80 | cp & 0x3f;
      return n + 2;
    }
    if (cp < 0x10000) {
      out[n] = 0xe0 | cp >> 12;
      out[n + 1] = 0x80 | cp >> 6 & 0x3f;
      out[n + 2] = 0x80 | cp & 0x3f;
      return n + 3;
    }
    out[n] = 0xf0 | cp >> 18;
    out[n + 1] = 0x80 | cp >> 12 & 0x3f;
    out[n + 2] = 0x80 | cp >> 6 & 0x3f;
    out[n + 3] = 0x80 | cp & 0x3f;
    return n + 4;
  }
}
