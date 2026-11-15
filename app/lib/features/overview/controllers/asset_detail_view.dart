import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:ow_pricing/ow_pricing.dart';

/// 某账户某位置对该币种的持有明细。
@immutable
final class AssetDistributionItem {
  const AssetDistributionItem({
    required this.account,
    required this.location,
    required this.amount,
    required this.share,
    this.value,
  });

  final Account account;
  final HoldingLocation location;
  final Decimal amount;

  /// 该行估值；若币种无报价则为 null。
  final Decimal? value;

  /// 该行估值（或无估值时按数量）占总额的百分比，例如 53 表示 53%。
  final Decimal share;
}

/// 该币种在某条链上的合约地址。
@immutable
final class AssetContractItem {
  const AssetContractItem({
    required this.chainId,
    required this.chainName,
    required this.contract,
  });

  final String chainId;
  final String chainName;
  final String contract;
}

/// P09 币种详情的视图模型。
@immutable
final class AssetDetailView {
  const AssetDetailView({
    required this.assetId,
    required this.symbol,
    required this.name,
    required this.totalAmount,
    required this.distributions,
    required this.contracts,
    this.price,
    this.totalValue,
  });

  final String assetId;
  final String symbol;
  final String name;

  /// 当前价格；若无报价则为 null。
  final Price? price;

  /// 全账户持有总量。
  final Decimal totalAmount;

  /// 全账户总估值；若无价格则为 null。
  final Decimal? totalValue;

  /// 各账户与位置的分布明细，按估值/数量降序。
  final List<AssetDistributionItem> distributions;

  /// 各链合约地址列表，按 Chains 标准顺序排列。
  final List<AssetContractItem> contracts;
}

/// 由仓储数据计算 [AssetDetailView]。纯函数。
AssetDetailView buildAssetDetail({
  required String assetId,
  required AssetCatalog catalog,
  required List<Account> accounts,
  required List<Holding> holdings,
  required Map<String, Price> prices,
  Set<String> hiddenTokens = const {},
  List<CatalogContract> builtInContracts = const [],
}) {
  final asset = catalog.byId(assetId);
  final displaySymbol =
      asset?.symbol ??
      holdings
          .where((h) => h.assetId == assetId)
          .map((h) => h.displaySymbol)
          .firstOrNull ??
      assetId;
  final displayName = asset?.name ?? displaySymbol;
  final price = prices[assetId];

  // 1. 使用 PortfolioCalculator.distributionOf 计算各账户分布
  final rawEntries = PortfolioCalculator.distributionOf(
    assetId: assetId,
    holdings: holdings,
    prices: prices,
    hiddenTokens: hiddenTokens,
  );

  final accountsById = {for (final a in accounts) a.id: a};
  final distributions = <AssetDistributionItem>[];
  var totalAmount = Decimal.zero;
  for (final e in rawEntries) {
    final account = accountsById[e.accountId];
    if (account == null) continue;
    totalAmount += e.amount;
    distributions.add(
      AssetDistributionItem(
        account: account,
        location: e.location,
        amount: e.amount,
        value: e.value,
        share: e.share,
      ),
    );
  }

  final totalValue = price == null ? null : totalAmount * price.price;

  // 2. 收集各链合约地址
  final contractMap = <String, String>{};
  for (final c in builtInContracts) {
    if (c.asset.id == assetId) {
      contractMap[c.token.chainId] = c.token.contract;
    }
  }
  for (final h in holdings) {
    if (h.assetId == assetId && h.token is ContractToken) {
      final ct = h.token as ContractToken;
      contractMap.putIfAbsent(ct.chainId, () => ct.contract);
    }
  }

  final chainIndex = {
    for (var i = 0; i < Chains.all.length; i++) Chains.all[i].id: i,
  };
  final contractList =
      [
        for (final e in contractMap.entries)
          AssetContractItem(
            chainId: e.key,
            chainName: Chains.tryById(e.key)?.name ?? e.key,
            contract: e.value,
          ),
      ]..sort((a, b) {
        final ia = chainIndex[a.chainId] ?? 999;
        final ib = chainIndex[b.chainId] ?? 999;
        final c = ia.compareTo(ib);
        return c != 0 ? c : a.chainId.compareTo(b.chainId);
      });

  return AssetDetailView(
    assetId: assetId,
    symbol: displaySymbol,
    name: displayName,
    price: price,
    totalAmount: totalAmount,
    totalValue: totalValue,
    distributions: distributions,
    contracts: contractList,
  );
}
