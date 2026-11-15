import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:ow_domain/ow_domain.dart';

/// 某币种在某个子账户内的明细。
@immutable
final class AssetSubAccountDetail {
  const AssetSubAccountDetail({required this.sub, required this.amount});

  final ExchangeSubAccount sub;
  final Decimal amount;
}

/// P08 资产分段的一行：按币种汇总。
@immutable
final class ExchangeAssetRow {
  const ExchangeAssetRow({
    required this.key,
    required this.symbol,
    required this.amount,
    required this.details,
    this.value,
  });

  /// 汇总键：标准币种 id；无法识别的代币用代币键。
  final String key;
  final String symbol;
  final Decimal amount;

  /// 估值；没有价格时为 null。
  final Decimal? value;
  final List<AssetSubAccountDetail> details;
}

/// 某子账户内的某个币种明细。
@immutable
final class SubAccountAssetDetail {
  const SubAccountAssetDetail({
    required this.key,
    required this.symbol,
    required this.amount,
    this.value,
  });

  final String key;
  final String symbol;
  final Decimal amount;
  final Decimal? value;
}

/// P08 子账户分段的一行：按子账户汇总。
@immutable
final class ExchangeSubAccountRow {
  const ExchangeSubAccountRow({
    required this.sub,
    required this.assets,
    this.value,
  });

  final ExchangeSubAccount sub;
  final List<SubAccountAssetDetail> assets;
  final Decimal? value;
}

/// API Key 状态。
enum ApiKeyStatus {
  /// 正常 · 只读。
  normalReadOnly,

  /// 已失效（接口返回未授权或已过期）。
  expired,
}

/// P08 的页面状态。
enum ExchangeDetailStatus {
  /// 还没有成功同步过，正在等待第一次同步结果。
  loading,

  /// 有资产可显示。
  normal,

  /// 没有可显示的资产。
  noAssets,

  /// API Key 已失效。
  keyExpired,
}

/// P08 的视图模型。
@immutable
final class ExchangeDetailView {
  const ExchangeDetailView({
    required this.account,
    required this.status,
    required this.apiKeyStatus,
    required this.total,
    required this.priced,
    required this.unpriced,
    required this.subAccounts,
    required this.depositAddresses,
    required this.notIncluded,
    this.failure,
    this.lastSuccessAt,
  });

  final Account account;
  final ExchangeDetailStatus status;
  final ApiKeyStatus apiKeyStatus;
  final Decimal total;

  /// 有估值的币种，按估值降序。
  final List<ExchangeAssetRow> priced;

  /// 无价格或无法识别的币种（折叠显示）。
  final List<ExchangeAssetRow> unpriced;

  /// 子账户列表（现货、资金、合约、理财等）。
  final List<ExchangeSubAccountRow> subAccounts;

  /// 从交易所读取到的充值地址（只读）。
  final List<DepositAddress> depositAddresses;

  /// 未包含的产品列表（静态 notIncluded 与动态 lastSkipped 合并）。
  final List<String> notIncluded;

  /// 最近一次同步失败的记录；最近一次成功则为 null。
  final SyncRecord? failure;

  /// 上次成功同步的时间；从未成功为 null。
  final DateTime? lastSuccessAt;
}

