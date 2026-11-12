import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

import '../fakes/fake_services.dart';
import '../fakes/sync_fixture.dart';

void main() {
  const a = TestAddresses.evmA;
  late SyncFixture f;

  setUp(() => f = SyncFixture());

  test('SyncAccount_全部地址与链成功_替换持仓并写成功记录', () async {
    await f.addWallet('w1', a, chainIds: {'ethereum', 'arbitrum'});
    await f.seedOldHolding('w1');
    f
      ..ethBalance(a, 'ethereum', '1.5')
      ..ethBalance(a, 'arbitrum', '0.2');
    final startedAt = f.clock.nowUtc();

    final result = await f.syncAccount('w1');

    expect(result.isOk, isTrue);
    expect(result.valueOrNull?.cancelled, isFalse);
    expect(result.valueOrNull?.assets, {eth});
    final held = f.holdings.forAccount('w1');
    expect(held.map((h) => h.amount), [
      Decimal.parse('1.5'),
      Decimal.parse('0.2'),
    ]);
    expect(held.first.location, isA<OnChainLocation>());
    final record = f.syncRecords.records.single;
    expect(record.status, SyncStatus.success);
    expect(record.startedAt, startedAt);
    expect(record.finishedAt, isNotNull);
    expect(record.failureType, isNull);
  });

  test('SyncAccount_某个地址乘链失败_整体失败且旧持仓不变', () async {
    await f.addWallet('w1', a, chainIds: {'ethereum', 'arbitrum', 'base'});
    final old = await f.seedOldHolding('w1');
    f.ethBalance(a, 'ethereum', '1');
    f.adapters.evm.respond(a, 'arbitrum', [const Err(ServiceDownFailure())]);

    final result = await f.syncAccount('w1');

    expect(
      result.when(ok: (_) => null, err: (e) => e),
      isA<ServiceDownFailure>(),
    );
    expect(f.holdings.forAccount('w1'), [old]);
    expect(f.holdings.replaceCalls, isEmpty);
    // 失败后不再查询剩下的链。
    expect(f.adapters.evm.calls, ['$a|ethereum', '$a|arbitrum']);
    final record = f.syncRecords.records.single;
    expect(record.status, SyncStatus.failed);
    expect(record.failureType, 'ServiceDownFailure');
  });

  test('SyncAccount_限频后恢复_经退避重试后成功', () async {
    await f.addWallet('w1', a);
    f.adapters.evm.respond(a, 'ethereum', [
      const Err(RateLimitedFailure()),
      const Err(RateLimitedFailure()),
      Ok([
        RawHolding(token: const NativeToken('ethereum'), amount: Decimal.one),
      ]),
    ]);

    final result = await f.syncAccount('w1');

    expect(result.isOk, isTrue);
    expect(f.delay.durations, const [
      Duration(seconds: 1),
      Duration(seconds: 2),
    ]);
  });

  test('SyncAccount_凭据类失败_不重试', () async {
    await f.addWallet('w1', a);
    f.adapters.evm.respond(a, 'ethereum', [const Err(UnauthorizedFailure())]);

    await f.syncAccount('w1');

    expect(f.adapters.evm.calls, hasLength(1));
    expect(f.delay.durations, isEmpty);
    expect(f.syncRecords.records.single.failureType, 'UnauthorizedFailure');
  });

  test('SyncAccount_同一账户并发调用_只执行一次', () async {
    await f.addWallet('w1', a);
    f.adapters.evm.gate = Completer<void>();

    final first = f.syncAccount('w1');
    final second = f.syncAccount('w1');
    expect(identical(first, second), isTrue);
    f.adapters.evm.gate?.complete();
    await Future.wait([first, second]);

    expect(f.adapters.evm.calls, hasLength(1));
    expect(f.syncRecords.records, hasLength(1));
    // 结束后再次调用会重新执行。
    await f.syncAccount('w1');
    expect(f.adapters.evm.calls, hasLength(2));
  });

  test('SyncAccount_交易所账户_返回不支持并写失败记录', () async {
    await f.accounts.upsert(
      Account(
        id: 'x1',
        type: AccountType.exchange,
        name: '交易所',
        colorIndex: 1,
        exchange: ExchangeId.okx,
        createdAt: f.clock.nowUtc(),
      ),
    );

    final result = await f.syncAccount('x1');

    expect(
      result.when(ok: (_) => null, err: (e) => e),
      isA<UnsupportedFailure>(),
    );
    expect(
      f.syncRecords.records.single.failureType,
      'UnsupportedFailure.notIntegrated',
    );
  });

  test('SyncAccount_账户不存在_返回校验失败且不写记录', () async {
    final result = await f.syncAccount('missing');
    expect(
      result.when(ok: (_) => null, err: (e) => e),
      isA<ValidationFailure>(),
    );
    expect(f.syncRecords.records, isEmpty);
  });

  test('SyncAccount_启用的链未知或不属于该家族_跳过', () async {
    await f.addWallet('w1', a, chainIds: {'ethereum', 'retired-chain', 'tron'});
    await f.syncAccount('w1');
    expect(f.adapters.evm.calls, ['$a|ethereum']);
  });

  test('SyncAccount_请求期间被取消_不写持仓也不写记录', () async {
    await f.addWallet('w1', a, chainIds: {'ethereum', 'arbitrum'});
    final old = await f.seedOldHolding('w1');
    final cancellation = SyncCancellation();
    f.adapters.evm.onCall = (_) => cancellation.cancel();

    final result = await f.syncAccount('w1', cancellation: cancellation);

    expect(result.valueOrNull?.cancelled, isTrue);
    expect(f.adapters.evm.calls, hasLength(1));
    expect(f.holdings.forAccount('w1'), [old]);
    expect(f.syncRecords.records, isEmpty);
  });

  test('failureTypeName_各失败类型_返回稳定的类型名', () {
    expect(failureTypeName(const NetworkFailure()), 'NetworkFailure');
    expect(failureTypeName(const RateLimitedFailure()), 'RateLimitedFailure');
    expect(failureTypeName(const KeyExpiredFailure()), 'KeyExpiredFailure');
    expect(failureTypeName(const ClockSkewFailure()), 'ClockSkewFailure');
    expect(failureTypeName(const ValidationFailure()), 'ValidationFailure');
    expect(
      failureTypeName(const DuplicateAddressFailure(shortAddress: 'x')),
      'DuplicateAddressFailure',
    );
    expect(
      failureTypeName(const WrongPasswordFailure()),
      'WrongPasswordFailure',
    );
    expect(failureTypeName(const UnknownFailure()), 'UnknownFailure');
    expect(failureTypeName(const UnsupportedFailure()), 'UnsupportedFailure');
    expect(
      failureTypeName(const UnsupportedFailure.notIntegrated()),
      'UnsupportedFailure.notIntegrated',
    );
  });
}
