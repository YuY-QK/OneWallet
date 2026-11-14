import 'dart:convert';
import 'dart:typed_data';

import 'package:ow_vault/src/backup/json_bytes.dart';
import 'package:ow_vault/src/backup/json_writer.dart';
import 'package:test/test.dart';

/// 字节上的 JSON 解析器与写入器。
void main() {
  JsonNode? parse(String text) => JsonBytes.parse(utf8.encode(text));
  JsonNode? parseBytes(List<int> bytes) =>
      JsonBytes.parse(Uint8List.fromList(bytes));

  /// 把解析结果转成普通的 Dart 值，便于与 jsonDecode 比较。
  Object? plain(JsonNode node) => switch (node) {
    JsonObject(:final fields) => {
      for (final e in fields.entries) e.key: plain(e.value),
    },
    JsonArray(:final items) => [for (final i in items) plain(i)],
    JsonString() => node.text,
    JsonNumber(:final literal) => num.parse(literal),
    JsonBool(:final value) => value,
    JsonNull() => null,
  };

  group('解析', () {
    test('合法JSON_与jsonDecode结果一致', () {
      for (final text in [
        '{}',
        '[]',
        ' { "a" : [ 1 , -2.5e3 , 0 , 1E+2, 3e-1 ] , "b" : { } } ',
        '"x"',
        'true',
        'false',
        'null',
        '-0',
        r'"\"\\\/\b\f\n\r\té中😀"',
        '"中文 😀"',
        '{"a":{"b":{"c":[[[]]]}}}',
      ]) {
        final node = parse(text);
        expect(node, isNotNull, reason: text);
        expect(plain(node!), jsonDecode(text), reason: text);
      }
    });

    test('不合法JSON_返回null', () {
      for (final text in [
        '',
        ' ',
        '{',
        '{"a"}',
        '{"a":1,}',
        '[1,]',
        '[1 2]',
        '{"a":1 "b":2}',
        '{1:2}',
        '01',
        '1.',
        '.5',
        '-',
        '1e',
        '+1',
        'tru',
        'nul',
        '"abc',
        '"\\x"',
        '"\\u12"',
        '"\\u12g4"',
        r'"\ud800"',
        r'"\udc00"',
        r'"\ud800A"',
        r'"\ud800x"',
        '"\t"',
        '{"a":1}{}',
        '{"a":1,"a":2}',
        '\u{feff}{}',
        '"\\',
      ]) {
        expect(parse(text), isNull, reason: text);
      }
    });

    test('非UTF-8与过长编码、代理区、超范围码点_返回null', () {
      for (final bytes in [
        [0x22, 0xff, 0x22],
        [0x22, 0xc0, 0xaf, 0x22],
        [0x22, 0xe0, 0x80, 0xaf, 0x22],
        [0x22, 0xed, 0xa0, 0x80, 0x22],
        [0x22, 0xf4, 0x90, 0x80, 0x80, 0x22],
        [0x22, 0xe4, 0xb8, 0x22],
        [0x22, 0xc3],
      ]) {
        expect(parseBytes(bytes), isNull, reason: '$bytes');
      }
    });

    test('嵌套过深_返回null', () {
      expect(parse('${'[' * 32}${']' * 32}'), isNotNull);
      expect(parse('${'[' * 34}${']' * 34}'), isNull);
    });

    test('字符串以字节持有_wipe后清零', () {
      final node = parse('{"k":["secret"]}')! as JsonObject;
      final s = (node['k']! as JsonArray).items.single as JsonString;
      expect(utf8.decode(s.bytes), 'secret');
      node.wipe();
      expect(s.bytes, everyElement(0));
    });

    test('JsonNumber.asInt_只接受范围内的整数', () {
      expect(const JsonNumber('42').asInt, 42);
      expect(const JsonNumber('-7').asInt, -7);
      expect(const JsonNumber('1.0').asInt, isNull);
      expect(const JsonNumber('1e2').asInt, isNull);
      expect(const JsonNumber('9007199254740993').asInt, isNull);
      expect(const JsonNumber('99999999999999999999').asInt, isNull);
    });
  });

  group('UTF-8校验', () {
    test('isValidUtf8', () {
      expect(isValidUtf8(utf8.encode('a中😀')), isTrue);
      expect(isValidUtf8(Uint8List.fromList([0xf0, 0x9f, 0x98])), isFalse);
      expect(isValidUtf8(Uint8List.fromList([0x80])), isFalse);
      expect(
        isValidUtf8(Uint8List.fromList([0xf8, 0x80, 0x80, 0x80])),
        isFalse,
      );
    });
  });

  group('写入', () {
    test('结构与转义_可被jsonDecode还原', () {
      final out = JsonWriter.build((w) {
        w.object(() {
          w.field('s');
          w.string('引号"与\\与\n');
          w.field('n');
          w.integerOrNull(null);
          w.field('i');
          w.integer(-3);
          w.field('b');
          w.boolean(false);
          w.field('arr');
          w.array([1, 2], w.integer);
          w.field('t');
          w.secretText(Uint8List.fromList(utf8.encode('a"b\\c 中')));
          w.field('h');
          w.secretHex(Uint8List.fromList([0, 0xab, 0xff]));
          w.field('e');
          w.object(() {});
        });
      });
      expect(jsonDecode(utf8.decode(out)), {
        's': '引号"与\\与\n',
        'n': null,
        'i': -3,
        'b': false,
        'arr': [1, 2],
        't': 'a"b\\c 中',
        'h': '00abff',
        'e': <String, Object?>{},
      });
    });

    test('secretText_不能写成文本的内容抛出ArgumentError', () {
      expect(
        () => JsonWriter.build(
          (w) => w.secretText(Uint8List.fromList([0x61, 0x0a])),
        ),
        throwsArgumentError,
      );
    });

    test('两遍写入不一致_抛出StateError', () {
      var n = 0;
      expect(
        () => JsonWriter.build((w) => w.integer(n++ == 0 ? 1 : 100)),
        throwsStateError,
      );
      var m = 0;
      expect(
        () => JsonWriter.build((w) => w.integer(m++ == 0 ? 100 : 1)),
        throwsStateError,
      );
    });

    test('isPlainText', () {
      bool plain(List<int> b, {bool ascii = false}) =>
          JsonWriter.isPlainText(Uint8List.fromList(b), asciiOnly: ascii);
      expect(plain(utf8.encode('abandon about')), isTrue);
      expect(plain(utf8.encode('中文')), isTrue);
      expect(plain(utf8.encode('中文'), ascii: true), isFalse);
      expect(plain([0x61, 0x7f]), isFalse);
      expect(plain([0x61, 0x1f]), isFalse);
      expect(plain([0xc2, 0x85]), isFalse);
      expect(plain([0xc2, 0xa0]), isTrue);
      expect(plain([0xff]), isFalse);
      expect(plain([]), isTrue);
    });
  });
}
