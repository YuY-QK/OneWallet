import 'package:decimal/decimal.dart';
import 'package:ow_domain/src/portfolio/portfolio_math.dart';
import 'package:test/test.dart';

Decimal d(String s) => Decimal.parse(s);

void main() {
  group('shareOf', () {
    test('一半_50', () {
      expect(shareOf(d('1'), d('2')), d('50'));
    });

    test('总额为0_返回0', () {
      expect(shareOf(d('5'), Decimal.zero), Decimal.zero);
      expect(shareOf(Decimal.zero, Decimal.zero), Decimal.zero);
    });

    test('全部_100', () {
      expect(shareOf(d('3.3'), d('3.3')), d('100'));
    });

    test('三分之一_保留18位并四舍五入', () {
      expect(shareOf(d('1'), d('3')), d('33.333333333333333333'));
      expect(shareOf(d('2'), d('3')), d('66.666666666666666667'));
    });

    test('负数部分_远离零舍入', () {
      expect(shareOf(d('-2'), d('3')), d('-66.666666666666666667'));
    });

    test('极小与极大数量_不丢精度', () {
      expect(
        shareOf(d('0.000000000000000001'), d('1')),
        d('0.0000000000000001'),
      );
      expect(
        shareOf(
          d('123456789012345678901234567890'),
          d('246913578024691357802469135780'),
        ),
        d('50'),
      );
    });
  });

  group('Fraction', () {
    test('除以零_抛参数错误', () {
      expect(() => Fraction.one / Fraction.zero, throwsA(isA<ArgumentError>()));
    });

    test('除以负数_符号归到分子', () {
      final r = Fraction.fromInt(1) / Fraction.fromInt(-4);
      expect(r.toDecimal(), d('-0.25'));
    });

    test('加减乘', () {
      final a = Fraction.fromDecimal(d('0.5'));
      final b = Fraction.fromDecimal(d('0.25'));
      expect((a + b).toDecimal(), d('0.75'));
      expect((a - b).toDecimal(), d('0.25'));
      expect((a * b).toDecimal(), d('0.125'));
      expect((a - a).isZero, isTrue);
    });
  });
}
