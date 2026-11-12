import 'package:decimal/decimal.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

import '../fakes/fake_adapters.dart';
import '../fakes/fake_repositories.dart';
import '../fakes/fake_services.dart';
import '../fakes/sync_fixture.dart';

void main() {
  const evmContract = '0x8888888888888888888888888888888888888888';
  const newToken = ContractToken('ethereum', evmContract);
  const foo = Asset(id: 'FOO', symbol: 'FOO', name: 'Foo', priceId: 'foo-coin');

  late FakeAssetCatalog builtIn;
  late InMemoryAssetRepository repo;
  late PersistentAssetCatalog catalog;

  PersistentAssetCatalog build() => PersistentAssetCatalog(
    builtIn: builtIn,
    repository: repo,
    clock: FakeClock(),
  );

  setUp(() {
    builtIn = FakeAssetCatalog()
      ..register(const NativeToken('ethereum'), eth)
      ..register(
        const ContractToken(
          'ethereum',
          '0xdac17f958d2ee523a2206206994597c13d831ec7',
        ),
        usdt,
      );
    repo = InMemoryAssetRepository();
    catalog = build();
  });

  test('内置表优先；库中没有时返回 null', () async {
    await catalog.load();
    expect(catalog.resolve(const NativeToken('ethereum')), eth);
    expect(catalog.byId('USDT'), usdt);
    expect(catalog.byPriceId('ethereum'), eth);
    expect(catalog.resolve(newToken), isNull);
    expect(catalog.byId('FOO'), isNull);
    expect(catalog.byPriceId('foo-coin'), isNull);
  });

  test('remember 先写库再更新内存；合约大小写不敏感', () async {
    await catalog.load();
    final out = await catalog.remember({newToken: foo});
    expect(out, {newToken: foo});
    expect(repo.assets['FOO'], foo);
    expect(repo.contractMap, {newToken: 'FOO'});
    expect(catalog.resolve(newToken), foo);
    expect(
      catalog.resolve(ContractToken('ethereum', evmContract.toUpperCase())),
      foo,
    );
    expect(catalog.byId('FOO'), foo);
    expect(catalog.byPriceId('foo-coin'), foo);
  });

  test('重启后 load 能从库恢复币种与合约对应', () async {
    await catalog.remember({newToken: foo});
    final restarted = build();
    expect(restarted.resolve(newToken), isNull);
    await restarted.load();
    expect(restarted.resolve(newToken), foo);
    expect(restarted.byPriceId('foo-coin'), foo);
  });

  test('同一价格源标识的另一条链合约复用已有币种', () async {
    await catalog.remember({newToken: foo});
    const other = ContractToken(
      'bsc',
      '0x7777777777777777777777777777777777777777',
    );
    final out = await catalog.remember({other: foo});
    expect(out[other], foo);
    expect(repo.assets, hasLength(1));
    expect(repo.contractMap[other], 'FOO');
  });

  test('币种 id 与另一价格源标识的已存币种冲突时改名，不覆盖原来的', () async {
    await catalog.remember({newToken: foo});
    const scam = Asset(id: 'FOO', symbol: 'FOO', name: 'Foo?', priceId: 'scam');
    const scamToken = ContractToken(
      'ethereum',
      '0x6666666666666666666666666666666666666666',
    );
    final out = await catalog.remember({scamToken: scam});
    expect(out[scamToken]?.id, 'FOO-SCAM');
    expect(repo.assets['FOO'], foo);
    expect(repo.assets['FOO-SCAM']?.priceId, 'scam');
    expect(catalog.resolve(scamToken)?.id, 'FOO-SCAM');
  });

  test('同一批次内 id 冲突也改名', () async {
    const a = Asset(id: 'BAR', symbol: 'BAR', name: 'Bar1', priceId: 'bar-1');
    const b = Asset(id: 'BAR', symbol: 'BAR', name: 'Bar2', priceId: 'bar-2');
    const ta = ContractToken(
      'ethereum',
      '0x1000000000000000000000000000000000000001',
    );
    const tb = ContractToken(
      'ethereum',
      '0x1000000000000000000000000000000000000002',
    );
    final out = await catalog.remember({ta: a, tb: b});
    expect({out[ta]?.id, out[tb]?.id}, {'BAR', 'BAR-BAR-2'});
  });

  test('内置表已有的币种（价格源合并到内置币种）：记合约对应', () async {
    await catalog.load();
    final out = await catalog.remember({newToken: usdt});
    expect(out[newToken], usdt);
    expect(catalog.resolve(newToken), usdt);
    expect(repo.contractMap[newToken], 'USDT');
  });

  test('重复 remember 同样内容不再写库', () async {
    await catalog.remember({newToken: foo});
    final calls = repo.upsertCalls;
    await catalog.remember({newToken: foo});
    expect(repo.upsertCalls, calls);
  });

  test('库中币种后来被内置表以不同内容收录：忽略库中那条', () async {
    await catalog.remember({newToken: foo});
    builtIn.register(
      const NativeToken('bsc'),
      const Asset(id: 'FOO', symbol: 'FOO', name: 'Real', priceId: 'real-foo'),
    );
    final restarted = build();
    await restarted.load();
    expect(restarted.byId('FOO')?.priceId, 'real-foo');
    expect(restarted.resolve(newToken), isNull);
  });

  test('HoldingNormalizer 配合目录：查到的币种存库，第二次不再向价格源查询', () async {
    final priceSource = FakePriceSource()..lookupResult = Ok({newToken: foo});
    final normalize = HoldingNormalizer(
      catalog: catalog,
      priceSource: priceSource,
      recorder: catalog,
    );
    final raw = [
      (
        location: const OnChainLocation(chainId: 'ethereum', addressId: 'a1'),
        raw: RawHolding(token: newToken, amount: Decimal.parse('5')),
      ),
    ];

    final first = await normalize(
      accountId: 'acc',
      raw: raw,
      updatedAt: DateTime.utc(2026, 11, 12),
    );
    expect(first.holdings.single.assetId, 'FOO');
    expect(first.assets, {foo});
    expect(repo.assets['FOO'], foo);
    expect(priceSource.lookupCalls, hasLength(1));

    final second = await normalize(
      accountId: 'acc',
      raw: raw,
      updatedAt: DateTime.utc(2026, 11, 12),
    );
    expect(second.holdings.single.assetId, 'FOO');
    expect(priceSource.lookupCalls, hasLength(1));
  });

  test('HoldingNormalizer 价格源没查到：不写库', () async {
    final normalize = HoldingNormalizer(
      catalog: catalog,
      priceSource: FakePriceSource(),
      recorder: catalog,
    );
    await normalize(
      accountId: 'acc',
      raw: [
        (
          location: const OnChainLocation(chainId: 'ethereum', addressId: 'a1'),
          raw: RawHolding(token: newToken, amount: Decimal.one),
        ),
      ],
      updatedAt: DateTime.utc(2026, 11, 12),
    );
    expect(repo.assets, isEmpty);
    expect(repo.upsertCalls, 0);
  });
}
