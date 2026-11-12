import 'package:decimal/decimal.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

Price price({
  String assetId = 'ETH',
  Quote quote = Quote.usd,
  String value = '3000.5',
  String? change24hPercent = '-2.5',
  DateTime? updatedAt,
}) => Price(
  assetId: assetId,
  quote: quote,
  price: Decimal.parse(value),
  change24hPercent: change24hPercent == null
      ? null
      : Decimal.parse(change24hPercent),
  updatedAt: updatedAt ?? DateTime.utc(2026, 1, 2, 8),
);

void main() {
  group('Quote', () {
    test('Quote_枚举值_包含USD与CNY', () {
      expect(Quote.values, [Quote.usd, Quote.cny]);
    });
  });

  group('Price', () {
    test('Price_构造后_字段可读', () {
      final p = price();
      expect(p.assetId, 'ETH');
      expect(p.quote, Quote.usd);
      expect(p.price, Decimal.parse('3000.5'));
      expect(p.change24hPercent, Decimal.parse('-2.5'));
      expect(p.updatedAt, DateTime.utc(2026, 1, 2, 8));
    });

    test('Price_价格源不提供涨跌_change24hPercent为null', () {
      expect(price(change24hPercent: null).change24hPercent, isNull);
    });

    test('Price_字段相同_相等且哈希相同', () {
      final a = price();
      final b = price();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('Price_数值小数位不同但数值相同_相等', () {
      expect(price(value: '3000.50', change24hPercent: '-2.50'), price());
    });

    test('Price_任一字段不同_不相等', () {
      final base = price();
      expect(price(assetId: 'BTC'), isNot(base));
      expect(price(quote: Quote.cny), isNot(base));
      expect(price(value: '3000.6'), isNot(base));
      expect(price(change24hPercent: '2.5'), isNot(base));
      expect(price(change24hPercent: null), isNot(base));
      expect(price(updatedAt: DateTime.utc(2026, 1, 2, 9)), isNot(base));
    });

    test('Price_toString_含币种计价与价格', () {
      expect(price(value: '3000').toString(), 'Price(ETH, usd, 3000)');
      expect(
        price(quote: Quote.cny, value: '21000').toString(),
        'Price(ETH, cny, 21000)',
      );
    });
  });
}
