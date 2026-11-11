import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:ow_domain/ow_domain.dart';

/// 某一行无法还原为领域对象（未知的枚举名、未知链 id、损坏的数字或 JSON 等）。
///
/// **读取约定**：列表类读取（`watchAll`、`byAccount`、`range` 等）会**跳过**这样的行，
/// 不崩溃也不影响其他行；按键读取（`byId`、`find` 等）把它当作"没有这一行"返回 null。
/// 这样旧版本应用读到新版本写入的数据（例如新增的链）时仍能正常运行。
/// 本异常不会越过仓储的公开方法。
final class RowDecodeException implements Exception {
  const RowDecodeException(this.message);

  final String message;

  @override
  String toString() => 'RowDecodeException($message)';
}

/// 逐行解码，跳过无法解码的行（见 [RowDecodeException]）。
List<T> decodeRows<R, T>(Iterable<R> rows, T Function(R row) decode) {
  final result = <T>[];
  for (final row in rows) {
    final value = tryDecode(row, decode);
    if (value != null) result.add(value);
  }
  return result;
}

/// 解码单行，无法解码时返回 null。
T? tryDecode<R, T>(R row, T Function(R row) decode) {
  try {
    return decode(row);
  } on RowDecodeException {
    return null;
  }
}

/// 金额、数量、价格存为文本：`Decimal.toString()` 是不带指数的十进制文本，往返无损。
String encodeDecimal(Decimal value) => value.toString();

/// 还原 [encodeDecimal] 的结果；文本损坏时抛出 [RowDecodeException]。
Decimal decodeDecimal(String text) {
  final value = Decimal.tryParse(text);
  if (value == null) throw const RowDecodeException('金额文本无法解析');
  return value;
}

/// 按名称还原枚举；名称未知时抛出 [RowDecodeException]。
T decodeEnum<T extends Enum>(List<T> values, String name, String what) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  throw RowDecodeException('未知的$what：$name');
}

/// 可空列的 [decodeEnum]。
T? decodeEnumOrNull<T extends Enum>(
  List<T> values,
  String? name,
  String what,
) => name == null ? null : decodeEnum(values, name, what);

/// 校验链 id 是内置链；未知时抛出 [RowDecodeException]。
String checkChainId(String? id) {
  if (id == null || Chains.tryById(id) == null) {
    throw RowDecodeException('未知的链 id：$id');
  }
  return id;
}

/// 取出非空列；为空说明行已损坏。
T requireValue<T extends Object>(T? value, String column) {
  if (value == null) throw RowDecodeException('列 $column 不应为空');
  return value;
}

/// 链 id 集合与 JSON 数组文本互转（`addresses.enabled_chain_ids`）。
String encodeStringSet(Set<String> values) =>
    jsonEncode((values.toList()..sort()));

/// 还原 [encodeStringSet] 的结果；JSON 损坏时抛出 [RowDecodeException]。
Set<String> decodeStringSet(String text) {
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException {
    throw const RowDecodeException('JSON 数组损坏');
  }
  if (decoded is! List<Object?> || decoded.any((e) => e is! String)) {
    throw const RowDecodeException('JSON 数组内容不是字符串');
  }
  return decoded.cast<String>().toSet();
}
