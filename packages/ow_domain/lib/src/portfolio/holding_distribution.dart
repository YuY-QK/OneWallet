import 'package:decimal/decimal.dart';

import '../asset/holding_location.dart';

/// 某个币种在一个账户、一个位置上的分布（P09"持有分布"的一行）。
final class DistributionEntry {
  const DistributionEntry({
    required this.accountId,
    required this.location,
    required this.amount,
    required this.share,
    this.value,
  });

  final String accountId;
  final HoldingLocation location;

  /// 该账户、该位置上此币种的数量之和。
  final Decimal amount;

  /// 以当前计价货币表示的估值；该币种没有价格时为 null（R9）。
  final Decimal? value;

  /// 占该币种全部分布估值的百分数（0–100）。总估值为 0 或无价格时为 0。
  final Decimal share;

  @override
  bool operator ==(Object other) =>
      other is DistributionEntry &&
      other.accountId == accountId &&
      other.location == location &&
      other.amount == amount &&
      other.value == value &&
      other.share == share;

  @override
  int get hashCode => Object.hash(accountId, location, amount, value, share);

  @override
  String toString() => 'DistributionEntry($accountId, $location, $amount)';
}
