import 'package:ow_data/ow_data.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  late OwDatabase db;
  late OwRepositories repos;

  setUp(() async {
    db = newDb();
    repos = OwRepositories(db);
    await repos.accounts.upsert(makeAccount('a1'));
    await repos.accounts.upsert(makeAccount('ex1', type: AccountType.exchange));
    await repos.addresses.upsert(makeAddress('ad1', 'a1'));
  });
  tearDown(() => db.close());

  group('HoldingRepository', () {
    test('三种代币与两种位置按列拆分后往返', () async {
      final list = [
        makeHolding('a1'),
        makeHolding(
          'a1',
          symbol: 'USDT',
          token: const ContractToken('ethereum', '0xdac17f'),
        ).copyWithAsset('USDT'),
      ];
      final ex = [
        Holding(
          accountId: 'ex1',
          location: const ExchangeLocation(ExchangeSubAccount.funding),
          token: const ExchangeToken(ExchangeId.okx, 'BTC'),
          displaySymbol: 'BTC',
          amount: d('0.25'),
          updatedAt: t0,
        ),
      ];
      await repos.holdings.replaceForAccount('a1', list);
      await repos.holdings.replaceForAccount('ex1', ex);
      final all = await repos.holdings.watchAll().first;
      expect(all, [...list, ...ex]);
      expect(all.every((h) => h.updatedAt.isUtc), isTrue);
    });

    test('replaceForAccount 只替换该账户，且是整体替换', () async {
      await repos.holdings.replaceForAccount('a1', [makeHolding('a1')]);
      await repos.holdings.replaceForAccount('ex1', [
        Holding(
          accountId: 'ex1',
          location: const ExchangeLocation(ExchangeSubAccount.spot),
          token: const ExchangeToken(ExchangeId.okx, 'ETH'),
          displaySymbol: 'ETH',
          amount: d('2'),
          updatedAt: t0,
        ),
      ]);
      await repos.holdings.replaceForAccount('a1', [
        makeHolding('a1', symbol: 'DAI', amount: '9'),
      ]);
      final all = await repos.holdings.watchAll().first;
      expect(all.map((h) => h.displaySymbol), ['ETH', 'DAI']);
      await repos.holdings.replaceForAccount('a1', const []);
      expect((await repos.holdings.watchAll().first).single.accountId, 'ex1');
    });

    test('事务性：中途失败回滚，旧数据仍在', () async {
      final old = [makeHolding('a1', symbol: 'OLD1'), makeHolding('a1')];
      await repos.holdings.replaceForAccount('a1', old);
      // 遇到符号为 BOOM 的行时由数据库触发器中止，模拟写到一半失败。
      await db.customStatement(
        'CREATE TRIGGER boom BEFORE INSERT ON holdings '
        "WHEN NEW.display_symbol = 'BOOM' "
        "BEGIN SELECT RAISE(ABORT, 'boom'); END",
      );
      await expectLater(
        repos.holdings.replaceForAccount('a1', [
          makeHolding('a1', symbol: 'NEW1'),
          makeHolding('a1', symbol: 'BOOM'),
          makeHolding('a1', symbol: 'NEW3'),
        ]),
        throwsA(isA<Object>()),
      );
      expect(await repos.holdings.watchAll().first, old);
    });

    test('持仓不属于该账户时抛 ArgumentError 且不改动数据', () async {
      await repos.holdings.replaceForAccount('a1', [makeHolding('a1')]);
      await expectLater(
        repos.holdings.replaceForAccount('a1', [makeHolding('ex1')]),
        throwsArgumentError,
      );
      expect(await repos.holdings.watchAll().first, hasLength(1));
    });

    test('金额精度：30 位小数与超大整数往返不变', () async {
      const tiny = '0.123456789012345678901234567891';
      const huge =
          '123456789012345678901234567890123456789012345678901234567890';
      await repos.holdings.replaceForAccount('a1', [
        makeHolding('a1', symbol: 'TINY', amount: tiny),
        makeHolding('a1', symbol: 'HUGE', amount: huge),
      ]);
      final all = await repos.holdings.watchAll().first;
      expect(all[0].amount, d(tiny));
      expect(all[0].amount.toString(), tiny);
      expect(all[1].amount, d(huge));
      expect(all[1].amount.toString(), huge);
    });

    test('未知链 id 或损坏金额的行被跳过，其他行正常', () async {
      await repos.holdings.replaceForAccount('a1', [
        makeHolding('a1', symbol: 'A'),
        makeHolding('a1', symbol: 'B'),
        makeHolding('a1', symbol: 'C'),
      ]);
      await db.customStatement(
        "UPDATE holdings SET token_chain_id = 'mars' WHERE display_symbol = 'A'",
      );
      await db.customStatement(
        "UPDATE holdings SET amount = 'abc' WHERE display_symbol = 'B'",
      );
      expect(
        (await repos.holdings.watchAll().first).map((h) => h.displaySymbol),
        ['C'],
      );
    });

    test('watchAll 随替换发出新值', () async {
      final expectation = expectLater(
        repos.holdings.watchAll(),
        emitsInOrder([isEmpty, hasLength(1), isEmpty]),
      );
      await Future<void>.delayed(Duration.zero);
      await repos.holdings.replaceForAccount('a1', [makeHolding('a1')]);
      await repos.holdings.replaceForAccount('a1', const []);
      await expectation;
    });
  });

  group('PriceRepository', () {
    Price p(String id, Quote q, String v, {String? ch}) => Price(
      assetId: id,
      quote: q,
      price: d(v),
      change24hPercent: ch == null ? null : d(ch),
      updatedAt: t0,
    );

    test('按计价货币过滤、upsert 覆盖、watch 发出新值', () async {
      final expectation = expectLater(
        repos.prices.watch(Quote.usd),
        emitsInOrder([
          isEmpty,
          {'ETH': p('ETH', Quote.usd, '3000.123456789012345678', ch: '-1.5')},
          {'ETH': p('ETH', Quote.usd, '3100')},
        ]),
      );
      await Future<void>.delayed(Duration.zero);
      await repos.prices.upsertAll([
        p('ETH', Quote.usd, '3000.123456789012345678', ch: '-1.5'),
        p('ETH', Quote.cny, '21000'),
      ]);
      await repos.prices.upsertAll([p('ETH', Quote.usd, '3100')]);
      await expectation;
      expect(
        (await repos.prices.watch(Quote.cny).first)['ETH']!.price,
        d('21000'),
      );
    });
  });

  group('SnapshotRepository', () {
    test('range 含两端、按日期升序，明细完整往返', () async {
      final days = [for (var i = 1; i <= 5; i++) DateTime.utc(2026, 11, i)];
      for (final day in days.reversed) {
        await repos.snapshots.upsert(makeSnapshot(day));
      }
      final got = await repos.snapshots.range(days[1], days[3]);
      expect(got.map((s) => s.date), days.sublist(1, 4));
      expect(got.first, makeSnapshot(days[1]));
      expect(got.first.date.isUtc, isTrue);
    });

    test('upsert 以 date 为键整体替换，旧明细不残留', () async {
      final day = DateTime.utc(2026, 11, 9);
      await repos.snapshots.upsert(makeSnapshot(day));
      await repos.snapshots.upsert(
        makeSnapshot(day, byAccount: {'a9': d('1')}),
      );
      final all = await repos.snapshots.range(day, day);
      expect(all, hasLength(1));
      expect(all.single.byAccountUsd.keys, ['a9']);
    });

    test('范围内没有快照返回空列表', () async {
      final day = DateTime.utc(2026, 1, 1);
      expect(await repos.snapshots.range(day, day), isEmpty);
    });
  });
}

extension on Holding {
  Holding copyWithAsset(String assetId) => Holding(
    accountId: accountId,
    location: location,
    token: token,
    assetId: assetId,
    displaySymbol: displaySymbol,
    amount: amount,
    updatedAt: updatedAt,
  );
}
