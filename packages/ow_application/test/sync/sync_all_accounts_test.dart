import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

import '../fakes/sync_fixture.dart';

/// 第 [i] 个测试地址（合法 EVM 格式的假数据）。
String addr(int i) => '0x${i.toRadixString(16).padLeft(40, '0')}';

Price price(String assetId, Quote q, String v) => Price(
  assetId: assetId,
  quote: q,
  price: Decimal.parse(v),
  updatedAt: DateTime.utc(2026, 11, 11),
);

void main() {
  late SyncFixture f;

  setUp(() => f = SyncFixture());

  Future<void> addWallets(int n) async {
    for (var i = 1; i <= n; i++) {
      await f.addWallet('w$i', addr(i));
      f.ethBalance(addr(i), 'ethereum', '$i');
    }
  }

  test('SyncAllAccounts_部分账户失败_其余正常且失败者保留旧数据并写记录', () async {
    await addWallets(3);
    final old = await f.seedOldHolding('w2');
    f.adapters.evm.respond(addr(2), 'ethereum', [
      const Err(ServiceDownFailure()),
    ]);

    final result = await f.syncAll();

    expect(result.succeededCount, 2);
    expect(result.failures, [
      const AccountSyncFailure(accountId: 'w2', failure: ServiceDownFailure()),
    ]);
    expect(result.cancelled, isFalse);
    expect(result.allAccountsSucceeded, isFalse);
    expect(f.holdings.forAccount('w2'), [old]);
    expect(f.holdings.forAccount('w1').single.amount, Decimal.one);
    expect(f.holdings.forAccount('w3').single.amount, Decimal.parse('3'));
    final byAccount = {for (final r in f.syncRecords.records) r.accountId: r};
    expect(byAccount['w2']?.status, SyncStatus.failed);
    expect(byAccount['w1']?.status, SyncStatus.success);
  });

  test('SyncAllAccounts_十个账户_同时进行的请求不超过4个', () async {
    await addWallets(10);
    final gate = Completer<void>();
    f.adapters.evm.gate = gate;

    final running = f.syncAll();
    await pumpEventQueue();
    expect(f.adapters.evm.maxInFlight, 4);
    gate.complete();
    final result = await running;

    expect(result.succeededCount, 10);
    expect(f.adapters.evm.maxInFlight, 4);
  });

  test('SyncAllAccounts_并发上限可配置为1_串行执行', () async {
    f = SyncFixture(maxConcurrency: 1);
    await addWallets(3);
    await f.syncAll();
    expect(f.adapters.evm.maxInFlight, 1);
  });

  test('SyncAllAccounts_结束后_按当前货币与USD拉取价格并写入', () async {
    await addWallets(1);
    await f.settings.update((s) => s.copyWith(quote: Quote.cny));
    f.priceSource.pricesByQuote[Quote.cny] = Ok([
      price('ETH', Quote.cny, '20000'),
    ]);
    f.priceSource.pricesByQuote[Quote.usd] = Ok([
      price('ETH', Quote.usd, '3000'),
    ]);

    final result = await f.syncAll();

    expect(result.pricesUpdated, isTrue);
    expect(result.priceFailure, isNull);
    expect(f.priceSource.fetchCalls.map((c) => c.$2), [Quote.cny, Quote.usd]);
    expect(f.priceSource.fetchCalls.first.$1, {eth});
    expect(f.prices.store.value, hasLength(2));
  });

  test('SyncAllAccounts_计价货币为USD_只拉取一次', () async {
    await addWallets(1);
    await f.syncAll();
    expect(f.priceSource.fetchCalls.map((c) => c.$2), [Quote.usd]);
  });

  test('SyncAllAccounts_失败账户的旧持仓_其币种也拉取价格', () async {
    await f.addWallet('w1', addr(1));
    await f.seedOldHolding('w1');
    f.adapters.evm.respond(addr(1), 'ethereum', [
      const Err(ServiceDownFailure()),
    ]);
    f.catalog.register(const NativeToken('ethereum'), eth);

    await f.syncAll();

    expect(f.priceSource.fetchCalls.single.$1, {eth});
  });

  test('SyncAllAccounts_价格拉取失败_不影响账户结果并在返回值中体现', () async {
    await addWallets(2);
    f.priceSource.pricesByQuote[Quote.usd] = const Err(ServiceDownFailure());

    final result = await f.syncAll();

    expect(result.succeededCount, 2);
    expect(result.failures, isEmpty);
    expect(result.pricesUpdated, isFalse);
    expect(result.priceFailure, isA<ServiceDownFailure>());
    expect(f.prices.upsertCalls, isEmpty);
  });

  test('SyncAllAccounts_没有任何币种_不调用价格源', () async {
    final result = await f.syncAll();
    expect(result.succeededCount, 0);
    expect(result.pricesUpdated, isTrue);
    expect(f.priceSource.fetchCalls, isEmpty);
  });

  test('SyncAllAccounts_取消后_未开始的账户不再执行且已完成的保留', () async {
    f = SyncFixture(maxConcurrency: 1);
    await addWallets(4);
    f.adapters.evm.onCall = (key) {
      if (key.startsWith(addr(2))) f.syncAll.cancel();
    };

    final result = await f.syncAll();

    expect(f.adapters.evm.calls, hasLength(2));
    expect(result.cancelled, isTrue);
    expect(result.succeededCount, 1);
    expect(result.cancelledAccountIds, ['w2', 'w3', 'w4']);
    expect(result.pricesUpdated, isFalse);
    expect(f.holdings.forAccount('w1'), hasLength(1));
    expect(f.holdings.forAccount('w2'), isEmpty);
    expect(f.priceSource.fetchCalls, isEmpty);
    expect(f.syncRecords.records.map((r) => r.accountId), ['w1']);
  });

  test('SyncAllAccounts_没有进行中的同步_cancel无副作用', () async {
    f.syncAll.cancel();
    await addWallets(1);
    expect((await f.syncAll()).succeededCount, 1);
  });

  test('SyncAllAccounts_进行中再次调用_返回同一个Future', () async {
    await addWallets(1);
    f.adapters.evm.gate = Completer<void>();
    final first = f.syncAll();
    expect(f.syncAll.isRunning, isTrue);
    expect(identical(first, f.syncAll()), isTrue);
    f.adapters.evm.gate?.complete();
    await first;
    expect(f.syncAll.isRunning, isFalse);
    expect(f.adapters.evm.calls, hasLength(1));
  });

  test('SyncAllAccounts_进度流_推送已完成数与总数', () async {
    await addWallets(3);
    final events = <SyncProgress>[];
    final sub = f.syncAll.progress.listen(events.add);

    await f.syncAll();
    await sub.cancel();

    expect(events.first, const SyncProgress(completed: 0, total: 3));
    expect(events.last, const SyncProgress(completed: 3, total: 3));
    expect(events, hasLength(4));
  });

  test('SyncAllAccounts_全量结束_调用完成钩子；被取消时不调用', () async {
    final hooked = <SyncAllResult>[];
    f = SyncFixture(onCompleted: (r) async => hooked.add(r));
    await addWallets(1);
    await f.syncAll();
    expect(hooked.single.succeededCount, 1);

    f.adapters.evm.onCall = (_) => f.syncAll.cancel();
    await f.syncAll();
    expect(hooked, hasLength(1));
  });

  group('shouldAutoSync', () {
    SyncRecord success(DateTime at) => SyncRecord(
      accountId: 'w1',
      startedAt: at.subtract(const Duration(seconds: 3)),
      finishedAt: at,
      status: SyncStatus.success,
    );

    test('shouldAutoSync_从未成功同步_返回true', () async {
      expect(await f.syncAll.shouldAutoSync(), isTrue);
      await f.syncRecords.add(
        SyncRecord(
          accountId: 'w1',
          startedAt: f.clock.nowUtc(),
          finishedAt: f.clock.nowUtc(),
          status: SyncStatus.failed,
          failureType: 'NetworkFailure',
        ),
      );
      expect(await f.syncAll.shouldAutoSync(), isTrue);
    });

    test('shouldAutoSync_恰好5分钟_返回false', () async {
      await f.syncRecords.add(success(f.clock.nowUtc()));
      f.clock.advance(const Duration(minutes: 5));
      expect(await f.syncAll.shouldAutoSync(), isFalse);
    });

    test('shouldAutoSync_超过5分钟_返回true', () async {
      await f.syncRecords.add(success(f.clock.nowUtc()));
      f.clock.advance(const Duration(minutes: 5, seconds: 1));
      expect(await f.syncAll.shouldAutoSync(), isTrue);
    });

    test('shouldAutoSync_多个账户_以最晚的一次成功为准', () async {
      final t0 = f.clock.nowUtc();
      await f.syncRecords.add(success(t0));
      await f.syncRecords.add(
        SyncRecord(
          accountId: 'w2',
          startedAt: t0.add(const Duration(minutes: 3)),
          status: SyncStatus.success,
        ),
      );
      f.clock.advance(const Duration(minutes: 7));
      expect(await f.syncAll.shouldAutoSync(), isFalse);
    });
  });
}
