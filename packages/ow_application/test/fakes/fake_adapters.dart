import 'dart:async';

import 'package:ow_domain/ow_domain.dart';

/// 按 (地址, 链) 预设返回值的链适配器，记录调用与最大并发数。
final class FakeChainAdapter implements ChainAdapter {
  FakeChainAdapter(this.family);

  @override
  final ChainFamily family;

  /// 键为 `地址|链 id`；值按调用顺序依次返回，用完后重复最后一个。
  final responses = <String, List<Result<List<RawHolding>>>>{};

  /// 每次调用记录 `地址|链 id`。
  final calls = <String>[];

  /// 设置后，每次调用先等它完成，用于观察并发。
  Completer<void>? gate;

  /// 每次调用开始时回调，测试可在此触发取消等动作。
  void Function(String key)? onCall;

  int _inFlight = 0;
  int maxInFlight = 0;

  void respond(
    String address,
    String chainId,
    List<Result<List<RawHolding>>> r,
  ) {
    responses['$address|$chainId'] = r;
  }

  @override
  Future<Result<List<RawHolding>>> fetchHoldings(
    String address,
    ChainInfo chain,
  ) async {
    final key = '$address|${chain.id}';
    calls.add(key);
    onCall?.call(key);
    _inFlight++;
    if (_inFlight > maxInFlight) maxInFlight = _inFlight;
    try {
      final g = gate;
      if (g != null) await g.future;
      final list = responses[key];
      if (list == null || list.isEmpty) return const Ok([]);
      final callIndex = calls.where((c) => c == key).length - 1;
      return list[callIndex < list.length ? callIndex : list.length - 1];
    } finally {
      _inFlight--;
    }
  }

  @override
  Future<Result<bool>> hasActivity(String address, ChainInfo chain) async =>
      const Ok(false);
}

final class FakeExchangeAdapter implements ExchangeAdapter {
  FakeExchangeAdapter(this.id, {this.needsPassphrase = false});

  @override
  final ExchangeId id;

  @override
  final bool needsPassphrase;

  Result<CredentialCheck> verifyResult = const Ok(
    CredentialCheck(permission: KeyPermission.readOnly),
  );

  final List<ExchangeCredentials> verifyCalls = [];
  final List<ExchangeCredentials> fetchHoldingsCalls = [];

  List<Result<List<(ExchangeSubAccount, RawHolding)>>> holdingsResponses = [];
  List<Result<List<DepositAddress>>> depositAddressesResponses = [];

  @override
  Future<Result<CredentialCheck>> verify(ExchangeCredentials c) async {
    verifyCalls.add(c);
    return verifyResult;
  }

  @override
  Future<Result<List<(ExchangeSubAccount, RawHolding)>>> fetchHoldings(
    ExchangeCredentials c,
  ) async {
    fetchHoldingsCalls.add(c);
    if (holdingsResponses.isEmpty) return const Ok([]);
    final callIndex = fetchHoldingsCalls.length - 1;
    return holdingsResponses[callIndex < holdingsResponses.length
        ? callIndex
        : holdingsResponses.length - 1];
  }

  @override
  Future<Result<List<DepositAddress>>> fetchDepositAddresses(
    ExchangeCredentials c,
  ) async {
    if (depositAddressesResponses.isEmpty) return const Ok([]);
    return depositAddressesResponses.removeAt(0);
  }
}

final class FakeAdapterRegistry implements AdapterRegistry {
  FakeAdapterRegistry({
    Map<ChainFamily, FakeChainAdapter>? chains,
    Map<ExchangeId, FakeExchangeAdapter>? exchanges,
  }) : chains =
           chains ??
           {for (final f in ChainFamily.values) f: FakeChainAdapter(f)},
       exchanges =
           exchanges ??
           {
             for (final id in ExchangeId.values)
               id: FakeExchangeAdapter(
                 id,
                 needsPassphrase:
                     id == ExchangeId.okx || id == ExchangeId.bitget,
               ),
           };

  final Map<ChainFamily, FakeChainAdapter> chains;
  final Map<ExchangeId, FakeExchangeAdapter> exchanges;

  FakeChainAdapter get evm => _of(ChainFamily.evm);
  FakeExchangeAdapter exchangeFake(ExchangeId id) => exchanges[id]!;

  FakeChainAdapter _of(ChainFamily f) =>
      chains[f] ?? (throw StateError('缺少 $f 的假适配器'));

  @override
  ChainAdapter chain(ChainFamily family) => _of(family);

  @override
  ExchangeAdapter exchange(ExchangeId id) =>
      exchanges[id] ?? (throw StateError('缺少 $id 的假适配器'));
}

/// 只认识预先登记的代币的映射表。
final class FakeAssetCatalog implements AssetCatalog {
  final byToken = <TokenRef, Asset>{};
  final byAssetId = <String, Asset>{};

  void register(TokenRef token, Asset asset) {
    byToken[token] = asset;
    byAssetId[asset.id] = asset;
  }

  @override
  Asset? resolve(TokenRef token) => byToken[token];

  @override
  Asset? byId(String assetId) => byAssetId[assetId];

  @override
  Asset? byPriceId(String priceId) {
    for (final a in byAssetId.values) {
      if (a.priceId == priceId) return a;
    }
    return null;
  }
}

final class FakePriceSource implements PriceSource {
  /// 按计价货币返回的结果；未设置时返回空列表。
  final pricesByQuote = <Quote, Result<List<Price>>>{};
  Result<Map<ContractToken, Asset>> lookupResult = const Ok({});

  final fetchCalls = <(Set<Asset>, Quote)>[];
  final lookupCalls = <Set<ContractToken>>[];

  @override
  Future<Result<List<Price>>> fetchPrices(
    Set<Asset> assets,
    Quote quote,
  ) async {
    fetchCalls.add((assets, quote));
    return pricesByQuote[quote] ?? const Ok([]);
  }

  @override
  Future<Result<Map<ContractToken, Asset>>> lookupContracts(
    Set<ContractToken> tokens,
  ) async {
    lookupCalls.add(tokens);
    return lookupResult;
  }
}
