import 'package:ow_domain/ow_domain.dart';

/// 一个同步失败的账户。
final class AccountSyncFailure {
  const AccountSyncFailure({required this.accountId, required this.failure});

  final String accountId;
  final Failure failure;

  @override
  bool operator ==(Object other) =>
      other is AccountSyncFailure &&
      other.accountId == accountId &&
      other.failure.runtimeType == failure.runtimeType;

  @override
  int get hashCode => Object.hash(accountId, failure.runtimeType);

  @override
  String toString() => 'AccountSyncFailure($accountId, $failure)';
}

/// 全量同步的进度：已结束的账户数 / 账户总数。
final class SyncProgress {
  const SyncProgress({required this.completed, required this.total});

  final int completed;
  final int total;

  @override
  bool operator ==(Object other) =>
      other is SyncProgress &&
      other.completed == completed &&
      other.total == total;

  @override
  int get hashCode => Object.hash(completed, total);

  @override
  String toString() => 'SyncProgress($completed/$total)';
}

/// 全量同步的结果。
final class SyncAllResult {
  /// 各列表会被复制为不可修改的列表。
  SyncAllResult({
    required this.succeededCount,
    required List<AccountSyncFailure> failures,
    required List<String> cancelledAccountIds,
    required this.pricesUpdated,
    required this.cancelled,
    this.priceFailure,
  }) : failures = List.unmodifiable(failures),
       cancelledAccountIds = List.unmodifiable(cancelledAccountIds);

  /// 同步成功的账户数。
  final int succeededCount;

  /// 同步失败的账户，按结束顺序。
  final List<AccountSyncFailure> failures;

  /// 因取消而未开始或中途停止的账户；它们的旧数据不变，也没有写同步记录。
  final List<String> cancelledAccountIds;

  /// 价格是否全部拉取并写入成功。被取消时为 false。
  final bool pricesUpdated;

  /// 价格拉取失败的原因；成功或被取消时为 null。不影响各账户的同步结果。
  final Failure? priceFailure;

  /// 本次同步是否被取消（被取消时不拉取价格，也不调用完成钩子）。
  final bool cancelled;

  /// 账户全部成功且未取消。
  bool get allAccountsSucceeded => failures.isEmpty && !cancelled;
}
