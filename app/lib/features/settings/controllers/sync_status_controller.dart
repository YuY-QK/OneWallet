import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/read_model_providers.dart';
import '../../overview/controllers/overview_controller.dart';
import 'sync_status_view.dart';

/// P21 同步状态页的状态 Provider。
final syncStatusViewProvider = Provider.autoDispose<AsyncValue<SyncStatusView>>(
  (ref) {
    final accounts = ref.watch(accountsProvider);
    final latestRecords = ref.watch(latestSyncRecordsProvider);
    final lastSuccess = ref.watch(lastSuccessPerAccountProvider);
    final recentRecords = ref.watch(recentSyncRecordsProvider);
    final syncing = ref.watch(syncingAccountIdsProvider);
    final syncState = ref.watch(overviewSyncProvider);

    if (accounts.hasError) {
      return AsyncError(accounts.error!, accounts.stackTrace!);
    }
    if (latestRecords.hasError) {
      return AsyncError(latestRecords.error!, latestRecords.stackTrace!);
    }
    if (lastSuccess.hasError) {
      return AsyncError(lastSuccess.error!, lastSuccess.stackTrace!);
    }
    if (recentRecords.hasError) {
      return AsyncError(recentRecords.error!, recentRecords.stackTrace!);
    }
    if (syncing.hasError) {
      return AsyncError(syncing.error!, syncing.stackTrace!);
    }

    if (!accounts.hasValue ||
        !latestRecords.hasValue ||
        !lastSuccess.hasValue ||
        !recentRecords.hasValue ||
        !syncing.hasValue) {
      return const AsyncLoading();
    }

    return AsyncData(
      buildSyncStatusView(
        accounts: accounts.value!,
        latestRecords: latestRecords.value!,
        lastSuccessPerAccount: lastSuccess.value!,
        recentLogs: recentRecords.value!,
        syncingAccountIds: syncing.value!,
        lastFullSyncFinishedAt: syncState.lastFullSyncFinishedAt,
        lastFullSyncDuration: syncState.lastFullSyncDuration,
        isFullSyncRunning: syncState.running,
      ),
    );
  },
);
