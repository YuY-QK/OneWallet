import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../../bootstrap/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../router/route_names.dart';
import '../../../theme/ow_colors.dart';
import '../../../theme/ow_text_styles.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/formatters.dart';
import '../../../widgets/ow_amount_text.dart';
import '../../../widgets/ow_avatar.dart';
import '../../../widgets/ow_card.dart';
import '../../../widgets/ow_notice.dart';
import '../../../widgets/ow_pill.dart';
import '../../../widgets/ow_primary_button.dart';
import '../../../widgets/ow_secondary_button.dart';
import '../../../widgets/ow_skeleton.dart';
import '../../shared/labels.dart';

/// P11 备份清单页面。
class BackupChecklistPage extends ConsumerWidget {
  const BackupChecklistPage({super.key});

  static String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '${local.year}-$m-$d';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final asyncData = ref.watch(backupChecklistProvider);
    final quote = ref.watch(quoteProvider);
    final hidden = ref.watch(hideAmountsProvider);
    final now = ref.watch(clockProvider).nowUtc();
    final updateStatus = ref.watch(updateBackupStatusProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.backupChecklistTitle)),
      body: asyncData.when(
        loading: () =>
            const Padding(padding: EdgeInsets.all(16), child: OwSkeleton()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l.failureUnknown,
              style: OwTextStyles.body.copyWith(color: context.ow.down),
            ),
          ),
        ),
        data: (data) {
          if (data.isEmpty) {
            return EmptyState(
              icon: Icons.shield_outlined,
              title: l.backupChecklistEmptyTitle,
              body: l.backupChecklistEmptyDesc,
              actionLabel: l.overviewEmptyAction,
              onAction: () => context.goNamed(RouteNames.accountAdd),
            );
          }

          final progressRatio = data.totalWallets > 0
              ? (data.backedUpWallets / data.totalWallets).clamp(0.0, 1.0)
              : 1.0;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  // 顶部汇总卡片
                  OwCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l.backupChecklistProgress(
                                data.backedUpWallets,
                                data.totalWallets,
                              ),
                              style: OwTextStyles.title,
                            ),
                            if (data.allBackedUp)
                              OwPill(
                                label: l.backupChecklistAllBackedUp,
                                tone: OwPillTone.green,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: progressRatio,
                            minHeight: 6,
                            backgroundColor: context.ow.brandSoft,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              context.ow.brand,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          data.lastBackupExportedAt != null
                              ? l.backupChecklistLastExport(
                                  _formatDate(data.lastBackupExportedAt!),
                                )
                              : l.backupChecklistNeverExported,
                          style: OwTextStyles.caption.copyWith(
                            color: context.ow.muted,
                          ),
                        ),
                        if (data.hasUnexportedVaultChanges) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 16,
                                color: context.ow.warn,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  l.backupChecklistUnexportedChanges,
                                  style: OwTextStyles.caption.copyWith(
                                    color: context.ow.warn,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OwSecondaryButton(
                            label: l.backupChecklistExport,
                            onPressed: () =>
                                context.pushNamed(RouteNames.backupExport),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 待处理组
                  if (data.pendingWallets.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        l.backupChecklistPendingSection,
                        style: OwTextStyles.rowTitle.copyWith(
                          color: context.ow.muted,
                        ),
                      ),
                    ),
                    for (final item in data.pendingWallets)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _PendingWalletCard(
                          item: item,
                          quote: quote,
                          hidden: hidden,
                          onGoToVault: () => context.pushNamed(
                            RouteNames.vaultImport,
                            queryParameters: {'accountId': item.account.id},
                          ),
                          onMarkOffline: () => updateStatus(
                            accountId: item.account.id,
                            backup: item.account.backup.copyWith(
                              offlineBackedUp: true,
                              offlineVerifiedAt: now,
                            ),
                          ),
                          onMarkKeyless: () => updateStatus(
                            accountId: item.account.id,
                            backup: item.account.backup.copyWith(keyless: true),
                          ),
                          onResetKeyless: () => updateStatus(
                            accountId: item.account.id,
                            backup: item.account.backup.copyWith(
                              keyless: false,
                            ),
                          ),
                        ),
                      ),
                  ],

                  // 已完成组
                  if (data.completedWallets.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        l.backupChecklistCompletedSection,
                        style: OwTextStyles.rowTitle.copyWith(
                          color: context.ow.muted,
                        ),
                      ),
                    ),
                    for (final item in data.completedWallets)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _CompletedWalletCard(
                          item: item,
                          quote: quote,
                          hidden: hidden,
                          onTap: () => context.goNamed(
                            RouteNames.walletDetail,
                            pathParameters: {'id': item.account.id},
                          ),
                          onVerifyToday: () => updateStatus(
                            accountId: item.account.id,
                            backup: item.account.backup.copyWith(
                              offlineVerifiedAt: now,
                            ),
                          ),
                        ),
                      ),
                  ],

                  const SizedBox(height: 16),
                  // 底部固定说明（R37）
                  OwNotice(
                    tone: OwNoticeTone.info,
                    message: l.backupChecklistExchangeNote,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PendingWalletCard extends StatelessWidget {
  const _PendingWalletCard({
    required this.item,
    required this.quote,
    required this.hidden,
    required this.onGoToVault,
    required this.onMarkOffline,
    required this.onMarkKeyless,
    required this.onResetKeyless,
  });

  final BackupChecklistItem item;
  final Quote quote;
  final bool hidden;
  final VoidCallback onGoToVault;
  final VoidCallback onMarkOffline;
  final VoidCallback onMarkKeyless;
  final VoidCallback onResetKeyless;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isKeyless = item.account.backupLevel == BackupLevel.keyless;

    return OwCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              OwAvatar(label: avatarMark(item.account.name)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.account.name,
                            style: OwTextStyles.rowTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        OwPill(
                          label: isKeyless
                              ? l.backupStatusKeyless
                              : l.backupStatusNone,
                          tone: isKeyless ? OwPillTone.orange : OwPillTone.red,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    OwAmountText(
                      formatFiat(item.valuation, symbol: fiatSymbol(quote)),
                      hidden: hidden,
                      style: OwTextStyles.caption.copyWith(
                        color: context.ow.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (isKeyless) ...[
            Text(
              l.backupChecklistKeylessNote,
              style: OwTextStyles.caption.copyWith(color: context.ow.muted),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                OwSecondaryButton(
                  label: l.backupActionResetStatus,
                  onPressed: onResetKeyless,
                ),
                OwSecondaryButton(
                  label: l.backupActionMarkOffline,
                  onPressed: onMarkOffline,
                ),
              ],
            ),
          ] else ...[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                OwPrimaryButton(
                  label: l.backupActionGoToVault,
                  onPressed: onGoToVault,
                ),
                OwSecondaryButton(
                  label: l.backupActionMarkOffline,
                  onPressed: onMarkOffline,
                ),
                OwSecondaryButton(
                  label: l.backupActionMarkKeyless,
                  onPressed: onMarkKeyless,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CompletedWalletCard extends StatelessWidget {
  const _CompletedWalletCard({
    required this.item,
    required this.quote,
    required this.hidden,
    required this.onTap,
    required this.onVerifyToday,
  });

  final BackupChecklistItem item;
  final Quote quote;
  final bool hidden;
  final VoidCallback onTap;
  final VoidCallback onVerifyToday;

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '${local.year}-$m-$d';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final level = item.account.backupLevel;
    final verifiedAt = item.account.backup.offlineVerifiedAt;

    final pills = <Widget>[];
    switch (level) {
      case BackupLevel.inVaultAndOffline:
        pills.add(OwPill(label: l.backupStatusInVault, tone: OwPillTone.green));
        pills.add(OwPill(label: l.backupStatusOffline, tone: OwPillTone.green));
      case BackupLevel.inVault:
        pills.add(OwPill(label: l.backupStatusInVault, tone: OwPillTone.green));
      case BackupLevel.offlineOnly:
        pills.add(OwPill(label: l.backupStatusOffline, tone: OwPillTone.green));
      case BackupLevel.keyless:
      case BackupLevel.none:
        break;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: OwCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                OwAvatar(label: avatarMark(item.account.name)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.account.name,
                              style: OwTextStyles.rowTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Wrap(spacing: 4, children: pills),
                        ],
                      ),
                      const SizedBox(height: 2),
                      if (item.account.backup.offlineBackedUp) ...[
                        if (item.isOverdue) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 14,
                                color: context.ow.warn,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                l.backupChecklistOverdueWarning,
                                style: OwTextStyles.caption.copyWith(
                                  color: context.ow.warn,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ] else if (verifiedAt != null) ...[
                          Text(
                            l.backupChecklistLastVerified(
                              _formatDate(verifiedAt),
                            ),
                            style: OwTextStyles.caption.copyWith(
                              color: context.ow.muted,
                            ),
                          ),
                        ],
                      ] else ...[
                        Text(
                          l.backupStatusInVault,
                          style: OwTextStyles.caption.copyWith(
                            color: context.ow.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OwAmountText(
                  formatFiat(item.valuation, symbol: fiatSymbol(quote)),
                  hidden: hidden,
                  style: OwTextStyles.rowTitle,
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, size: 20),
              ],
            ),
            if (item.isOverdue) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OwSecondaryButton(
                  label: l.backupActionVerifiedToday,
                  onPressed: onVerifyToday,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
