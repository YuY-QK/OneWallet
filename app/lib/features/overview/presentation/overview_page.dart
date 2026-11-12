import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../../bootstrap/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../router/route_names.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/failure_text.dart';
import '../../../widgets/formatters.dart';
import '../../../widgets/ow_notice.dart';
import '../controllers/overview_controller.dart';
import '../controllers/overview_view.dart';
import 'widgets/distribution_section.dart';
import 'widgets/failure_sheet.dart';
import 'widgets/overview_skeleton.dart';
import 'widgets/total_card.dart';

/// P02 总览：总资产、分布、同步状态。
class OverviewPage extends ConsumerStatefulWidget {
  const OverviewPage({super.key});

  @override
  ConsumerState<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends ConsumerState<OverviewPage> {
  @override
  void initState() {
    super.initState();
    // R13：进入时距上次同步超过 5 分钟（或从未同步）则同步。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(ref.read(overviewSyncProvider.notifier).autoSyncIfNeeded());
      }
    });
  }

  Future<void> _refresh() => ref.read(overviewSyncProvider.notifier).refresh();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final hidden = ref.watch(hideAmountsProvider);
    final view = ref.watch(overviewViewProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.tabOverview),
        actions: [
          IconButton(
            tooltip: hidden ? l.overviewShowAmounts : l.overviewHideAmounts,
            icon: Icon(
              hidden
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
            onPressed: () =>
                ref.read(overviewSyncProvider.notifier).toggleHideAmounts(),
          ),
          IconButton(
            tooltip: l.overviewAddAccount,
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.goNamed(RouteNames.accountAdd),
          ),
        ],
      ),
      body: switch (view) {
        AsyncData(:final value) => _body(context, l, value, hidden),
        AsyncError() => _failed(l, failureText(l, const UnknownFailure())),
        _ => const OverviewSkeleton(),
      },
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l,
    OverviewView view,
    bool hidden,
  ) {
    switch (view.status) {
      case OverviewStatus.empty:
        return EmptyState(
          icon: Icons.pie_chart_outline,
          title: l.overviewEmptyTitle,
          body: l.overviewEmptyBody,
          actionLabel: l.overviewEmptyAction,
          onAction: () => context.goNamed(RouteNames.accountAdd),
        );
      case OverviewStatus.loading:
        return Column(
          children: [
            if (view.syncing) const _SyncBar(),
            const Expanded(child: OverviewSkeleton()),
          ],
        );
      case OverviewStatus.allFailed:
        return _failed(
          l,
          view.offline
              ? failureText(l, const NetworkFailure())
              : l.overviewAllFailedBody,
        );
      case OverviewStatus.content:
        return Column(
          children: [
            if (view.syncing) const _SyncBar(),
            Expanded(child: _content(context, l, view, hidden)),
          ],
        );
    }
  }

  Widget _failed(AppLocalizations l, String body) => EmptyState(
    icon: Icons.cloud_off_outlined,
    title: l.overviewAllFailedTitle,
    body: body,
    actionLabel: l.overviewRetry,
    onAction: () => unawaited(_refresh()),
  );

  Widget _content(
    BuildContext context,
    AppLocalizations l,
    OverviewView view,
    bool hidden,
  ) {
    final summary = ref.watch(portfolioSummaryProvider);
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final quote = ref.watch(quoteProvider);
    final now = ref.watch(clockProvider).nowUtc();
    final data = summary.value;
    if (data == null) return const OverviewSkeleton();
    final last = view.lastSyncedAt;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (view.offline && last != null) ...[
                    OwNotice(
                      message: l.overviewOffline(
                        formatRelativeTime(last, now: now, l10n: l),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else if (view.partialFailureCount > 0) ...[
                    OwNotice(
                      tone: OwNoticeTone.error,
                      message: l.overviewPartialFailed(
                        view.partialFailureCount,
                      ),
                      onTap: () => showSyncFailureSheet(
                        context,
                        failed: view.failedRecords,
                        accounts: accounts,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  OverviewTotalCard(
                    summary: data,
                    quote: quote,
                    hidden: hidden,
                    lastSyncedAt: last,
                    now: now,
                  ),
                  const SizedBox(height: 12),
                  DistributionSection(
                    summary: data,
                    accounts: accounts,
                    quote: quote,
                    hidden: hidden,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 同步中的顶部细进度条。用确定值而不是循环动画，避免测试里无法"静止"。
class _SyncBar extends ConsumerWidget {
  const _SyncBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final p = ref.watch(overviewSyncProvider.select((s) => s.progress));
    final value = (p == null || p.total == 0)
        ? 0.08
        : (p.completed / p.total).clamp(0.08, 1.0);
    return Semantics(
      label: l.overviewSyncingLabel,
      child: LinearProgressIndicator(minHeight: 2, value: value),
    );
  }
}
