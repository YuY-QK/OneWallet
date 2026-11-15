import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../../bootstrap/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../router/route_names.dart';
import '../../../theme/ow_colors.dart';
import '../../../theme/ow_text_styles.dart';
import '../../../widgets/failure_text.dart';
import '../../../widgets/formatters.dart';
import '../../../widgets/ow_avatar.dart';
import '../../../widgets/ow_card.dart';
import '../../../widgets/ow_list_group.dart';
import '../../../widgets/ow_notice.dart';
import '../../../widgets/ow_pill.dart';
import '../../../widgets/ow_primary_button.dart';
import '../../../widgets/ow_row.dart';
import '../../../widgets/ow_skeleton.dart';
import '../../overview/controllers/overview_controller.dart';
import '../../shared/labels.dart';
import '../../shared/sync_failure.dart';
import '../controllers/sync_status_controller.dart';
import '../controllers/sync_status_view.dart';

/// P21 同步状态页：全量同步耗时、各账户同步状态、最近 50 条同步日志。
class SyncStatusPage extends ConsumerWidget {
  const SyncStatusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final state = ref.watch(syncStatusViewProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.syncStatusTitle)),
      body: switch (state) {
        AsyncData(:final value) => _body(context, ref, l, value),
        AsyncError() => Padding(
          padding: const EdgeInsets.all(16),
          child: OwNotice(
            tone: OwNoticeTone.error,
            message: failureText(l, const UnknownFailure()),
          ),
        ),
        _ => const OwSkeleton(),
      },
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    SyncStatusView view,
  ) {
    final now = ref.watch(clockProvider).nowUtc();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            _buildTopCard(context, ref, l, view, now),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 20, 2, 6),
              child: Text(
                l.syncStatusAccountsSection,
                style: OwTextStyles.caption.copyWith(color: context.ow.muted),
              ),
            ),
            _buildAccountsSection(context, l, view, now),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 20, 2, 6),
              child: Text(
                l.syncStatusLogsSection,
                style: OwTextStyles.caption.copyWith(color: context.ow.muted),
              ),
            ),
            _buildLogsSection(context, l, view, now),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCard(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    SyncStatusView view,
    DateTime now,
  ) {
    final String summary;
    if (view.lastFullSyncAt == null) {
      summary = l.syncStatusNeverFullSynced;
    } else {
      final timeStr = formatRelativeTime(
        view.lastFullSyncAt!,
        now: now,
        l10n: l,
      );
      if (view.lastFullSyncDuration != null) {
        final durStr = formatDuration(view.lastFullSyncDuration!, l10n: l);
        summary = '$timeStr · $durStr';
      } else {
        summary = timeStr;
      }
    }

    return OwCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l.syncStatusLastFullSync,
                style: OwTextStyles.caption.copyWith(color: context.ow.muted),
              ),
              Text(summary, style: OwTextStyles.mono),
            ],
          ),
          const SizedBox(height: 12),
          OwPrimaryButton(
            label: view.isFullSyncRunning
                ? l.syncStatusSyncing
                : l.syncStatusSyncNow,
            onPressed: view.isFullSyncRunning
                ? null
                : () => ref.read(overviewSyncProvider.notifier).refresh(),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsSection(
    BuildContext context,
    AppLocalizations l,
    SyncStatusView view,
    DateTime now,
  ) {
    if (view.accounts.isEmpty) {
      return OwListGroup(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Text(
                l.accountsEmptyTitle,
                style: OwTextStyles.caption.copyWith(color: context.ow.muted),
              ),
            ),
          ),
        ],
      );
    }

    return OwListGroup(
      children: [
        for (final item in view.accounts)
          OwRow(
            avatar: OwAvatar(
              label: avatarMark(item.account.name),
              shape: item.account.type == AccountType.wallet
                  ? OwAvatarShape.circle
                  : OwAvatarShape.roundedSquare,
            ),
            title: item.account.name,
            subtitle: _accountSubtitle(l, item, now),
            trailing: _accountPill(l, item),
            onTap: () => _handleAccountTap(context, item),
          ),
      ],
    );
  }

  String _accountSubtitle(
    AppLocalizations l,
    AccountSyncStatusItem item,
    DateTime now,
  ) {
    if (item.isRunning) {
      return l.syncStatusSyncing;
    }
    if (item.isFailed) {
      final reason = item.isKeyIssue
          ? l.syncStatusKeyExpiredHint
          : failureText(l, failureFromTypeName(item.failureType));
      final last = item.lastSuccessAt != null
          ? l.syncStatusLastSuccess(
              formatRelativeTime(item.lastSuccessAt!, now: now, l10n: l),
            )
          : l.syncStatusNeverSuccess;
      return '$reason · $last';
    }
    if (item.isSuccess) {
      if (item.lastSyncedAt != null) {
        return formatRelativeTime(item.lastSyncedAt!, now: now, l10n: l);
      }
      return l.syncStatusSuccess;
    }
    return l.syncStatusNeverSuccess;
  }

  Widget? _accountPill(AppLocalizations l, AccountSyncStatusItem item) {
    if (item.isRunning) {
      return OwPill(label: l.syncStatusRunning, tone: OwPillTone.orange);
    }
    if (item.isFailed) {
      return OwPill(label: l.syncStatusFailed, tone: OwPillTone.red);
    }
    if (item.isSuccess) {
      return OwPill(label: l.syncStatusSuccess, tone: OwPillTone.green);
    }
    return null;
  }

  void _handleAccountTap(BuildContext context, AccountSyncStatusItem item) {
    if (item.isKeyIssue) {
      context.goNamed(
        RouteNames.exchangeAdd,
        queryParameters: {'accountId': item.account.id},
      );
      return;
    }
    if (item.account.type == AccountType.wallet) {
      context.goNamed(
        RouteNames.walletDetail,
        pathParameters: {'id': item.account.id},
      );
    } else {
      context.goNamed(
        RouteNames.exchangeDetail,
        pathParameters: {'id': item.account.id},
      );
    }
  }

  Widget _buildLogsSection(
    BuildContext context,
    AppLocalizations l,
    SyncStatusView view,
    DateTime now,
  ) {
    if (view.logs.isEmpty) {
      return OwListGroup(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Text(
                l.syncStatusLogsEmpty,
                style: OwTextStyles.caption.copyWith(color: context.ow.muted),
              ),
            ),
          ),
        ],
      );
    }

    return OwListGroup(
      children: [
        for (final log in view.logs)
          OwRow(
            title: log.accountName,
            subtitle: _logSubtitle(l, log, now),
            trailing: OwPill(
              label: log.record.status == SyncStatus.success
                  ? l.syncStatusSuccess
                  : l.syncStatusFailed,
              tone: log.record.status == SyncStatus.success
                  ? OwPillTone.green
                  : OwPillTone.red,
            ),
          ),
      ],
    );
  }

  String _logSubtitle(AppLocalizations l, SyncLogItem log, DateTime now) {
    final timeStr = formatRelativeTime(log.record.startedAt, now: now, l10n: l);
    final durStr = log.duration != null
        ? ' · ${formatDuration(log.duration!, l10n: l)}'
        : '';
    if (log.record.status == SyncStatus.failed) {
      final reason = failureText(
        l,
        failureFromTypeName(log.record.failureType),
      );
      return '$timeStr$durStr · $reason';
    }
    return '$timeStr$durStr';
  }
}
