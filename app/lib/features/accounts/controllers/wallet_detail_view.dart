import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:ow_domain/ow_domain.dart';

/// 某币种在一条链上的明细。
@immutable
final class AssetChainDetail {
  const AssetChainDetail({required this.chainId, required this.amount});

  final String chainId;
  final Decimal amount;
}

/// P07 资产分段的一行：按币种汇总。
@immutable
final class WalletAssetRow {
  const WalletAssetRow({
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
  final List<AssetChainDetail> details;
}

/// P07 地址分段的一行。
@immutable
final class WalletAddressRow {
  const WalletAddressRow({required this.address, this.value});

  final WatchAddress address;

  /// 该地址上有估值部分的合计。
  final Decimal? value;
}

/// P07 的页面状态。
enum WalletDetailStatus {
  /// 还没有成功同步过，正在等待第一次同步结果。
  loading,

  /// 有资产可显示。
  normal,

  /// 没有可显示的资产。
  noAssets,
}

/// P07 的视图模型。
@immutable
final class WalletDetailView {
  const WalletDetailView({
    required this.account,
    required this.status,
    required this.total,
    required this.priced,
    required this.unpriced,
    required this.addresses,
    this.failure,
    this.lastSuccessAt,
  });

  final Account account;
  final WalletDetailStatus status;
  final Decimal total;

  /// 有估值的币种，按估值降序。
  final List<WalletAssetRow> priced;

  /// 无价格或无法识别的币种（折叠显示）。
  final List<WalletAssetRow> unpriced;
  final List<WalletAddressRow> addresses;

  /// 最近一次同步失败的记录；最近一次成功则为 null。
  final SyncRecord? failure;

  /// 上次成功同步的时间（持久化的账户级记录，不受同步记录裁剪影响）；从未成功为 null。
  final DateTime? lastSuccessAt;
}

/// 由原始数据推出 [WalletDetailView]。纯函数。
WalletDetailView buildWalletDetail({
  required Account account,
  required List<WatchAddress> addresses,
  required List<Holding> holdings,
  required Map<String, Price> prices,
  required SyncRecord? record,
  required DateTime? lastSuccessAt,
  required bool syncing,
}) {
  final mine = [
    for (final h in holdings)
      if (h.accountId == account.id) h,
  ];
  final rows = _assetRows(mine, prices);
  final priced = [
    for (final r in rows)
      if (r.value != null) r,
  ]..sort((a, b) => b.value!.compareTo(a.value!));
  final unpriced = [
    for (final r in rows)
      if (r.value == null) r,
  ];
  final total = priced.fold(Decimal.zero, (sum, r) => sum + r.value!);
  final failed = record != null && record.status == SyncStatus.failed;
  final WalletDetailStatus status;
  // 加载中：还没成功过，且正在同步，或最近没有失败（即第一次同步尚未得出结果）。
  if (lastSuccessAt == null && mine.isEmpty && (syncing || !failed)) {
    status = WalletDetailStatus.loading;
  } else if (priced.isEmpty && unpriced.isEmpty) {
    status = WalletDetailStatus.noAssets;
  } else {
    status = WalletDetailStatus.normal;
  }
  return WalletDetailView(
    account: account,
    status: status,
    total: total,
    priced: priced,
    unpriced: unpriced,
    addresses: _addressRows(addresses, mine, prices),
    failure: failed ? record : null,
    lastSuccessAt: lastSuccessAt,
  );
}

Decimal? _valueOf(Holding h, Map<String, Price> prices) {
  final id = h.assetId;
  final price = id == null ? null : prices[id];
  return price == null ? null : h.amount * price.price;
}

List<WalletAssetRow> _assetRows(
  List<Holding> holdings,
  Map<String, Price> prices,
) {
  final groups = <String, List<Holding>>{};
  for (final h in holdings) {
    final priced = h.assetId != null && prices.containsKey(h.assetId);
    final key = priced ? h.assetId! : 'token:${h.token.tokenKey}';
    groups.putIfAbsent(key, () => []).add(h);
  }
  return [
    for (final e in groups.entries)
      WalletAssetRow(
        key: e.key,
        symbol: e.value.first.displaySymbol,
        amount: e.value.fold(Decimal.zero, (s, h) => s + h.amount),
        value:
            e.value.first.assetId != null &&
                prices.containsKey(e.value.first.assetId)
            ? e.value.fold<Decimal>(
                Decimal.zero,
                (s, h) => s + (_valueOf(h, prices) ?? Decimal.zero),
              )
            : null,
        details: _details(e.value),
      ),
  ];
}

List<AssetChainDetail> _details(List<Holding> holdings) {
  final byChain = <String, Decimal>{};
  for (final h in holdings) {
    final location = h.location;
    final chain = location is OnChainLocation ? location.chainId : '';
    byChain[chain] = (byChain[chain] ?? Decimal.zero) + h.amount;
  }
  return [
    for (final e in byChain.entries)
      AssetChainDetail(chainId: e.key, amount: e.value),
  ];
}

List<WalletAddressRow> _addressRows(
  List<WatchAddress> addresses,
  List<Holding> holdings,
  Map<String, Price> prices,
) {
  final byAddress = <String, Decimal>{};
  for (final h in holdings) {
    final location = h.location;
    if (location is! OnChainLocation) continue;
    final v = _valueOf(h, prices);
    if (v == null) continue;
    byAddress[location.addressId] =
        (byAddress[location.addressId] ?? Decimal.zero) + v;
  }
  // 按链家族分组、组内保持添加顺序。
  final ordered = [for (var i = 0; i < addresses.length; i++) (i, addresses[i])]
    ..sort((a, b) {
      final c = a.$2.family.index.compareTo(b.$2.family.index);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
  return [
    for (final (_, a) in ordered)
      WalletAddressRow(address: a, value: byAddress[a.id] ?? Decimal.zero),
  ];
}
