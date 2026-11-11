import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/l10n/app_localizations_zh.dart';
import 'package:onewallet/widgets/formatters.dart';

Decimal d(String s) => Decimal.parse(s);

void main() {
  group('formatFiat（估值）', () {
    test('formatFiat_美元_符号加两位小数加千分位', () {
      expect(formatFiat(d('128450.32'), symbol: fiatSymbolUsd), r'$128,450.32');
    });

    test('formatFiat_人民币_使用人民币符号', () {
      expect(formatFiat(d('921330.1'), symbol: fiatSymbolCny), '¥921,330.10');
    });

    test('formatFiat_零_显示两位小数的零', () {
      expect(formatFiat(Decimal.zero, symbol: fiatSymbolUsd), r'$0.00');
    });

    test('formatFiat_极小值_四舍五入为零', () {
      expect(formatFiat(d('0.000000001'), symbol: fiatSymbolUsd), r'$0.00');
    });

    test('formatFiat_第三位小数_四舍五入', () {
      expect(formatFiat(d('1.005'), symbol: fiatSymbolUsd), r'$1.01');
      expect(formatFiat(d('1.004'), symbol: fiatSymbolUsd), r'$1.00');
    });

    test('formatFiat_大数_每三位一个逗号', () {
      expect(
        formatFiat(d('1234567890123.456'), symbol: fiatSymbolUsd),
        r'$1,234,567,890,123.46',
      );
      expect(formatFiat(d('999'), symbol: fiatSymbolUsd), r'$999.00');
      expect(formatFiat(d('1000'), symbol: fiatSymbolUsd), r'$1,000.00');
      expect(formatFiat(d('100000'), symbol: fiatSymbolUsd), r'$100,000.00');
    });

    test('formatFiat_负数_负号在符号之前', () {
      expect(formatFiat(d('-1234.5'), symbol: fiatSymbolUsd), r'-$1,234.50');
    });

    test('formatFiat_隐藏_显示星号', () {
      expect(
        formatFiat(d('128450.32'), symbol: fiatSymbolUsd, hidden: true),
        '****',
      );
    });
  });

  group('formatQuantity（数量）', () {
    test('formatQuantity_零_显示0', () {
      expect(formatQuantity(Decimal.zero), '0');
      expect(formatQuantity(d('0.000')), '0');
    });

    test('formatQuantity_小于最小显示值_显示小于号', () {
      expect(formatQuantity(d('0.000000009')), '<0.00000001');
      expect(formatQuantity(d('1e-20')), '<0.00000001');
    });

    test('formatQuantity_恰好等于最小显示值_正常显示', () {
      expect(formatQuantity(d('0.00000001')), '0.00000001');
    });

    test('formatQuantity_去掉尾随零', () {
      expect(formatQuantity(d('1.50000000')), '1.5');
      expect(formatQuantity(d('2.000')), '2');
      expect(formatQuantity(d('100')), '100');
    });

    test('formatQuantity_大于1_总共最多8位有效数字且截断', () {
      expect(formatQuantity(d('1.23456789')), '1.2345678');
      expect(formatQuantity(d('12.3456789')), '12.345678');
      expect(formatQuantity(d('1234.56789')), '1234.5678');
      expect(formatQuantity(d('1234567.89')), '1234567.8');
    });

    test('formatQuantity_截断而非四舍五入', () {
      expect(formatQuantity(d('1.99999999')), '1.9999999');
    });

    test('formatQuantity_整数部分达到8位或更多_不再显示小数', () {
      expect(formatQuantity(d('12345678.9')), '12345678');
      expect(formatQuantity(d('1234567890.123')), '1234567890');
    });

    test('formatQuantity_小于1_前导零不算有效数字', () {
      expect(formatQuantity(d('0.123456789')), '0.12345678');
      expect(formatQuantity(d('0.00123456789')), '0.0012345678');
      expect(formatQuantity(d('0.00000123456789')), '0.0000012345678');
    });

    test('formatQuantity_截断后尾部是零_继续去零', () {
      expect(formatQuantity(d('1.20000001')), '1.2');
      expect(formatQuantity(d('0.50000000999')), '0.5');
    });

    test('formatQuantity_负数_保留负号', () {
      expect(formatQuantity(d('-1.5')), '-1.5');
      expect(formatQuantity(d('-0.000000001')), '<0.00000001');
    });

    test('formatQuantity_隐藏_显示星号', () {
      expect(formatQuantity(d('1.5'), hidden: true), '****');
      expect(formatQuantity(Decimal.zero, hidden: true), '****');
    });
  });

  group('formatPercent（百分比）', () {
    test('formatPercent_正数_带加号', () {
      expect(formatPercent(d('0.95')), '+0.95%');
      expect(formatPercent(d('12.3456')), '+12.35%');
    });

    test('formatPercent_负数_带减号', () {
      expect(formatPercent(d('-3.2')), '-3.20%');
      expect(formatPercent(d('-0.456')), '-0.46%');
    });

    test('formatPercent_零_不带符号', () {
      expect(formatPercent(Decimal.zero), '0.00%');
    });

    test('formatPercent_四舍五入后为零_不带符号', () {
      expect(formatPercent(d('-0.001')), '0.00%');
      expect(formatPercent(d('0.004')), '0.00%');
    });

    test('formatPercent_一位小数', () {
      expect(formatPercent(d('1.25'), fractionDigits: 1), '+1.3%');
      expect(formatPercent(d('-1.24'), fractionDigits: 1), '-1.2%');
      expect(formatPercent(Decimal.zero, fractionDigits: 1), '0.0%');
    });
  });

  group('shortenAddress（地址）', () {
    const evm = '0x12ab34cd56ef78ab90cd12ef34ab56cd78ef9f3c';

    test('shortenAddress_默认_前6后4', () {
      expect(shortenAddress(evm), '0x12ab…9f3c');
    });

    test('shortenAddress_自定义长度', () {
      expect(shortenAddress(evm, head: 8, tail: 6), '0x12ab34…ef9f3c');
    });

    test('shortenAddress_过短的地址_原样返回', () {
      expect(shortenAddress('abc'), 'abc');
      expect(shortenAddress('0123456789'), '0123456789');
      expect(shortenAddress('01234567890'), '01234567890');
      expect(shortenAddress('012345678901'), '012345…8901');
    });

    test('shortenAddress_空串_返回空串', () {
      expect(shortenAddress(''), '');
    });
  });

  group('maskIfHidden（隐藏金额）', () {
    test('maskIfHidden_开启_显示星号', () {
      expect(maskIfHidden(r'$1.00', hidden: true), '****');
    });

    test('maskIfHidden_关闭_原样返回', () {
      expect(maskIfHidden(r'$1.00', hidden: false), r'$1.00');
    });
  });

  group('formatRelativeTime（相对时间）', () {
    final l10n = AppLocalizationsZh();
    // 用本地时间构造，避免测试依赖运行机器的时区。
    final now = DateTime(2026, 11, 11, 15, 30, 0);
    String fmt(DateTime t) => formatRelativeTime(t, now: now, l10n: l10n);

    test('刚刚_0秒与59秒', () {
      expect(fmt(now), '刚刚');
      expect(fmt(now.subtract(const Duration(seconds: 59))), '刚刚');
    });

    test('刚刚_时间晚于现在_按刚刚处理', () {
      expect(fmt(now.add(const Duration(minutes: 5))), '刚刚');
    });

    test('N分钟前_恰好1分钟与59分59秒', () {
      expect(fmt(now.subtract(const Duration(minutes: 1))), '1 分钟前');
      expect(
        fmt(now.subtract(const Duration(minutes: 3, seconds: 30))),
        '3 分钟前',
      );
      expect(
        fmt(now.subtract(const Duration(minutes: 59, seconds: 59))),
        '59 分钟前',
      );
    });

    test('当天_恰好1小时_显示时分', () {
      expect(fmt(now.subtract(const Duration(hours: 1))), '14:30');
    });

    test('当天_凌晨_时分补零', () {
      expect(fmt(DateTime(2026, 11, 11, 0, 5)), '00:05');
    });

    test('更早_昨天_显示月日加时分', () {
      expect(fmt(DateTime(2026, 11, 10, 23, 59)), '11-10 23:59');
    });

    test('更早_跨午夜但不足1小时_仍按分钟前', () {
      final midnight = DateTime(2026, 11, 12, 0, 10);
      expect(
        formatRelativeTime(
          DateTime(2026, 11, 11, 23, 50),
          now: midnight,
          l10n: l10n,
        ),
        '20 分钟前',
      );
    });

    test('更早_跨午夜超过1小时_显示月日', () {
      final early = DateTime(2026, 11, 12, 1, 30);
      expect(
        formatRelativeTime(
          DateTime(2026, 11, 11, 23, 50),
          now: early,
          l10n: l10n,
        ),
        '11-11 23:50',
      );
    });

    test('更早_月日补零', () {
      expect(fmt(DateTime(2026, 1, 5, 9, 7)), '01-05 09:07');
    });
  });
}