/// 由原始数据推出 [ExchangeDetailView]。纯函数。
ExchangeDetailView buildExchangeDetail({
  required Account account,
  required List<Holding> holdings,
  required Map<String, Price> prices,
  required SyncRecord? record,
  required DateTime? lastSuccessAt,
  required bool syncing,
  List<String> notIncluded = const [],
  List<String> lastSkipped = const [],
  List<DepositAddress> depositAddresses = const [],
}) {
  final mine = [
    for (final h in holdings)
      if (h.accountId == account.id && h.location is ExchangeLocation) h,
  ];

  // 按币种聚合：key -> List<Holding>
  final byAssetKey = <String, List<Holding>>{};
  for (final h in mine) {
    final priced = h.assetId != null && prices.containsKey(h.assetId);
    final key = priced ? h.assetId! : 'token:${h.token.tokenKey}';
    byAssetKey.putIfAbsent(key, () => []).add(h);
  }

  final priced = <ExchangeAssetRow>[];
  final unpriced = <ExchangeAssetRow>[];
  var total = Decimal.zero;

  for (final entry in byAssetKey.entries) {
    final list = entry.value;
    final first = list.first;
    final symbol = first.assetId ?? first.displaySymbol;

    var sumAmount = Decimal.zero;
    final details = <AssetSubAccountDetail>[];
    for (final h in list) {
      sumAmount += h.amount;
      final sub = (h.location as ExchangeLocation).sub;
      details.add(AssetSubAccountDetail(sub: sub, amount: h.amount));
    }

    final price = first.assetId != null ? prices[first.assetId!] : null;
    final value = price != null ? sumAmount * price.price : null;

    final row = ExchangeAssetRow(
      key: entry.key,
      symbol: symbol,
      amount: sumAmount,
      value: value,
      details: details,
    );

    if (value != null) {
      priced.add(row);
      total += value;
    } else {
      unpriced.add(row);
    }
  }

  // 有价格的按估值降序
  priced.sort(
    (a, b) => (b.value ?? Decimal.zero).compareTo(a.value ?? Decimal.zero),
  );
  unpriced.sort((a, b) => a.symbol.compareTo(b.symbol));

  // 按子账户聚合
  final bySub = <ExchangeSubAccount, List<Holding>>{};
  for (final h in mine) {
    final sub = (h.location as ExchangeLocation).sub;
    bySub.putIfAbsent(sub, () => []).add(h);
  }

  // 固定的子账户顺序展示
  const subOrder = [
    ExchangeSubAccount.spot,
    ExchangeSubAccount.funding,
    ExchangeSubAccount.futures,
    ExchangeSubAccount.margin,
    ExchangeSubAccount.earn,
    ExchangeSubAccount.other,
  ];

  final subAccountRows = <ExchangeSubAccountRow>[];
  for (final sub in subOrder) {
    final list = bySub[sub];
    if (list == null || list.isEmpty) continue;

    var subTotal = Decimal.zero;
    final assetDetails = <SubAccountAssetDetail>[];

    for (final h in list) {
      final priced = h.assetId != null && prices.containsKey(h.assetId);
      final key = priced ? h.assetId! : 'token:${h.token.tokenKey}';
      final symbol = h.assetId ?? h.displaySymbol;
      final price = h.assetId != null ? prices[h.assetId!] : null;
      final value = price != null ? h.amount * price.price : null;
      if (value != null) {
        subTotal += value;
      }
      assetDetails.add(
        SubAccountAssetDetail(
          key: key,
          symbol: symbol,
          amount: h.amount,
          value: value,
        ),
      );
    }

    subAccountRows.add(
      ExchangeSubAccountRow(sub: sub, assets: assetDetails, value: subTotal),
    );
  }

  // 检查 API Key 状态
  final isKeyFailure =
      record != null &&
      record.status == SyncStatus.failed &&
      (record.failureType == 'unauthorized' ||
          record.failureType == 'key_expired' ||
          record.failureType == 'UnauthorizedFailure' ||
          record.failureType == 'KeyExpiredFailure');

  final apiKeyStatus = isKeyFailure
      ? ApiKeyStatus.expired
      : ApiKeyStatus.normalReadOnly;

  // 综合页面状态
  final ExchangeDetailStatus status;
  if (syncing && lastSuccessAt == null && record == null) {
    status = ExchangeDetailStatus.loading;
  } else if (apiKeyStatus == ApiKeyStatus.expired) {
    status = ExchangeDetailStatus.keyExpired;
  } else if (priced.isEmpty && unpriced.isEmpty) {
    status = ExchangeDetailStatus.noAssets;
  } else {
    status = ExchangeDetailStatus.normal;
  }

  // 合并未包含清单并去重
  final mergedNotIncluded = <String>{...notIncluded, ...lastSkipped}.toList();

  return ExchangeDetailView(
    account: account,
    status: status,
    apiKeyStatus: apiKeyStatus,
    total: total,
    priced: priced,
    unpriced: unpriced,
    subAccounts: subAccountRows,
    depositAddresses: depositAddresses,
    notIncluded: mergedNotIncluded,
    failure: record?.status == SyncStatus.failed ? record : null,
    lastSuccessAt: lastSuccessAt,
  );
}
