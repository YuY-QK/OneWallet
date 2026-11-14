import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/bootstrap/unsupported_adapters.dart';
import 'package:ow_domain/ow_domain.dart';

class _EvmStub implements ChainAdapter {
  @override
  ChainFamily get family => ChainFamily.evm;

  @override
  Future<Result<List<RawHolding>>> fetchHoldings(
    String address,
    ChainInfo chain,
  ) async => const Ok([]);

  @override
  Future<Result<bool>> hasActivity(String address, ChainInfo chain) async =>
      const Ok(false);
}

void main() {
  final credentials = ExchangeCredentials(
    apiKey: Sensitive(Uint8List.fromList([1, 2, 3])),
    apiSecret: Sensitive(Uint8List.fromList([4, 5, 6])),
  );

  test('占位链适配器_全部方法返回UnsupportedFailure', () async {
    const adapter = UnsupportedChainAdapter(ChainFamily.solana);
    expect(adapter.family, ChainFamily.solana);
    final holdings = await adapter.fetchHoldings('x', Chains.byId('ethereum'));
    expect((holdings as Err).failure, isA<UnsupportedFailure>());
    final activity = await adapter.hasActivity('x', Chains.byId('ethereum'));
    expect((activity as Err).failure, isA<UnsupportedFailure>());
  });

  test('占位交易所适配器_全部方法返回UnsupportedFailure', () async {
    for (final id in ExchangeId.values) {
      final adapter = UnsupportedExchangeAdapter(id);
      expect(adapter.id, id);
      expect(
        ((await adapter.verify(credentials)) as Err).failure,
        isA<UnsupportedFailure>(),
      );
      expect(
        ((await adapter.fetchHoldings(credentials)) as Err).failure,
        isA<UnsupportedFailure>(),
      );
      expect(
        ((await adapter.fetchDepositAddresses(credentials)) as Err).failure,
        isA<UnsupportedFailure>(),
      );
    }
    expect(
      const UnsupportedExchangeAdapter(ExchangeId.okx).needsPassphrase,
      isTrue,
    );
    expect(
      const UnsupportedExchangeAdapter(ExchangeId.binance).needsPassphrase,
      isFalse,
    );
  });

  test('注册表_EVM返回注入的适配器_其余家族与全部交易所是占位', () async {
    final evm = _EvmStub();
    final registry = AppAdapterRegistry(evm: evm);

    expect(registry.chain(ChainFamily.evm), same(evm));
    for (final f in ChainFamily.values.where((f) => f != ChainFamily.evm)) {
      final adapter = registry.chain(f);
      expect(adapter, isA<UnsupportedChainAdapter>());
      expect(adapter.family, f);
      final r = await adapter.fetchHoldings('x', Chains.byId('ethereum'));
      expect((r as Err).failure, isA<UnsupportedFailure>());
    }
    for (final id in ExchangeId.values) {
      expect(registry.exchange(id), isA<UnsupportedExchangeAdapter>());
    }
  });

  test('注册表_注入全部四类链适配器_各自返回对应实例', () {
    final evm = _EvmStub();
    final btc = _EvmStub();
    final sol = _EvmStub();
    final trx = _EvmStub();
    final registry = AppAdapterRegistry(
      evm: evm,
      bitcoin: btc,
      solana: sol,
      tron: trx,
    );
    expect(registry.chain(ChainFamily.evm), same(evm));
    expect(registry.chain(ChainFamily.bitcoin), same(btc));
    expect(registry.chain(ChainFamily.solana), same(sol));
    expect(registry.chain(ChainFamily.tron), same(trx));
  });
}
