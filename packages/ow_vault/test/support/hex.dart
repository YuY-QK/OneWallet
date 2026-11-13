import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// 十六进制字符串转字节（测试用）。
Uint8List unhex(String hex) {
  if (hex.length.isOdd) throw ArgumentError('奇数长度的十六进制');
  return Uint8List.fromList([
    for (var i = 0; i < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ]);
}

/// 字节转小写十六进制（测试用）。
String tohex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// 读取 test/fixtures 下的 JSON 样本。
Map<String, Object?> readFixture(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync())
        as Map<String, Object?>;

/// 把 JSON 中的对象数组转成类型化的列表。
List<Map<String, Object?>> objects(Object? list) =>
    (list! as List<Object?>).cast<Map<String, Object?>>();
