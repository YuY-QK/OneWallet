import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../../../bootstrap/foundation_providers.dart';
import '../../../../bootstrap/usecase_providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../router/route_names.dart';
import '../../../../theme/ow_colors.dart';
import '../../../../theme/ow_text_styles.dart';
import '../../../../widgets/ow_avatar.dart';
import '../../../../widgets/ow_card.dart';
import '../../../../widgets/ow_list_group.dart';
import '../../../../widgets/ow_pill.dart';
import '../../../../widgets/ow_row.dart';
import '../../../../widgets/ow_secondary_button.dart';
import '../../../shared/labels.dart';

/// 呼出钱包账户的备份状态管理面板（P07）。
Future<void> showBackupStatusSheet(
  BuildContext context, {
  required Account account,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => BackupStatusSheet(account: account),
);

/// 备份状态管理面板组件。
class BackupStatusSheet extends ConsumerWidget {
  const BackupStatusSheet({super.key, required this.account});

  final Account account;

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '${local.year}-$m-$d';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final now = ref.watch(clockProvider).nowUtc();
    final updateStatus = ref.watch(updateBackupStatusProvider);

    final level = account.backupLevel;
    final offline = account.backup.offlineBackedUp;
    final verifiedAt = account.backup.offlineVerifiedAt;
    final isOverdue =
        offline &&
        (verifiedAt == null ||
            now.difference(verifiedAt) >= const Duration(days: 180));

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
        pills.add(
          OwPill(label: l.backupStatusKeyless, tone: OwPillTone.orange),
        );
      case BackupLevel.none:
        pills.add(OwPill(label: l.backupStatusNone, tone: OwPillTone.red));
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                OwAvatar(label: avatarMark(account.name)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.name,
                        style: OwTextStyles.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Wrap(spacing: 6, runSpacing: 4, children: pills),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            OwCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.backupStatusSheetTitle, style: OwTextStyles.emphasis),
                  const SizedBox(height: 6),
                  if (level == BackupLevel.none)
                    Text(
                      l.backupStatusNoneDesc,
                      style: OwTextStyles.caption.copyWith(
                        color: context.ow.muted,
                      ),
                    )
                  else if (level == BackupLevel.keyless)
                    Text(
                      l.backupStatusKeylessDesc,
                      style: OwTextStyles.caption.copyWith(
                        color: context.ow.muted,
                      ),
                    )
                  else ...[
                    if (account.vaultItemId != null) ...[
                      Text(
                        l.backupStatusInVaultDesc,
                        style: OwTextStyles.caption.copyWith(
                          color: context.ow.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (offline) ...[
                      Text(
                        verifiedAt != null
                            ? l.backupChecklistLastVerified(
                                _formatDate(verifiedAt),
                              )
                            : l.backupStatusOfflineNeverVerified,
                        style: OwTextStyles.caption.copyWith(
                          color: isOverdue ? context.ow.warn : context.ow.muted,
                          fontWeight: isOverdue
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      if (isOverdue) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: context.ow.warn,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l.backupChecklistOverdueWarning,
                              style: OwTextStyles.caption.copyWith(
                                color: context.ow.warn,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        OwSecondaryButton(
                          label: l.backupActionVerifiedToday,
                          onPressed: () async {
                            await updateStatus(
                              accountId: account.id,
                              backup: account.backup.copyWith(
                                offlineVerifiedAt: now,
                              ),
                            );
                            if (context.mounted) Navigator.pop(context);
                          },
                        ),
                      ],
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            OwListGroup(
              children: [
                if (account.vaultItemId == null)
                  OwRow(
                    title: l.backupActionGoToVault,
                    subtitle: l.accountAddImportBody,
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.pop(context);
                      context.pushNamed(
                        RouteNames.vaultImport,
                        queryParameters: {'accountId': account.id},
                      );
                    },
                  ),
                if (!offline)
                  OwRow(
                    title: l.backupActionMarkOffline,
                    subtitle: l.backupStatusOfflineDesc,
                    onTap: () async {
                      await updateStatus(
                        accountId: account.id,
                        backup: account.backup.copyWith(
                          offlineBackedUp: true,
                          offlineVerifiedAt: now,
                        ),
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
                  )
                else
                  OwRow(
                    title: l.backupActionUnmarkOffline,
                    onTap: () async {
                      await updateStatus(
                        accountId: account.id,
                        backup: account.backup.copyWith(
                          offlineBackedUp: false,
                          offlineVerifiedAt: null,
                        ),
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                if (!account.backup.keyless)
                  OwRow(
                    title: l.backupActionMarkKeyless,
                    subtitle: l.backupStatusKeylessDesc,
                    onTap: () async {
                      await updateStatus(
                        accountId: account.id,
                        backup: account.backup.copyWith(keyless: true),
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
                  )
                else
                  OwRow(
                    title: l.backupActionUnmarkKeyless,
                    onTap: () async {
                      await updateStatus(
                        accountId: account.id,
                        backup: account.backup.copyWith(keyless: false),
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                OwRow(
                  title: l.backupActionViewChecklist,
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(context);
                    context.goNamed(RouteNames.backupChecklist);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
