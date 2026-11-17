import 'package:decimal/decimal.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

import '../fakes/fake_repositories.dart';
import '../fakes/fake_services.dart';

void main() {
  late InMemoryAccountRepository accounts;
  late InMemoryHoldingRepository holdings;
  late InMemoryPriceRepository prices;
  late InMemorySnapshotRepository snapshots;
  late FakeClock clock;
  late RecordDailySnapshot recordDailySnapshot;

  final account1 = Account(
    id: 'a1',
    type: AccountType.wallet,
    name: '钱包 1',
    colorIndex: 0,
    createdAt: DateTime.utc(2026, 11, 1),
  );

  final account2 = Account(
    id: 'a2',
    type: AccountType.exchange,
    name: '交易所 1',
    colorIndex: 1,
    createdAt: DateTime.utc(2026, 11, 1),
  );

  Holding makeHolding({
    required String accountId,
    required String assetId,
    required String amount,
  }) => Holding(
    accountId: accountId,
    location: const OnChainLocation(chainId: 'ethereum', addressId: 'addr1'),
    token: NativeToken(assetId.toLowerCase()),
    assetId: assetId,
    displaySymbol: assetId,
    amount: Decimal.parse(amount),
    updatedAt: DateTime.utc(2026, 11, 15),
  );

  Price makePrice(String assetId, String priceUsd) => Price(
    assetId: assetId,
    quote: Quote.usd,
    price: Decimal.parse(priceUsd),
    updatedAt: DateTime.utc(2026, 11, 15),
  );

  setUp(() {
    accounts = InMemoryAccountRepository();
    holdings = InMemoryHoldingRepository();
    prices = InMemoryPriceRepository();
    snapshots = InMemorySnapshotRepository();
    clock = FakeClock(DateTime.utc(2026, 11, 16, 14, 30, 0));

    recordDailySnapshot = RecordDailySnapshot(
      accounts: accounts,
      holdings: holdings,
      prices: prices,
      snapshots: snapshots,
      clock: clock,
    );
  });

  group('buildDailySnapshot', () {
    test('纯函数计算金额精确且按 UTC 0 点归一', () {
      final now = DateTime.utc(2026, 11, 16, 23, 59, 59);
      final snapshot = buildDailySnapshot(
        now: now,
        complete: true,
        accounts: [account1, account2],
        holdings: [
          makeHolding(accountId: 'a1', assetId: 'BTC', amount: '1.5'),
          makeHolding(accountId: 'a1', assetId: 'ETH', amount: '10'),
          makeHolding(accountId: 'a2', assetId: 'USDT', amount: '1000.50'),
          // 属于不存在账户的持仓，应忽略
          makeHolding(accountId: 'a_unknown', assetId: 'BTC', amount: '99'),
        ],
        usdPrices: {
          'BTC': makePrice('BTC', '90000'),
          'ETH': makePrice('ETH', '3000'),
          'USDT': makePrice('USDT', '1'),
        },
      );

      expect(snapshot.date, equals(DateTime.utc(2026, 11, 16)));
      expect(snapshot.complete, isTrue);
      // 1.5 * 90000 = 135000
      // 10 * 3000 = 30000
      // a1 合计 = 165000
      // a2 = 1000.50
      // total = 166000.50
      expect(snapshot.totalUsd, equals(Decimal.parse('166000.5')));
      expect(snapshot.byAccountUsd['a1'], equals(Decimal.parse('165000')));
      expect(snapshot.byAccountUsd['a2'], equals(Decimal.parse('1000.5')));
      expect(snapshot.byAssetUsd['BTC'], equals(Decimal.parse('135000')));
      expect(snapshot.byAssetUsd['ETH'], equals(Decimal.parse('30000')));
      expect(snapshot.byAssetUsd['USDT'], equals(Decimal.parse('1000.5')));
    });

    test('缺失价格或 assetId 为空时不计入 USD 净值', () {
      final snapshot = buildDailySnapshot(
        now: DateTime.utc(2026, 11, 16),
        complete: false,
        accounts: [account1],
        holdings: [
          makeHolding(accountId: 'a1', assetId: 'NO_PRICE', amount: '100'),
          Holding(
            accountId: 'a1',
            location: const OnChainLocation(
              chainId: 'ethereum',
              addressId: 'addr1',
            ),
            token: const NativeToken('unknown'),
            assetId: null,
            displaySymbol: 'UNKNOWN',
            amount: Decimal.fromInt(10),
            updatedAt: DateTime.utc(2026, 11, 16),
          ),
        ],
        usdPrices: {},
      );

      expect(snapshot.totalUsd, equals(Decimal.zero));
      expect(snapshot.complete, isFalse);
      expect(snapshot.byAccountUsd['a1'], equals(Decimal.zero));
      expect(snapshot.byAssetUsd, isEmpty);
    });
  });

  group('RecordDailySnapshot 用例', () {
    test('无账户时返回 null 且不写入快照', () async {
      final res = await recordDailySnapshot();
      expect(res, isNull);
      final range = await snapshots.range(
        DateTime.utc(2026, 1, 1),
        DateTime.utc(2026, 12, 31),
      );
      expect(range, isEmpty);
    });

    test('全量同步成功时记录 complete = true 的快照', () async {
      await accounts.upsert(account1);
      await holdings.replaceForAccount('a1', [
        makeHolding(accountId: 'a1', assetId: 'BTC', amount: '2'),
      ]);
      await prices.upsertAll([makePrice('BTC', '80000')]);

      final syncResult = SyncAllResult(
        succeededCount: 1,
        failures: const [],
        cancelledAccountIds: const [],
        pricesUpdated: true,
        cancelled: false,
        priceFailure: null,
      );

      final snapshot = await recordDailySnapshot(syncResult);
      expect(snapshot, isNotNull);
      expect(snapshot!.complete, isTrue);
      expect(snapshot.date, equals(DateTime.utc(2026, 11, 16)));
      expect(snapshot.totalUsd, equals(Decimal.parse('160000')));

      final saved = await snapshots.range(
        DateTime.utc(2026, 11, 1),
        DateTime.utc(2026, 11, 30),
      );
      expect(saved.length, equals(1));
      expect(saved.first.totalUsd, equals(Decimal.parse('160000')));
    });

    test('部分账户同步失败时沿用旧余额但标记 complete = false', () async {
      await accounts.upsert(account1);
      await accounts.upsert(account2);
      // a1 有旧持仓，本次 a1 同步失败（余额不变仍留在库里）
      await holdings.replaceForAccount('a1', [
        makeHolding(accountId: 'a1', assetId: 'ETH', amount: '5'),
      ]);
      await prices.upsertAll([makePrice('ETH', '3000')]);

      final syncResult = SyncAllResult(
        succeededCount: 1,
        failures: const [
          AccountSyncFailure(
            accountId: 'a1',
            failure: NetworkFailure('timeout'),
          ),
        ],
        cancelledAccountIds: const [],
        pricesUpdated: true,
        cancelled: false,
        priceFailure: null,
      );

      final snapshot = await recordDailySnapshot(syncResult);
      expect(snapshot, isNotNull);
      expect(snapshot!.complete, isFalse);
      expect(snapshot.totalUsd, equals(Decimal.parse('15000')));
      expect(snapshot.byAccountUsd['a1'], equals(Decimal.parse('15000')));
      expect(snapshot.byAccountUsd['a2'], equals(Decimal.zero));
    });

    test('价格同步失败时标记 complete = false', () async {
      await accounts.upsert(account1);
      await holdings.replaceForAccount('a1', [
        makeHolding(accountId: 'a1', assetId: 'BTC', amount: '1'),
      ]);
      await prices.upsertAll([makePrice('BTC', '80000')]);

      final syncResult = SyncAllResult(
        succeededCount: 1,
        failures: const [],
        cancelledAccountIds: const [],
        pricesUpdated: false,
        cancelled: false,
        priceFailure: const NetworkFailure('price error'),
      );

      final snapshot = await recordDailySnapshot(syncResult);
      expect(snapshot, isNotNull);
      expect(snapshot!.complete, isFalse);
    });

    test('同日多次同步覆盖当天快照，库中该日期只保留最新一条', () async {
      await accounts.upsert(account1);
      await holdings.replaceForAccount('a1', [
        makeHolding(accountId: 'a1', assetId: 'BTC', amount: '1'),
      ]);
      await prices.upsertAll([makePrice('BTC', '80000')]);

      // 早上同步一次
      clock.now = DateTime.utc(2026, 11, 16, 9, 0, 0);
      await recordDailySnapshot();

      var saved = await snapshots.range(
        DateTime.utc(2026, 11, 1),
        DateTime.utc(2026, 11, 30),
      );
      expect(saved.length, equals(1));
      expect(saved.first.totalUsd, equals(Decimal.parse('80000')));

      // 晚上余额更新为 2 BTC，再次同步
      clock.now = DateTime.utc(2026, 11, 16, 21, 0, 0);
      await holdings.replaceForAccount('a1', [
        makeHolding(accountId: 'a1', assetId: 'BTC', amount: '2'),
      ]);
      await recordDailySnapshot();

      saved = await snapshots.range(
        DateTime.utc(2026, 11, 1),
        DateTime.utc(2026, 11, 30),
      );
      expect(saved.length, equals(1));
      expect(saved.first.totalUsd, equals(Decimal.parse('160000')));
    });
  });
}
