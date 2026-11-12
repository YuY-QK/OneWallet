import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/bootstrap/providers.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_data/ow_data.dart';
import 'package:ow_domain/ow_domain.dart';

import 'support.dart';

/// 只在"ethereum"链上返回 2 个 ETH 的假 EVM 适配器。
final class _FakeEvmAdapter implements ChainAdapter {
  @override
  ChainFamily get family => ChainFamily.evm;

  @override
  Future<Result<List<RawHolding>>> fetchHoldings(
    String address,
    ChainInfo chain,
  ) async => Ok([
    if (chain.id == 'ethereum')
      RawHolding(
        token: const NativeToken('ethereum'),
        amount: Decimal.parse('2'),
      ),
  ]);

  @override
  Future<Result<bool>> hasActivity(String address, ChainInfo chain) async =>
      const Ok(true);
}

final class _FakeRegistry implements AdapterRegistry {
  @override
  ChainAdapter chain(ChainFamily family) => _FakeEvmAdapter();

  @override
  ExchangeAdapter exchange(ExchangeId id) => throw UnimplementedError();
}

/// 任何币种都报 2000 的价格。
final class _FakePriceSource implements PriceSource {
  @override
  Future<Result<List<Price>>> fetchPrices(
    Set<Asset> assets,
    Quote quote,
  ) async => Ok([
    for (final a in assets)
      Price(
        assetId: a.id,
        quote: quote,
        price: Decimal.parse('2000'),
        updatedAt: DateTime.utc(2026, 11, 12),
      ),
  ]);

  @override
  Future<Result<Map<ContractToken, Asset>>> lookupContracts(
    Set<ContractToken> tokens,
  ) async => const Ok({});
}

/// 整条装配链路（不联网）：添加钱包 -> 同步 -> 总览汇总。
void main() {
  test('添加EVM地址_同步_总览汇总总额等于预期', () async {
    final db = OwDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secretStoreProvider.overrideWithValue(FakeSecretStore()),
        adapterRegistryProvider.overrideWithValue(_FakeRegistry()),
        priceSourceProvider.overrideWithValue(_FakePriceSource()),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });

    final expected = Decimal.parse('4000');
    final reached = Completer<PortfolioSummary>();
    container.listen(portfolioSummaryProvider, (_, next) {
      final summary = next.value;
      if (summary != null &&
          summary.total == expected &&
          !reached.isCompleted) {
        reached.complete(summary);
      }
    }, fireImmediately: true);

    final added = await container.read(addWalletAccountProvider)(
      name: '测试钱包',
      addresses: [
        AddressInput(raw: '0x1111111111111111111111111111111111111111'),
      ],
    );
    expect(added, isA<Ok<Account>>());
    final account = (added as Ok<Account>).value;

    // 单个账户同步：写入持仓。
    final synced = await container.read(syncAccountProvider)(account.id);
    expect(synced, isA<Ok<SyncAccountOutcome>>());
    expect(
      await container.read(holdingRepositoryProvider).watchAll().first,
      hasLength(1),
    );

    // 全量同步：刷新价格。汇总需要价格才能得出总额。
    final all = await container.read(syncAllAccountsProvider)();
    expect(all.succeededCount, 1);
    expect(all.failures, isEmpty);

    final summary = await reached.future.timeout(const Duration(seconds: 10));
    expect(summary.total, expected);
    expect(summary.unpricedCount, 0);
    expect(summary.byAccount, hasLength(1));
  });
}
