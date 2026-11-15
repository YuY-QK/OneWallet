import 'package:flutter/foundation.dart';
import 'package:ow_domain/ow_domain.dart';

/// 单个账户的同步状态项（用于 P21 账户列表）。
@immutable
final class AccountSyncStatusItem {
  const AccountSyncStatusItem({
    required this.account,
    required this.isRunning,
    this.status,
    this.lastSuccessAt,
    this.failureType,
    this.lastSyncedAt,
  });

  /// 账户信息。
  final Account account;

  /// 该账户当前是否正在同步。
  final bool isRunning;

  /// 最近一次同步结果状态。
  final SyncStatus? status;

  /// 最近一次成功同步的时间（UTC）。
  final DateTime? lastSuccessAt;

  /// 失败类型名（若失败）。
  final String? failureType;

  /// 最近一次同步的结束（或开始）时间。
  final DateTime? lastSyncedAt;

  /// 是否同步成功。
  bool get isSuccess => !isRunning && status == SyncStatus.success;

  /// 是否同步失败。
  bool get isFailed => !isRunning && status == SyncStatus.failed;

  /// 是否是交易所凭据问题（失效或未授权）。
  bool get isKeyIssue =>
      isFailed &&
      account.type == AccountType.exchange &&
      (failureType == 'KeyExpiredFailure' ||
          failureType == 'UnauthorizedFailure');
}

/// 单条同步日志项（用于 P21 最近 50 条同步记录）。
@immutable
final class SyncLogItem {
  const SyncLogItem({
    required this.accountId,
    this.accountName,
    required this.record,
  });

  final String accountId;

  /// 账户名称；若账户已被删除则为 null。
  final String? accountName;

  final SyncRecord record;

  /// 同步耗时（若已结束）。
  Duration? get duration => record.finishedAt?.difference(record.startedAt);
}

/// P21 同步状态页的只读视图模型。
@immutable
final class SyncStatusView {
  const SyncStatusView({
    required this.accounts,
    required this.logs,
    this.lastFullSyncAt,
    this.lastFullSyncDuration,
    this.isFullSyncRunning = false,
  });

  /// 各账户的状态列表。
  final List<AccountSyncStatusItem> accounts;

  /// 最近最多 50 条同步记录。
  final List<SyncLogItem> logs;

  /// 最近一次全量同步完成时间（UTC）。
  final DateTime? lastFullSyncAt;

  /// 最近一次全量同步耗时。
  final Duration? lastFullSyncDuration;

  /// 当前是否正在进行全量同步。
  final bool isFullSyncRunning;

  /// 处于失败状态的账户数。
  int get failedCount => accounts.where((a) => a.isFailed).length;

  /// 正在同步中的账户数。
  int get runningCount => accounts.where((a) => a.isRunning).length;
}

/// 由仓储数据构建 [SyncStatusView] 的纯函数。
SyncStatusView buildSyncStatusView({
  required List<Account> accounts,
  required List<SyncRecord> latestRecords,
  required Map<String, DateTime> lastSuccessPerAccount,
  required List<SyncRecord> recentLogs,
  required Set<String> syncingAccountIds,
  DateTime? lastFullSyncFinishedAt,
  Duration? lastFullSyncDuration,
  bool isFullSyncRunning = false,
}) {
  final recordMap = {for (final r in latestRecords) r.accountId: r};
  final accountMap = {for (final a in accounts) a.id: a};

  final accountItems = <AccountSyncStatusItem>[];
  for (final account in accounts) {
    final isRunning = syncingAccountIds.contains(account.id);
    final rec = recordMap[account.id];
    accountItems.add(
      AccountSyncStatusItem(
        account: account,
        isRunning: isRunning,
        status: rec?.status,
        lastSuccessAt: lastSuccessPerAccount[account.id],
        failureType: rec?.failureType,
        lastSyncedAt: rec?.finishedAt ?? rec?.startedAt,
      ),
    );
  }

  final logItems = <SyncLogItem>[];
  for (final rec in recentLogs) {
    final name = accountMap[rec.accountId]?.name;
    logItems.add(
      SyncLogItem(accountId: rec.accountId, accountName: name, record: rec),
    );
  }

  return SyncStatusView(
    accounts: accountItems,
    logs: logItems,
    lastFullSyncAt: lastFullSyncFinishedAt,
    lastFullSyncDuration: lastFullSyncDuration,
    isFullSyncRunning: isFullSyncRunning,
  );
}
