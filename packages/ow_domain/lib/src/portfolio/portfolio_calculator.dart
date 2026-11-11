import 'package:decimal/decimal.dart';

import '../account/account.dart';
import '../asset/holding.dart';
import '../asset/holding_location.dart';
import '../asset/price.dart';
import '../asset/token_key.dart';
import 'holding_distribution.dart';
import 'portfolio_math.dart';
import 'portfolio_summary.dart';

/// 币种汇总的累加器（私有）。
final class _AssetAcc {
  _AssetAcc(this.displaySymbol);

  final String displaySymbol;
  Decimal amount = Decimal.zero;
  Decimal value = Decimal.zero;
}

/// 24 小时变化的累加器（私有）：在有理数上求和，最后一步才转回 `Decimal`。
final class _ChangeAcc {
  Fraction previous = Fraction.zero;
  bool hasPercent = false;

  /// 记入一笔估值为 [value]、24 小时涨跌百分比为 [percent] 的持仓。
  ///
  /// 前值 = 现值 / (1 + 百分比 / 100)。百分比缺失时按"无变化"计入；
  /// 百分比 ≤ −100 时分母为 0 或为负，没有意义，同样按"无变化"计入
  /// （此时不算作"有百分比"）。
  void add(Decimal value, Decimal? percent) {
    final minusAll = Decimal.fromInt(-100);
    if (percent == null || percent <= minusAll) {
      previous += Fraction.fromDecimal(value);
      return;
    }
    hasPercent = true;
    final factor =
        Fraction.one + Fraction.fromDecimal(percent) / Fraction.fromInt(100);
    previous += Fraction.fromDecimal(value) / factor;
  }

  /// 由现值合计 [total] 得出（变化金额，变化百分比）；无法计算时为 null。
  (Decimal, Decimal)? resolve(Decimal total) {
    if (!hasPercent || previous.isZero) return null;
    final delta = Fraction.fromDecimal(total) - previous;
    return (
      delta.toDecimal(),
      (delta / previous * Fraction.fromInt(100)).toDecimal(),
    );
  }
}

/// 总览汇总（PRD R7–R12），纯函数，不做任何 IO。
abstract final class PortfolioCalculator {
  /// 汇总全部持仓。
  ///
  /// 参与计算的持仓：所属账户在 [accounts] 中，且 `token.tokenKey` 不在
  /// [hiddenTokens] 中。账户不在 [accounts] 中的持仓被整体忽略（不计入总额、
  /// 切片、任何计数），因此 `byAccount` 的估值之和始终等于 `total`；
  /// [hiddenTokens] 中的持仓同样完全排除。
  ///
  /// 规则：
  /// - 估值 = 数量 × 价格。只有 `assetId` 非空且 [prices] 含该 assetId 的持仓
  ///   才有估值；没有估值的持仓不计入任何总额（R9）。
  /// - `unpricedCount`：没有估值的不同币种数，以 assetId 为准，assetId 为空
  ///   的以 `tokenKey` 为准。
  /// - R8：同一 assetId 跨链、跨账户合并为一个 [AssetSlice]；
  ///   `displaySymbol` 取输入顺序中第一条该币种持仓的 `displaySymbol`。
  /// - R11：[hideSmall] 为 true 时，合并后估值低于 [smallThreshold] 的币种不进
  ///   `byAsset`，计入 `hiddenSmallCount`，但仍计入总额与账户汇总。
  ///   [smallThreshold] 是"1 USD 折合当前计价货币"的值，由调用方换算；
  ///   [prices] 已是当前计价货币的价格。
  /// - `byAsset` 按估值降序，相同按 assetId 升序；`byAccount` 含 [accounts]
  ///   中的全部账户（估值 0 的也在），按估值降序，相同按账户名升序、再按 id。
  /// - `onChainTotal` 按持仓位置统计链上部分，`exchangeTotal` 为交易所部分，
  ///   二者之和等于 `total`。
  /// - 24 小时变化按"当前数量 × 24 小时前价格"估算，其中前价由
  ///   `Price.change24hPercent` 反推。缺百分比的持仓按"无变化"计入；
  ///   全部缺百分比或前值合计为 0 时，`change24h` 与 `change24hPercent` 为 null。
  ///
  /// 精度：除法在有理数上完成，最终四舍五入到 18 位小数（见 `ratioScale`）。
  /// 加法、乘法精确，不使用浮点数。
  static PortfolioSummary summarize({
    required List<Account> accounts,
    required List<Holding> holdings,
    required Map<String, Price> prices,
    required bool hideSmall,
    required Decimal smallThreshold,
    required Set<String> hiddenTokens,
  }) {
    final accountValue = {for (final a in accounts) a.id: Decimal.zero};
    final assets = <String, _AssetAcc>{};
    final unpriced = <String>{};
    final change = _ChangeAcc();
    var total = Decimal.zero;
    var onChain = Decimal.zero;
    var exchange = Decimal.zero;
    var anyValued = false;

    for (final h in holdings) {
      if (!accountValue.containsKey(h.accountId)) continue;
      if (hiddenTokens.contains(h.token.tokenKey)) continue;
      final assetId = h.assetId;
      final price = assetId == null ? null : prices[assetId];
      if (assetId == null || price == null) {
        // 加前缀避免 assetId 与 tokenKey 偶然同名。
        unpriced.add(assetId == null ? 't:${h.token.tokenKey}' : 'a:$assetId');
        continue;
      }
      final value = h.amount * price.price;
      anyValued = true;
      total += value;
      accountValue[h.accountId] = accountValue[h.accountId]! + value;
      switch (h.location) {
        case OnChainLocation():
          onChain += value;
        case ExchangeLocation():
          exchange += value;
      }
      final acc = assets.putIfAbsent(assetId, () => _AssetAcc(h.displaySymbol));
      acc.amount += h.amount;
      acc.value += value;
      change.add(value, price.change24hPercent);
    }

    final (slices, hiddenSmall) = _assetSlices(
      assets,
      hideSmall: hideSmall,
      smallThreshold: smallThreshold,
    );
    final accountSlices = _accountSlices(accounts, accountValue);
    final changeOrNull = anyValued ? change.resolve(total) : null;
    final change24h = changeOrNull?.$1;
    final change24hPercent = changeOrNull?.$2;

    return PortfolioSummary(
      total: total,
      change24h: change24h,
      change24hPercent: change24hPercent,
      unpricedCount: unpriced.length,
      hiddenSmallCount: hiddenSmall,
      byAsset: slices,
      byAccount: accountSlices,
      onChainTotal: onChain,
      exchangeTotal: exchange,
    );
  }

