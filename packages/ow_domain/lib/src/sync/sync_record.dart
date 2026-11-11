/// 一次账户同步的状态。
enum SyncStatus { success, failed, running }

/// 一次账户同步的记录（P21）。
final class SyncRecord {
  const SyncRecord({
    required this.accountId,
    required this.startedAt,
    required this.status,
    this.finishedAt,
    this.failureType,
  });

  final String accountId;

  /// 开始时间（UTC）。
  final DateTime startedAt;

  /// 结束时间（UTC）；进行中为 null。
  final DateTime? finishedAt;
  final SyncStatus status;

  /// 失败时为 `Failure` 的类型名，如 `RateLimitedFailure`；不含任何详情文本。
  final String? failureType;

  @override
  bool operator ==(Object other) =>
      other is SyncRecord &&
      other.accountId == accountId &&
      other.startedAt == startedAt &&
      other.finishedAt == finishedAt &&
      other.status == status &&
      other.failureType == failureType;

  @override
  int get hashCode =>
      Object.hash(accountId, startedAt, finishedAt, status, failureType);

  @override
  String toString() => 'SyncRecord($accountId, ${status.name})';
}
