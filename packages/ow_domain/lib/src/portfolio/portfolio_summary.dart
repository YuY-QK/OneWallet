import 'package:decimal/decimal.dart';

import '../asset/holding.dart';
import '../core/equality.dart';

// 本文件只定义类型；计算见 portfolio_calculator.dart。

/// 一笔持仓及其估值。
final class ValuedHolding {
  const ValuedHolding({required this.holding, this.value});

  final Holding holding;

  /// 以当前计价货币表示的估值；没有价格时为 null（R9）。
  final Decimal? value;

  @override
  bool operator ==(Object other) =>
      other is ValuedHolding &&
      other.holding == holding &&
      other.value == value;

  @override
  int get hashCode => Object.hash(holding, value);
}

/// 按币种汇总的一行（P02"按币种"分布）。只包含有估值的标准币种。
final class AssetSlice {
  const AssetSlice({
    required this.assetId,
    required this.displaySymbol,
    required this.amount,
    required this.value,
  });

  final String assetId;
  final String displaySymbol;

  /// 全部账户、全部位置中该币种的数量之和。
  final Decimal amount;

  /// 以当前计价货币表示的估值。
  final Decimal value;

  @override
  bool operator ==(Object other) =>
      other is AssetSlice &&
      other.assetId == assetId &&
      other.displaySymbol == displaySymbol &&
      other.amount == amount &&
      other.value == value;

  @override
  int get hashCode => Object.hash(assetId, displaySymbol, amount, value);
}

/// 按账户汇总的一行（P02"按账户"分布）。
final class AccountSlice {
  const AccountSlice({required this.accountId, required this.value});

  final String accountId;

  /// 该账户有估值部分的合计。
  final Decimal value;

  @override
  bool operator ==(Object other) =>
      other is AccountSlice &&
      other.accountId == accountId &&
      other.value == value;

  @override
  int get hashCode => Object.hash(accountId, value);
}

/// 总览所需的全部汇总结果（PRD R7–R12）。
final class PortfolioSummary {
  /// [byAsset]、[byAccount] 会被复制为不可修改的列表。
  PortfolioSummary({
    required this.total,
    required this.unpricedCount,
    required this.hiddenSmallCount,
    required List<AssetSlice> byAsset,
    required List<AccountSlice> byAccount,
    required this.onChainTotal,
    required this.exchangeTotal,
    this.change24h,
    this.change24hPercent,
  }) : byAsset = List.unmodifiable(byAsset),
       byAccount = List.unmodifiable(byAccount);

  /// 有估值部分的总额，不含无价格的币种（R9）。
  final Decimal total;

  /// 24 小时变化金额；无法计算时为 null。
  final Decimal? change24h;

  /// 24 小时变化百分比；无法计算时为 null。
  final Decimal? change24hPercent;

  /// 无估值的币种数（R9）。
  final int unpricedCount;

  /// 因小额隐藏而未列出的币种数（R11）。
  final int hiddenSmallCount;

  /// 按估值降序。
  final List<AssetSlice> byAsset;
  final List<AccountSlice> byAccount;
  final Decimal onChainTotal;
  final Decimal exchangeTotal;

  @override
  bool operator ==(Object other) =>
      other is PortfolioSummary &&
      other.total == total &&
      other.change24h == change24h &&
      other.change24hPercent == change24hPercent &&
      other.unpricedCount == unpricedCount &&
      other.hiddenSmallCount == hiddenSmallCount &&
      listEquals(other.byAsset, byAsset) &&
      listEquals(other.byAccount, byAccount) &&
      other.onChainTotal == onChainTotal &&
      other.exchangeTotal == exchangeTotal;

  @override
  int get hashCode => Object.hash(
    total,
    change24h,
    change24hPercent,
    unpricedCount,
    hiddenSmallCount,
    Object.hashAll(byAsset),
    Object.hashAll(byAccount),
    onChainTotal,
    exchangeTotal,
  );
}