  /// 生成币种切片并按需隐藏小额；返回（切片，被隐藏的币种数）。
  static (List<AssetSlice>, int) _assetSlices(
    Map<String, _AssetAcc> assets, {
    required bool hideSmall,
    required Decimal smallThreshold,
  }) {
    var hiddenSmall = 0;
    final slices = <AssetSlice>[];
    for (final e in assets.entries) {
      if (hideSmall && e.value.value < smallThreshold) {
        hiddenSmall++;
        continue;
      }
      slices.add(
        AssetSlice(
          assetId: e.key,
          displaySymbol: e.value.displaySymbol,
          amount: e.value.amount,
          value: e.value.value,
        ),
      );
    }
    slices.sort((a, b) {
      final c = b.value.compareTo(a.value);
      return c != 0 ? c : a.assetId.compareTo(b.assetId);
    });
    return (slices, hiddenSmall);
  }

  /// 生成账户切片：含全部传入账户，估值降序，相同按名称、再按 id 升序。
  static List<AccountSlice> _accountSlices(
    List<Account> accounts,
    Map<String, Decimal> accountValue,
  ) {
    final names = {for (final a in accounts) a.id: a.name};
    final slices = [
      for (final e in accountValue.entries)
        AccountSlice(accountId: e.key, value: e.value),
    ];
    slices.sort((a, b) {
      final c = b.value.compareTo(a.value);
      if (c != 0) return c;
      final n = names[a.accountId]!.compareTo(names[b.accountId]!);
      return n != 0 ? n : a.accountId.compareTo(b.accountId);
    });
    return slices;
  }

  /// 某个币种在各账户、各位置的分布（P09），按估值降序。
  ///
  /// 只统计 `assetId == assetId` 且 `token.tokenKey` 不在 [hiddenTokens] 中的
  /// 持仓；同一账户、同一位置的多笔持仓合并为一行。不检查账户是否存在，
  /// 调用方应只传入有效账户的持仓。
  ///
  /// 占比（`share`）是该行估值占本币种全部行估值之和的百分数；总估值为 0
  /// 或该币种没有价格时为 0（此时 `value` 为 null）。
  /// 排序：估值降序（无估值排最后）；相同按数量降序，再按账户 id 升序。
  static List<DistributionEntry> distributionOf({
    required String assetId,
    required List<Holding> holdings,
    required Map<String, Price> prices,
    Set<String> hiddenTokens = const {},
  }) {
    final price = prices[assetId];
    final merged = <(String, HoldingLocation), Decimal>{};
    for (final h in holdings) {
      if (h.assetId != assetId) continue;
      if (hiddenTokens.contains(h.token.tokenKey)) continue;
      final key = (h.accountId, h.location);
      merged[key] = (merged[key] ?? Decimal.zero) + h.amount;
    }
    final values = {
      for (final e in merged.entries)
        e.key: price == null ? null : e.value * price.price,
    };
    var total = Decimal.zero;
    for (final v in values.values) {
      if (v != null) total += v;
    }
    final entries = [
      for (final e in merged.entries)
        DistributionEntry(
          accountId: e.key.$1,
          location: e.key.$2,
          amount: e.value,
          value: values[e.key],
          share: shareOf(values[e.key] ?? Decimal.zero, total),
        ),
    ];
    entries.sort((a, b) {
      final av = a.value;
      final bv = b.value;
      if (av != null && bv != null) {
        final c = bv.compareTo(av);
        if (c != 0) return c;
      } else if (av != null || bv != null) {
        return av == null ? 1 : -1;
      }
      final c = b.amount.compareTo(a.amount);
      if (c != 0) return c;
      final i = a.accountId.compareTo(b.accountId);
      return i != 0
          ? i
          : a.location.toString().compareTo(b.location.toString());
    });
    return entries;
  }
}
