import 'package:flutter/foundation.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../shared/sync_failure.dart';

/// P02 的页面状态（PRD P02"页面状态"）。
enum OverviewStatus {
  /// 没有任何账户：引导添加。
  empty,

  /// 无缓存且同步中（或尚未得到结果）：骨架屏。
  loading,

  /// 全部失败且无缓存：错误说明加重试。
  allFailed,

  /// 有缓存可显示：正常、部分失败、离线、同步中都落在这里，由标记区分。
  content,
}

/// 总览页的视图模型：由账户、同步记录、各账户最近成功时间和同步进度推出，不含金额汇总
/// （金额汇总来自 `PortfolioSummary`）。
@immutable
final class OverviewView {
  const OverviewView({
    required this.status,
    this.lastSyncedAt,
    this.failedRecords = const [],
    this.offline = false,
    this.syncing = false,
  });

  final OverviewStatus status;

  /// 上次同步成功的时间（UTC）；从未成功为 null。
  final DateTime? lastSyncedAt;

  /// 最近一次同步失败的账户的记录。
  final List<SyncRecord> failedRecords;

  /// 离线：存在失败，且全部失败都是网络失败。
  final bool offline;

  /// 全量同步进行中（显示顶部细进度条）。
  final bool syncing;

  /// 需要提醒的失败账户数；离线时由离线提示代替，为 0。
  int get partialFailureCount => offline ? 0 : failedRecords.length;
}

/// 由原始数据推出 [OverviewView]。纯函数，便于测试。
OverviewView buildOverviewView({
  required List<Account> accounts,
  required List<SyncRecord> records,
  required Map<String, DateTime> lastSuccess,
  required bool syncing,
}) {
  if (accounts.isEmpty) return const OverviewView(status: OverviewStatus.empty);
  final ids = {for (final a in accounts) a.id};
  final mine = [
    for (final r in records)
      if (ids.contains(r.accountId)) r,
  ];
  final failed = [
    for (final r in mine)
      if (r.status == SyncStatus.failed) r,
  ];
  final lastSynced = _lastSynced(lastSuccess, ids);
  final hasCache = lastSynced != null;
  if (!hasCache) {
    final status = (!syncing && failed.isNotEmpty)
        ? OverviewStatus.allFailed
        : OverviewStatus.loading;
    return OverviewView(
      status: status,
      failedRecords: failed,
      syncing: syncing,
      offline: _allNetwork(failed),
    );
  }
  return OverviewView(
    status: OverviewStatus.content,
    lastSyncedAt: lastSynced,
    failedRecords: failed,
    offline: _allNetwork(failed),
    syncing: syncing,
  );
}

bool _allNetwork(List<SyncRecord> failed) =>
    failed.isNotEmpty &&
    failed.every((r) => r.failureType == networkFailureTypeName);

/// 最近一次成功的时间：各账户"最近一次成功时间"里最晚的。
///
/// 该时间单独持久化（不受同步记录只保留 50 条的影响）；失败的账户保留着上次
/// 成功时的持仓（R15），它的成功时间同样计入。
DateTime? _lastSynced(
  Map<String, DateTime> lastSuccess,
  Set<String> accountIds,
) {
  DateTime? latest;
  for (final e in lastSuccess.entries) {
    if (!accountIds.contains(e.key)) continue;
    if (latest == null || e.value.isAfter(latest)) latest = e.value;
  }
  return latest;
}
