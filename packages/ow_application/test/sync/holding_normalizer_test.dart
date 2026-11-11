import 'package:decimal/decimal.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

import '../fakes/fake_adapters.dart';
import '../fakes/sync_fixture.dart';

void main() {
  const loc = OnChainLocation(chainId: 'ethereum', addressId: 'a1');
  const usdtContract = ContractToken(
    'ethereum',
    '0xdac17f958d2ee523a2206206994597c13d831ec7',
  );
  const spamContract = ContractToken(
    'ethereum',
    '0x9999999999999999999999999999999999999999',
  );
  const newContract = ContractToken(
    'ethereum',
    '0x8888888888888888888888888888888888888888',
  );
  final at = DateTime.utc(2026, 11, 11);

  late FakeAssetCatalog catalog;
  late FakePriceSource priceSource;
  late HoldingNormalizer normalize;

  setUp(() {
    catalog = FakeAssetCatalog()
      ..register(const NativeToken('ethereum'), eth)
      ..register(usdtContract, usdt);
    priceSource = FakePriceSource();
    normalize = HoldingNormalizer(catalog: catalog, priceSource: priceSource);
  });

  LocatedRawHolding raw(TokenRef t, String amount, {String? symbol}) => (
    location: loc,
    raw: RawHolding(
      token: t,
      amount: Decimal.parse(amount),
      symbolHint: symbol,
    ),
  );

  test('HoldingNormalizer_映射表能识别_assetId与符号取标准币种', () async {
    final r = await normalize(
      accountId: 'acc',
      raw: [raw(const NativeToken('ethereum'), '1.5'), raw(usdtContract, '10')],
      updatedAt: at,
    );
    expect(r.holdings.map((h) => h.assetId), ['ETH', 'USDT']);
    expect(r.holdings.first.displaySymbol, 'ETH');
    expect(r.holdings.first.updatedAt, at);
    expect(r.holdings.first.accountId, 'acc');
    expect(r.assets, {eth, usdt});
    expect(priceSource.lookupCalls, isEmpty);
  });

  test('HoldingNormalizer_未识别代币_assetId为空且用符号提示', () async {
    final r = await normalize(
      accountId: 'acc',
      raw: [raw(spamContract, '1000', symbol: 'FREE')],
      updatedAt: at,
    );
    expect(r.holdings.single.assetId, isNull);
    expect(r.holdings.single.displaySymbol, 'FREE');
    expect(r.assets, isEmpty);
  });

  test('HoldingNormalizer_未识别且无符号_用缩略合约地址', () async {
    final r = await normalize(
      accountId: 'acc',
      raw: [raw(spamContract, '1')],
      updatedAt: at,
    );
    expect(r.holdings.single.displaySymbol, '0x9999…9999');
  });

  test('HoldingNormalizer_lookupContracts能补救_被识别', () async {
    const found = Asset(id: 'NEW', symbol: 'NEW', name: 'New Token');
    priceSource.lookupResult = Ok({newContract: found});
    final r = await normalize(
      accountId: 'acc',
      raw: [raw(newContract, '3'), raw(spamContract, '1')],
      updatedAt: at,
    );
    expect(priceSource.lookupCalls.single, {newContract, spamContract});
    expect(r.holdings.map((h) => h.assetId), ['NEW', null]);
    expect(r.assets, {found});
  });

  test('HoldingNormalizer_lookupContracts失败_按未识别处理', () async {
    priceSource.lookupResult = const Err(ServiceDownFailure());
    final r = await normalize(
      accountId: 'acc',
      raw: [raw(newContract, '3')],
      updatedAt: at,
    );
    expect(r.holdings.single.assetId, isNull);
  });

  test('HoldingNormalizer_数量为0_被丢弃且不参与查询', () async {
    final r = await normalize(
      accountId: 'acc',
      raw: [raw(spamContract, '0'), raw(const NativeToken('ethereum'), '0.0')],
      updatedAt: at,
    );
    expect(r.holdings, isEmpty);
    expect(priceSource.lookupCalls, isEmpty);
  });

  test('HoldingNormalizer_未识别的原生币与交易所币_退回链原生符号或交易所符号', () async {
    final r = await normalize(
      accountId: 'acc',
      raw: [
        raw(const NativeToken('arbitrum'), '1'),
        raw(const NativeToken('unknown-chain'), '1'),
        raw(const ExchangeToken(ExchangeId.okx, 'PEPE'), '5'),
      ],
      updatedAt: at,
    );
    expect(r.holdings.map((h) => h.displaySymbol), [
      'ETH',
      'unknown-chain',
      'PEPE',
    ]);
  });
}
