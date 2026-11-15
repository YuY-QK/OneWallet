import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/features/accounts/controllers/exchange_detail_view.dart';
import 'package:ow_domain/ow_domain.dart';

Holding _h({
  required String accountId,
  required ExchangeSubAccount sub,
  required String symbol,
  required String amount,
  String? assetId,
  TokenRef? token,
}) => Holding(
  accountId: accountId,
  location: ExchangeLocation(sub),
  token: token ?? NativeToken(symbol),
  assetId: assetId ?? symbol,
  displaySymbol: symbol,
  amount: Decimal.parse(amount),
  updatedAt: DateTime.utc(2026, 11, 12, 12),
);

void main() {
  final account = Account.exchange(
    id: 'ex1',
    name: 'Binance 主账户',
    colorIndex: 0,
    createdAt: DateTime.utc(2026, 11, 1),
    exchange: ExchangeId.binance,
  );

  final prices = <String, Price>{
    'BTC': Price(
      assetId: 'BTC',
      quote: Quote.usd,
      price: Decimal.parse('50000'),
      updatedAt: DateTime.utc(2026, 11, 12, 12),
    ),
    'ETH': Price(
      assetId: 'ETH',
      quote: Quote.usd,
      price: Decimal.parse('3000'),
      updatedAt: DateTime.utc(2026, 11, 12, 12),
    ),
    'USDT': Price(
      assetId: 'USDT',
      quote: Quote.usd,
      price: Decimal.parse('1'),
      updatedAt: DateTime.utc(2026, 11, 12, 12),
    ),
  };

  group('buildExchangeDetail', () {
    test('按币种与按子账户分组、计算估值与总和', () {
      final holdings = [
        _h(
          accountId: 'ex1',
          sub: ExchangeSubAccount.spot,
          symbol: 'BTC',
          amount: '1.5',
        ),
        _h(
          accountId: 'ex1',
          sub: ExchangeSubAccount.funding,
          symbol: 'BTC',
          amount: '0.5',
        ),
        _h(
          accountId: 'ex1',
          sub: ExchangeSubAccount.spot,
          symbol: 'USDT',
          amount: '1000',
        ),
        _h(
          accountId: 'ex1',
          sub: ExchangeSubAccount.futures,
          symbol: 'ETH',
          amount: '2',
        ),
        _h(
          accountId: 'ex1',
          sub: ExchangeSubAccount.earn,
          symbol: 'JUNK',
          amount: '500',
          assetId: null,
        ),
        // 属于其他账户的持仓应被忽略
        _h(
          accountId: 'ex2',
          sub: ExchangeSubAccount.spot,
          symbol: 'BTC',
          amount: '10',
        ),
      ];

      final view = buildExchangeDetail(
        account: account,
        holdings: holdings,
        prices: prices,
        record: null,
        lastSuccessAt: DateTime.utc(2026, 11, 12, 12),
        syncing: false,
        notIncluded: ['自动投资'],
        lastSkipped: ['期权'],
      );

      expect(view.status, ExchangeDetailStatus.normal);
      expect(view.apiKeyStatus, ApiKeyStatus.normalReadOnly);
      // BTC: 2.0 * 50000 = 100,000
      // ETH: 2.0 * 3000 = 6,000
      // USDT: 1000 * 1 = 1,000
      // Total: 107,000
      expect(view.total, Decimal.parse('107000'));

      // 有估值的币种按估值降序
      expect(view.priced.length, 3);
      expect(view.priced[0].symbol, 'BTC');
      expect(view.priced[0].amount, Decimal.parse('2.0'));
      expect(view.priced[0].value, Decimal.parse('100000'));
      expect(view.priced[0].details.length, 2);
      expect(view.priced[0].details[0].sub, ExchangeSubAccount.spot);
      expect(view.priced[0].details[0].amount, Decimal.parse('1.5'));
      expect(view.priced[0].details[1].sub, ExchangeSubAccount.funding);
      expect(view.priced[0].details[1].amount, Decimal.parse('0.5'));

      expect(view.priced[1].symbol, 'ETH');
      expect(view.priced[1].value, Decimal.parse('6000'));

      expect(view.priced[2].symbol, 'USDT');
      expect(view.priced[2].value, Decimal.parse('1000'));

      // 无估值币种
      expect(view.unpriced.length, 1);
      expect(view.unpriced[0].symbol, 'JUNK');
      expect(view.unpriced[0].value, isNull);

      // 按子账户分组
      // spot: BTC (75,000) + USDT (1,000) = 76,000
      // funding: BTC (25,000) = 25,000
      // futures: ETH (6,000) = 6,000
      // earn: JUNK (无估值)
      expect(view.subAccounts.length, 4);
      final spot = view.subAccounts.firstWhere(
        (s) => s.sub == ExchangeSubAccount.spot,
      );
      expect(spot.value, Decimal.parse('76000'));
      expect(spot.assets.length, 2);

      final funding = view.subAccounts.firstWhere(
        (s) => s.sub == ExchangeSubAccount.funding,
      );
      expect(funding.value, Decimal.parse('25000'));

      final futures = view.subAccounts.firstWhere(
        (s) => s.sub == ExchangeSubAccount.futures,
      );
      expect(futures.value, Decimal.parse('6000'));

      final earn = view.subAccounts.firstWhere(
        (s) => s.sub == ExchangeSubAccount.earn,
      );
      expect(earn.value, Decimal.zero);

      // 未包含产品列表合并且去重
      expect(view.notIncluded, ['自动投资', '期权']);
    });

    test('Key 失效状态判断', () {
      final failedRecord = SyncRecord(
        accountId: 'ex1',
        startedAt: DateTime.utc(2026, 11, 12, 11, 59),
        finishedAt: DateTime.utc(2026, 11, 12, 12),
        status: SyncStatus.failed,
        failureType: 'unauthorized',
      );

      final view = buildExchangeDetail(
        account: account,
        holdings: [],
        prices: prices,
        record: failedRecord,
        lastSuccessAt: null,
        syncing: false,
      );

      expect(view.apiKeyStatus, ApiKeyStatus.expired);
      expect(view.status, ExchangeDetailStatus.keyExpired);
    });

    test('初次加载状态与无资产状态', () {
      final loadingView = buildExchangeDetail(
        account: account,
        holdings: [],
        prices: prices,
        record: null,
        lastSuccessAt: null,
        syncing: true,
      );
      expect(loadingView.status, ExchangeDetailStatus.loading);

      final emptyView = buildExchangeDetail(
        account: account,
        holdings: [],
        prices: prices,
        record: null,
        lastSuccessAt: DateTime.utc(2026, 11, 12, 12),
        syncing: false,
      );
      expect(emptyView.status, ExchangeDetailStatus.noAssets);
    });
  });
}
