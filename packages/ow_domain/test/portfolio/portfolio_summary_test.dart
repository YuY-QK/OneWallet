import 'package:decimal/decimal.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

Decimal d(String s) => Decimal.parse(s);

PortfolioSummary make({
  List<AssetSlice>? byAsset,
  Decimal? change,
  int unpriced = 0,
}) => PortfolioSummary(
  total: d('10'),
  change24h: change,
  change24hPercent: change,
  unpricedCount: unpriced,
  hiddenSmallCount: 1,
  byAsset:
      byAsset ??
      [
        AssetSlice(
          assetId: 'ETH',
          displaySymbol: 'ETH',
          amount: d('1'),
          value: d('10'),
        ),
      ],
  byAccount: [AccountSlice(accountId: 'a', value: d('10'))],
  onChainTotal: d('10'),
  exchangeTotal: Decimal.zero,
);

void main() {
  group('PortfolioSummary 值语义', () {
    test('相同内容_相等且哈希相同', () {
      expect(make(), make());
      expect(make().hashCode, make().hashCode);
    });

    test('任一字段不同_不相等', () {
      expect(make(unpriced: 1), isNot(make()));
      expect(make(change: d('1')), isNot(make()));
      expect(
        make(
          byAsset: [
            AssetSlice(
              assetId: 'ETH',
              displaySymbol: 'ETH',
              amount: d('2'),
              value: d('10'),
            ),
          ],
        ),
        isNot(make()),
      );
    });

    test('列表不可修改', () {
      final s = make();
      expect(() => s.byAsset.clear(), throwsUnsupportedError);
      expect(() => s.byAccount.clear(), throwsUnsupportedError);
    });
  });

  group('切片值语义', () {
    test('AssetSlice_相等与哈希', () {
      final a = AssetSlice(
        assetId: 'A',
        displaySymbol: 'A',
        amount: d('1'),
        value: d('2'),
      );
      final b = AssetSlice(
        assetId: 'A',
        displaySymbol: 'A',
        amount: d('1.0'),
        value: d('2'),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('AccountSlice_相等与哈希', () {
      expect(
        AccountSlice(accountId: 'a', value: d('1')),
        AccountSlice(accountId: 'a', value: d('1.0')),
      );
      expect(
        AccountSlice(accountId: 'a', value: d('1')),
        isNot(AccountSlice(accountId: 'b', value: d('1'))),
      );
      expect(
        AccountSlice(accountId: 'a', value: d('1')).hashCode,
        AccountSlice(accountId: 'a', value: d('1')).hashCode,
      );
    });

    test('ValuedHolding_相等与哈希', () {
      final h = Holding(
        accountId: 'a',
        location: const ExchangeLocation(ExchangeSubAccount.spot),
        token: const ExchangeToken(ExchangeId.okx, 'BTC'),
        displaySymbol: 'BTC',
        amount: d('1'),
        updatedAt: DateTime.utc(2026),
      );
      expect(
        ValuedHolding(holding: h, value: d('2')),
        ValuedHolding(holding: h, value: d('2')),
      );
      expect(
        ValuedHolding(holding: h, value: d('2')).hashCode,
        ValuedHolding(holding: h, value: d('2')).hashCode,
      );
      expect(
        ValuedHolding(holding: h),
        isNot(ValuedHolding(holding: h, value: d('2'))),
      );
    });
  });
}
