import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:ow_pricing/ow_pricing.dart';
import 'package:test/test.dart';

void main() {
  group('parseJsonExact', () {
    test('结构与 jsonDecode 一致，数字保留原文', () {
      final v = parseJsonExact(
        '{"a":[1,2.50,-3e2,true,false,null,"x\\n\\u0041"],"b":{}}',
      );
      final map = v! as Map<String, Object?>;
      final list = map['a']! as List<Object?>;
      expect((list[0]! as JsonNumber).text, '1');
      expect((list[1]! as JsonNumber).text, '2.50');
      expect((list[2]! as JsonNumber).text, '-3e2');
      expect(list.sublist(3, 6), [true, false, null]);
      expect(list[6], 'x\nA');
      expect(map['b'], isEmpty);
    });

    test('与 jsonDecode 对同一份文档的非数字内容一致', () {
      const text = '{"k":["é","\\ud83d\\ude00",{"n":null}],"s":""}';
      expect(parseJsonExact(text), jsonDecode(text));
    });

    test('非法 JSON 抛出 FormatException，且信息不含原文', () {
      for (final bad in [
        '',
        '{',
        '[1,]',
        '{"a"}',
        '{"a":1,}',
        'nul',
        '01',
        '1.',
        '"abc',
        '{} x',
        '[1 2]',
        '+1',
        '"\\q"',
      ]) {
        expect(() => parseJsonExact(bad), throwsFormatException, reason: bad);
      }
      expect(
        () => parseJsonExact('{"token":"s3cr3t" oops'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            isNot(contains('s3cr3t')),
          ),
        ),
      );
    });

    test('嵌套过深被拒绝', () {
      expect(() => parseJsonExact('[' * 200), throwsFormatException);
    });
  });

  group('decimalFromJson', () {
    Decimal? d(String text) => decimalFromJson(parseJsonExact(text));

    test('用原文构造，不放大二进制误差', () {
      expect(d('0.1'), Decimal.parse('0.1'));
      expect(d('67187.3358936566'), Decimal.parse('67187.3358936566'));
      // 17 位有效数字：double 放不下，原文可以
      expect(d('0.12345678901234567'), Decimal.parse('0.12345678901234567'));
      expect(d('123456789012345678'), Decimal.parse('123456789012345678'));
    });

    test('指数写法', () {
      expect(d('1.2e-7'), Decimal.parse('0.00000012'));
      expect(d('5E-1'), Decimal.parse('0.5'));
      expect(d('1.5e3'), Decimal.parse('1500'));
      expect(d('-2.5E+2'), Decimal.parse('-250'));
      expect(d('0'), Decimal.zero);
      expect(d('1e1000'), isNull);
    });

    test('已经是 double 时用最短往返字符串，而不是二进制展开', () {
      expect(decimalFromJson(0.1), Decimal.parse('0.1'));
      expect(decimalFromJson(1.5e-7), Decimal.parse('0.00000015'));
      expect(decimalFromJson(67187.33), Decimal.parse('67187.33'));
      expect(decimalFromJson(double.nan), isNull);
      expect(decimalFromJson(double.infinity), isNull);
    });

    test('int、数字字符串可转换；其余返回 null', () {
      expect(decimalFromJson(42), Decimal.fromInt(42));
      expect(decimalFromJson(' 1.25 '), Decimal.parse('1.25'));
      expect(decimalFromJson('abc'), isNull);
      expect(decimalFromJson(null), isNull);
      expect(decimalFromJson(true), isNull);
      expect(decimalFromJson(<String, Object?>{}), isNull);
    });
  });
}
