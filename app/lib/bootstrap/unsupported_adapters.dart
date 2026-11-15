import 'package:ow_domain/ow_domain.dart';

/// 尚未实现的链家族适配器：所有方法返回 [UnsupportedFailure]。
///
/// TODO(M2-01..03)：Bitcoin、Solana、Tron 适配器完成后替换。
final class UnsupportedChainAdapter implements ChainAdapter {
  const UnsupportedChainAdapter(this.family);

  @override
  final ChainFamily family;

  @override
  Future<Result<List<RawHolding>>> fetchHoldings(
    String address,
    ChainInfo chain,
  ) async => Err(UnsupportedFailure.notIntegrated('尚未支持的链家族：${family.name}'));

  @override
  Future<Result<bool>> hasActivity(String address, ChainInfo chain) async =>
      Err(UnsupportedFailure.notIntegrated('尚未支持的链家族：${family.name}'));
}

/// 尚未实现的交易所适配器：所有方法返回 [UnsupportedFailure]。
///
/// TODO(M2-06..09)：Binance、OKX、Bybit、Bitget 适配器完成后替换。
final class UnsupportedExchangeAdapter implements ExchangeAdapter {
  const UnsupportedExchangeAdapter(this.id);

  @override
  final ExchangeId id;

  @override
  bool get needsPassphrase => id == ExchangeId.okx || id == ExchangeId.bitget;

  UnsupportedFailure get _failure =>
      UnsupportedFailure.notIntegrated('尚未支持的交易所：${id.name}');

  @override
  Future<Result<CredentialCheck>> verify(ExchangeCredentials c) async =>
      Err(_failure);

  @override
  Future<Result<List<(ExchangeSubAccount, RawHolding)>>> fetchHoldings(
    ExchangeCredentials c,
  ) async => Err(_failure);

  @override
  Future<Result<List<DepositAddress>>> fetchDepositAddresses(
    ExchangeCredentials c,
  ) async => Err(_failure);
}

/// 把已实现的适配器接入 [AdapterRegistry]，其余家族与交易所返回占位适配器。
final class AppAdapterRegistry implements AdapterRegistry {
  AppAdapterRegistry({
    required this._evm,
    this._bitcoin,
    this._solana,
    this._tron,
    this._binance,
    this._okx,
    this._bybit,
    this._bitget,
  });

  final ChainAdapter _evm;
  final ChainAdapter? _bitcoin;
  final ChainAdapter? _solana;
  final ChainAdapter? _tron;
  final ExchangeAdapter? _binance;
  final ExchangeAdapter? _okx;
  final ExchangeAdapter? _bybit;
  final ExchangeAdapter? _bitget;

  @override
  ChainAdapter chain(ChainFamily family) => switch (family) {
    ChainFamily.evm => _evm,
    ChainFamily.bitcoin => _bitcoin ?? UnsupportedChainAdapter(family),
    ChainFamily.solana => _solana ?? UnsupportedChainAdapter(family),
    ChainFamily.tron => _tron ?? UnsupportedChainAdapter(family),
  };

  @override
  ExchangeAdapter exchange(ExchangeId id) => switch (id) {
    ExchangeId.binance => _binance ?? UnsupportedExchangeAdapter(id),
    ExchangeId.okx => _okx ?? UnsupportedExchangeAdapter(id),
    ExchangeId.bybit => _bybit ?? UnsupportedExchangeAdapter(id),
    ExchangeId.bitget => _bitget ?? UnsupportedExchangeAdapter(id),
  };
}
