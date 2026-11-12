import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

Asset asset({
  String id = 'ETH',
  String symbol = 'ETH',
  String name = 'Ether',
  String? priceId = 'ethereum',
}) => Asset(id: id, symbol: symbol, name: name, priceId: priceId);

void main() {
  group('Asset', () {
    test('Asset_构造后_字段可读', () {
      final a = asset();
      expect(a.id, 'ETH');
      expect(a.symbol, 'ETH');
      expect(a.name, 'Ether');
      expect(a.priceId, 'ethereum');
    });

    test('Asset_没有价格源_priceId为null', () {
      expect(asset(priceId: null).priceId, isNull);
    });

    test('Asset_字段相同_相等且哈希相同', () {
      final a = asset();
      final b = asset();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('Asset_任一字段不同_不相等', () {
      final base = asset();
      expect(asset(id: 'WETH'), isNot(base));
      expect(asset(symbol: 'WETH'), isNot(base));
      expect(asset(name: 'Wrapped Ether'), isNot(base));
      expect(asset(priceId: 'weth'), isNot(base));
      expect(asset(priceId: null), isNot(base));
    });

    test('Asset_作为集合元素_去重', () {
      final set = {asset(), asset(), asset(id: 'WETH')};
      expect(set, hasLength(2));
    });

    test('toString_输出标准币种id', () {
      expect(asset().toString(), 'Asset(ETH)');
    });
  });
}
