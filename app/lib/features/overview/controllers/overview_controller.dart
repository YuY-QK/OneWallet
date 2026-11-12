import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ow_application/ow_application.dart';

import '../../../bootstrap/providers.dart';
import 'overview_view.dart';

/// 全量同步的界面状态。
@immutable
final class SyncUiState {
  const SyncUiState({this.running = false, this.progress});

  /// 是否有全量同步在进行。
  final bool running;

  /// 已结束的账户数 / 总数；刚开始时为 null。
  final SyncProgress? progress;
}

/// 全量同步的控制器：进入页面时的自动同步（R13）、下拉刷新、重试。
final overviewSyncProvider =
    NotifierProvider<OverviewSyncController, SyncUiState>(
      OverviewSyncController.new,
    );

class OverviewSyncController extends Notifier<SyncUiState> {
  @override
  SyncUiState build() {
    final syncAll = ref.watch(syncAllAccountsProvider);
    final sub = syncAll.progress.listen((p) {
      if (ref.mounted) state = SyncUiState(running: true, progress: p);
    });
    ref.onDispose(sub.cancel);
    return SyncUiState(running: syncAll.isRunning);
  }

  /// 触发一次全量同步并等待结束。已在进行中时直接等待同一次。
  Future<void> refresh() async {
    final syncAll = ref.read(syncAllAccountsProvider);
    state = const SyncUiState(running: true);
    try {
      await syncAll();
    } finally {
      if (ref.mounted) state = const SyncUiState();
    }
  }

  /// 进入页面时调用：有账户且距上次成功同步超过 5 分钟（或从未同步）才同步。
  Future<void> autoSyncIfNeeded() async {
    final accounts = await ref.read(accountsProvider.future);
    if (accounts.isEmpty || !ref.mounted) return;
    final needed = await ref.read(syncAllAccountsProvider).shouldAutoSync();
    if (needed && ref.mounted) await refresh();
  }

  /// 切换"隐藏金额"（写入设置，全 app 生效）。
  Future<void> toggleHideAmounts() => ref
      .read(settingsRepositoryProvider)
      .update((s) => s.copyWith(hideAmounts: !s.hideAmounts));
}

/// 总览页视图模型；任一数据源还在加载时为加载中。
final overviewViewProvider = Provider<AsyncValue<OverviewView>>((ref) {
  final accounts = ref.watch(accountsProvider);
  final records = ref.watch(latestSyncRecordsProvider);
  final holdings = ref.watch(holdingsProvider);
  final syncing = ref.watch(overviewSyncProvider.select((s) => s.running));
  for (final v in [accounts, records, holdings]) {
    if (v is AsyncError) return AsyncError(v.error!, v.stackTrace!);
  }
  final a = accounts.value;
  final r = records.value;
  final h = holdings.value;
  if (a == null || r == null || h == null) return const AsyncLoading();
  return AsyncData(
    buildOverviewView(accounts: a, records: r, holdings: h, syncing: syncing),
  );
});
