import 'package:decimal/decimal.dart';

import '../core/equality.dart';

/// 某一天的净值快照，用于净值曲线（PRD R16）。
final class Snapshot {
  /// [byAccountUsd]、[byAssetUsd] 会被复制为不可修改的映射。
  Snapshot({
    required this.date,
    required this.totalUsd,
    required this.complete,
    required Map<String, Decimal> byAccountUsd,
    required Map<String, Decimal> byAssetUsd,
  }) : byAccountUsd = Map.unmodifiable(byAccountUsd),
       byAssetUsd = Map.unmodifiable(byAssetUsd);

  /// UTC 当天零点；同一天只有一条。
  final DateTime date;

  /// 以 USD 计的总额。
  final Decimal totalUsd;

  /// 当天全部账户都同步成功时为 true（R16）。
  final bool complete;

  /// 以账户 id 为键的 USD 估值。
  final Map<String, Decimal> byAccountUsd;

  /// 以标准币种 id 为键的 USD 估值。
  final Map<String, Decimal> byAssetUsd;

  @override
  bool operator ==(Object other) =>
      other is Snapshot &&
      other.date == date &&
      other.totalUsd == totalUsd &&
      other.complete == complete &&
      mapEquals(other.byAccountUsd, byAccountUsd) &&
      mapEquals(other.byAssetUsd, byAssetUsd);

  @override
  int get hashCode => Object.hash(
    date,
    totalUsd,
    complete,
    mapHash(byAccountUsd),
    mapHash(byAssetUsd),
  );

  @override
  String toString() => 'Snapshot(${date.toIso8601String()}, $totalUsd)';
}
