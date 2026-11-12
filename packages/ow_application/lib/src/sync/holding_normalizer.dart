import 'package:decimal/decimal.dart';
import 'package:ow_domain/ow_domain.dart';

import 'persistent_asset_catalog.dart';

/// 一笔待归一化的原始余额及其位置。
typedef LocatedRawHolding = ({HoldingLocation location, RawHolding raw});

/// 归一化的结果。
final class NormalizedHoldings {
  /// [holdings] 与 [assets] 会被复制为不可修改的集合。
  NormalizedHoldings({
    required List<Holding> holdings,
    required Set<Asset> assets,
  }) : holdings = List.unmodifiable(holdings),
       assets = Set.unmodifiable(assets);

  /// 归一化后的持仓，已丢弃数量为 0 的条目。
  final List<Holding> holdings;

  /// [holdings] 涉及的全部标准币种，供随后拉取价格。
  ///
  /// 其中可能有经 `PriceSource.lookupContracts` 查到、`AssetCatalog.byId`
  /// 查不到的币种，所以要随结果带出，而不是只给 assetId。
  final Set<Asset> assets;
}

/// `RawHolding` → `Holding` 的归一化（PRD R8、TECH_DESIGN 5.3）。
///
/// 查找顺序：币种目录 [AssetCatalog.resolve]（内置表，装配了 `PersistentAssetCatalog`
/// 时还包括库中已存的）→ 对仍未识别的合约代币批量调用 [PriceSource.lookupContracts]
/// → 未识别（`assetId` 为 null）。
///
/// 传入 [recorder] 时，查到的币种与"合约 → 币种"对应会被记住（存库），
/// 之后同一合约由目录直接识别，不再向价格源查询。
final class HoldingNormalizer {
  const HoldingNormalizer({
    required this._catalog,
    required this._priceSource,
    this._recorder,
  });

  final AssetCatalog _catalog;
  final PriceSource _priceSource;
  final ContractAssetRecorder? _recorder;

  /// 把 [raw] 归一化为 [accountId] 名下、更新时间为 [updatedAt] 的持仓。
  ///
  /// 不会失败：`lookupContracts` 失败时这些代币按未识别处理，不影响同步。
  /// 未识别代币的 `displaySymbol` 取 `symbolHint`，没有时取缩略的合约地址。
  Future<NormalizedHoldings> call({
    required String accountId,
    required List<LocatedRawHolding> raw,
    required DateTime updatedAt,
  }) async {
    final kept = raw.where((e) => e.raw.amount != Decimal.zero).toList();
    final resolved = <TokenRef, Asset>{};
    final unresolved = <ContractToken>{};
    for (final e in kept) {
      final token = e.raw.token;
      final asset = _catalog.resolve(token);
      if (asset != null) {
        resolved[token] = asset;
      } else if (token is ContractToken) {
        unresolved.add(token);
      }
    }
    resolved.addAll(await _lookup(unresolved));

    final holdings = [
      for (final e in kept)
        Holding(
          accountId: accountId,
          location: e.location,
          token: e.raw.token,
          assetId: resolved[e.raw.token]?.id,
          displaySymbol:
              resolved[e.raw.token]?.symbol ?? _fallbackSymbol(e.raw),
          amount: e.raw.amount,
          updatedAt: updatedAt,
        ),
    ];
    final assets = {for (final e in kept) ?resolved[e.raw.token]};
    return NormalizedHoldings(holdings: holdings, assets: assets);
  }

  Future<Map<ContractToken, Asset>> _lookup(Set<ContractToken> tokens) async {
    if (tokens.isEmpty) return const {};
    final result = await _priceSource.lookupContracts(tokens);
    final found = result.when<Map<ContractToken, Asset>>(
      ok: (found) => found,
      err: (_) => const {},
    );
    final recorder = _recorder;
    if (found.isEmpty || recorder == null) return found;
    return recorder.remember(found);
  }

  static String _fallbackSymbol(RawHolding raw) {
    final hint = raw.symbolHint?.trim();
    if (hint != null && hint.isNotEmpty) return hint;
    return switch (raw.token) {
      ContractToken(:final contract) => AddressCodec.shorten(contract),
      NativeToken(:final chainId) =>
        Chains.tryById(chainId)?.nativeSymbol ?? chainId,
      ExchangeToken(:final symbol) => symbol,
    };
  }
}
