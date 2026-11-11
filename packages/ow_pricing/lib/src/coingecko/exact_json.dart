import 'package:decimal/decimal.dart';

/// JSON 数字的原文。
///
/// `dart:convert` 的 `jsonDecode` 会把带小数点的数字解析成 `double`，
/// 价格在这一步就已经丢失了十进制原文（例如 `0.1 + 0.2` 类误差、17 位有效数字被截断）。
/// 本包用 [parseJsonExact] 解析 CoinGecko 的响应，让数字保留原文，再直接构造 `Decimal`。
final class JsonNumber {
  const JsonNumber(this.text);

  /// 响应中数字的原文，如 `67187.3358936566`、`1.2e-7`。
  final String text;

  @override
  String toString() => text;
}

/// 解析 JSON，除数字外与 `jsonDecode` 的结果结构相同：
/// 对象为 `Map<String, Object?>`，数组为 `List<Object?>`，数字为 [JsonNumber]。
///
/// 非法 JSON 抛出 [FormatException]；异常信息不含响应原文。
Object? parseJsonExact(String source) {
  final parser = _ExactJsonParser(source);
  final value = parser.parseDocument();
  return value;
}

/// 把 JSON 值转为 `Decimal`；无法转换（缺失、null、非数字、NaN、无穷）时返回 null。
///
/// - [JsonNumber]：直接用原文构造，不经过 `double`，没有精度损失。
/// - 已经是 `int`：精确转换。
/// - 已经是 `double`（调用方自己用 `jsonDecode` 解码的情形）：二进制浮点数本身已经
///   不是原来的十进制数。这里用 Dart 的最短往返字符串（`double.toString()`）构造，
///   它与原文在 15 位有效数字内一致，不会把二进制展开（如 `0.1` 变成
///   `0.1000000000000000055…`）带进金额。
/// - 数字形式的字符串（CoinGecko 偶尔不会这样返回，但兼容）：按字符串构造。
Decimal? decimalFromJson(Object? value) {
  try {
    return switch (value) {
      JsonNumber(:final text) => _parseDecimal(text),
      int() => Decimal.fromInt(value),
      double() when value.isFinite => _parseDecimal(value.toString()),
      String() => _parseDecimal(value.trim()),
      _ => null,
    };
  } on FormatException {
    return null;
  }
}

/// `Decimal.parse` 不接受指数写法，这里把 `1.2e-7`、`3E+2` 展开为普通小数。
Decimal _parseDecimal(String text) {
  final match = RegExp(r'^(-?)(\d+)(?:\.(\d+))?(?:[eE]([+-]?\d+))?$')
      .firstMatch(text);
  if (match == null) throw FormatException('不是十进制数：$text');
  final sign = match.group(1)!;
  final intPart = match.group(2)!;
  final fraction = match.group(3) ?? '';
  final exponent = int.parse(match.group(4) ?? '0');
  // 指数过大会生成巨大的字符串；价格不会超出这个范围。
  if (exponent.abs() > 40) throw FormatException('指数过大：$text');

  var digits = '$intPart$fraction';
  var pointAt = intPart.length + exponent;
  if (pointAt <= 0) {
    digits = '${'0' * (1 - pointAt)}$digits';
    pointAt = 1;
  } else if (pointAt > digits.length) {
    digits = digits.padRight(pointAt, '0');
  }
  final whole = digits.substring(0, pointAt);
  final frac = digits.substring(pointAt);
  return Decimal.parse('$sign$whole${frac.isEmpty ? '' : '.$frac'}');
}

class _ExactJsonParser {
  _ExactJsonParser(this._s);

  final String _s;
  int _i = 0;
  int _depth = 0;

  static const _maxDepth = 64;

  Object? parseDocument() {
    _skipWs();
    final v = _value();
    _skipWs();
    if (_i != _s.length) _fail('文档末尾有多余内容');
    return v;
  }

  Never _fail(String why) => throw FormatException('JSON 解析失败：$why（位置 $_i）');

  void _skipWs() {
    while (_i < _s.length) {
      final c = _s.codeUnitAt(_i);
      if (c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D) {
        _i++;
      } else {
        break;
      }
    }
  }

  Object? _value() {
    if (_i >= _s.length) _fail('意外结束');
    final c = _s[_i];
    switch (c) {
      case '{':
        return _object();
      case '[':
        return _array();
      case '"':
        return _string();
      case 't':
        _literal('true');
        return true;
      case 'f':
        _literal('false');
        return false;
      case 'n':
        _literal('null');
        return null;
      default:
        return _number();
    }
  }

  void _literal(String word) {
    if (!_s.startsWith(word, _i)) _fail('非法字面量');
    _i += word.length;
  }

  Map<String, Object?> _object() {
    if (++_depth > _maxDepth) _fail('嵌套过深');
    _i++; // {
    final map = <String, Object?>{};
    _skipWs();
    if (_peek('}')) {
      _i++;
      _depth--;
      return map;
    }
    while (true) {
      _skipWs();
      if (!_peek('"')) _fail('缺少键');
      final key = _string();
      _skipWs();
      if (!_peek(':')) _fail('缺少冒号');
      _i++;
      _skipWs();
      map[key] = _value();
      _skipWs();
      if (_peek(',')) {
        _i++;
        continue;
      }
      if (_peek('}')) {
        _i++;
        _depth--;
        return map;
      }
      _fail('对象格式错误');
    }
  }

  List<Object?> _array() {
    if (++_depth > _maxDepth) _fail('嵌套过深');
    _i++; // [
    final list = <Object?>[];
    _skipWs();
    if (_peek(']')) {
      _i++;
      _depth--;
      return list;
    }
    while (true) {
      _skipWs();
      list.add(_value());
      _skipWs();
      if (_peek(',')) {
        _i++;
        continue;
      }
      if (_peek(']')) {
        _i++;
        _depth--;
        return list;
      }
      _fail('数组格式错误');
    }
  }

  bool _peek(String c) => _i < _s.length && _s[_i] == c;

  String _string() {
    _i++; // 开头的引号
    final buf = StringBuffer();
    while (true) {
      if (_i >= _s.length) _fail('字符串未结束');
      final c = _s.codeUnitAt(_i++);
      if (c == 0x22) return buf.toString();
      if (c < 0x20) _fail('字符串含控制字符');
      if (c != 0x5C) {
        buf.writeCharCode(c);
        continue;
      }
      if (_i >= _s.length) _fail('转义不完整');
      final e = _s[_i++];
      switch (e) {
        case '"':
        case '\\':
        case '/':
          buf.write(e);
        case 'b':
          buf.writeCharCode(0x08);
        case 'f':
          buf.writeCharCode(0x0C);
        case 'n':
          buf.writeCharCode(0x0A);
        case 'r':
          buf.writeCharCode(0x0D);
        case 't':
          buf.writeCharCode(0x09);
        case 'u':
          if (_i + 4 > _s.length) _fail('\\u 转义不完整');
          final code = int.tryParse(_s.substring(_i, _i + 4), radix: 16);
          if (code == null) _fail('\\u 转义非法');
          buf.writeCharCode(code);
          _i += 4;
        default:
          _fail('未知转义');
      }
    }
  }

  JsonNumber _number() {
    final start = _i;
    final m = _numberPattern.matchAsPrefix(_s, _i);
    if (m == null) _fail('非法数字或字符');
    _i = m.end;
    return JsonNumber(_s.substring(start, _i));
  }

  static final _numberPattern = RegExp(
    r'-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?',
  );
}
