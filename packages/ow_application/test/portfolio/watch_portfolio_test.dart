import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

import '../fakes/fake_repositories.dart';

Price _price(String id, Quote q, String v) => Price(
  assetId: id,
  quote: q,
  price: Decimal.parse(v),
  updatedAt: DateTime.utc(2026, 11, 11),
);

void main() {
  late InMemoryAccountRepository accounts;
  late InMemoryHoldingRepository holdings;
  late InMemoryPriceRepository prices;
  late InMemorySettingsRepository settings;
  late InMemoryTokenVisibilityRepository visibility;
  late List<PortfolioSummary> emitted;
  late StreamSubscription<PortfolioSummary> sub;

  final account = Account(
    id: 'w1',
    type: AccountType.wallet,
    name: '钱包',
    colorIndex: 0,
    createdAt: DateTime.utc(2026),
  );

  Holding holding(TokenRef token, String assetId, String amount) => Holding(
    accountId: 'w1',
    location: const OnChainLocation(chainId: 'ethereum', addressId: 'a1'),
    token: token,
    assetId: assetId,
    displaySymbol: assetId,
    amount: Decimal.parse(amount),
    updatedAt: DateTime.utc(2026),
  );

  final ethHolding = holding(const NativeToken('ethereum'), 'ETH', '2');
  final dustHolding = holding(
    const ContractToken(
      'ethereum',
      '0x5555555555555555555555555555555555555555',
    ),
    'DUST',
    '1',
  );

  setUp(() async {
    accounts = InMemoryAccountRepository();
    holdings = InMemoryHoldingRepository();
    prices = InMemoryPriceRepository();
    settings = InMemorySettingsRepository();
    visibility = InMemoryTokenVisibilityRepository();
    await accounts.upsert(account);
    await holdings.replaceForAccount('w1', [ethHolding]);
    await prices.upsertAll([
      _price('ETH', Quote.usd, '3000'),
      _price('ETH', Quote.cny, '21000'),
    ]);
    emitted = [];
    sub = WatchPortfolio(
      accounts: accounts,
      holdings: holdings,
      prices: prices,
      settings: settings,
      tokenVisibility: visibility,
    )().listen(emitted.add);
    await pumpEventQueue();
  });

  tearDown(() => sub.cancel());

  test('WatchPortfolio_订阅后_发出按当前货币计算的摘要', () {
    expect(emitted, hasLength(1));
    expect(emitted.single.total, Decimal.parse('6000'));
  });

  test('WatchPortfolio_持仓变化_发出新摘要', () async {
    await holdings.replaceForAccount('w1', [
      holding(const NativeToken('ethereum'), 'ETH', '3'),
    ]);
    await pumpEventQueue();
    expect(emitted.last.total, Decimal.parse('9000'));
  });

  test('WatchPortfolio_价格变化_发出新摘要', () async {
    await prices.upsertAll([_price('ETH', Quote.usd, '3500')]);
    await pumpEventQueue();
    expect(emitted.last.total, Decimal.parse('7000'));
  });

  test('WatchPortfolio_账户变化_发出新摘要', () async {
    final before = emitted.length;
    await accounts.upsert(account.copyWith(name: '改名'));
    await pumpEventQueue();
    expect(emitted.length, before + 1);
  });

  test('WatchPortfolio_切换计价货币_改用该货币价格', () async {
    await settings.update((s) => s.copyWith(quote: Quote.cny));
    await pumpEventQueue();
    expect(emitted.last.total, Decimal.parse('42000'));
  });

  test('WatchPortfolio_手动隐藏代币_立即发出新摘要', () async {
    final before = emitted.length;
    await visibility.setHidden(const NativeToken('ethereum').tokenKey, true);
    await pumpEventQueue();
    expect(emitted.length, before + 1);
    expect(emitted.last.total, Decimal.zero);
  });

  test('WatchPortfolio_取消隐藏代币_立即恢复计入', () async {
    final key = const NativeToken('ethereum').tokenKey;
    await visibility.setHidden(key, true);
    await pumpEventQueue();
    await visibility.setHidden(key, false);
    await pumpEventQueue();
    expect(emitted.last.total, Decimal.parse('6000'));
  });

  test('WatchPortfolio_小额隐藏开关_影响隐藏计数', () async {
    await prices.upsertAll([_price('DUST', Quote.usd, '0.5')]);
    await holdings.replaceForAccount('w1', [ethHolding, dustHolding]);
    await pumpEventQueue();
    expect(emitted.last.hiddenSmallCount, 1);

    await settings.update((s) => s.copyWith(hideSmall: false));
    await pumpEventQueue();
    expect(emitted.last.hiddenSmallCount, 0);
  });

  test('WatchPortfolio_CNY下小额阈值取USDT价格', () async {
    // DUST 估值 5 CNY：阈值 7.2（USDT 的 CNY 价格）时隐藏；没有 USDT 价格时阈值退回 1，不隐藏。
    await prices.upsertAll([_price('DUST', Quote.cny, '5')]);
    await holdings.replaceForAccount('w1', [ethHolding, dustHolding]);
    await settings.update((s) => s.copyWith(quote: Quote.cny));
    await pumpEventQueue();
    expect(emitted.last.hiddenSmallCount, 0);

    await prices.upsertAll([_price('USDT', Quote.cny, '7.2')]);
    await pumpEventQueue();
    expect(emitted.last.hiddenSmallCount, 1);
  });

  test('smallThresholdFor_各计价货币_USD为1且CNY取USDT价格或退回1', () {
    final p = {'USDT': _price('USDT', Quote.cny, '7.1')};
    expect(WatchPortfolio.smallThresholdFor(Quote.usd, p), Decimal.one);
    expect(
      WatchPortfolio.smallThresholdFor(Quote.cny, p),
      Decimal.parse('7.1'),
    );
    expect(WatchPortfolio.smallThresholdFor(Quote.cny, const {}), Decimal.one);
  });
}
