import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../../bootstrap/usecase_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../router/route_names.dart';
import '../../../theme/ow_colors.dart';
import '../../../theme/ow_text_styles.dart';
import '../../../widgets/ow_card.dart';
import '../../../widgets/ow_list_group.dart';
import '../../../widgets/ow_pill.dart';
import '../../../widgets/ow_primary_button.dart';
import '../../../widgets/ow_row.dart';

/// P17 加密备份首页。
class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  bool _includeExchangeCredentials = false;

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.ow;

    final settings =
        ref.watch(settingsProvider).asData?.value ?? const AppSettings();
    final lastExport = settings.lastBackupExportedAt;
    final vaultChanged = settings.vaultChangedAt;

    final hasUnbackedChanges =
        vaultChanged != null &&
        (lastExport == null || vaultChanged.isAfter(lastExport));

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: Text(l.backupTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: OwPill(
                label: l.backupSensitiveBadge,
                tone: OwPillTone.orange,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // 未备份提醒横幅（M5-05, R38）
          if (hasUnbackedChanges) ...[
            OwCard(
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: colors.warn,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l.backupUnbackedWarning,
                      style: OwTextStyles.body.copyWith(
                        color: colors.ink,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 导出部分
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
            child: Row(
              children: [
                Text(
                  l.backupExportSection,
                  style: OwTextStyles.caption.copyWith(color: colors.muted),
                ),
                const Spacer(),
                if (lastExport != null)
                  Text(
                    l.settingsBackupLastExport(_formatDateTime(lastExport)),
                    style: OwTextStyles.caption.copyWith(color: colors.muted),
                  )
                else
                  Text(
                    l.settingsBackupNever,
                    style: OwTextStyles.caption.copyWith(color: colors.muted),
                  ),
              ],
            ),
          ),
          OwCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.backupExportSummaryTitle,
                  style: OwTextStyles.body.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l.backupExportSummaryDesc,
                  style: OwTextStyles.caption.copyWith(color: colors.muted),
                ),
                const SizedBox(height: 12),
                Divider(color: colors.line, height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.backupExportIncludeExchange,
                            style: OwTextStyles.body.copyWith(
                              fontWeight: FontWeight.w500,
                              color: colors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l.backupExportIncludeExchangeDesc,
                            style: OwTextStyles.caption.copyWith(
                              color: colors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _includeExchangeCredentials,
                      onChanged: (val) {
                        setState(() => _includeExchangeCredentials = val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                OwPrimaryButton(
                  label: l.backupExportStartButton,
                  onPressed: () {
                    context.pushNamed(
                      RouteNames.backupExport,
                      queryParameters: {
                        'includeExchange': _includeExchangeCredentials
                            .toString(),
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 恢复部分
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
            child: Text(
              l.backupRestoreSection,
              style: OwTextStyles.caption.copyWith(color: colors.muted),
            ),
          ),
          OwListGroup(
            children: [
              OwRow(
                title: l.backupRestoreRowTitle,
                subtitle: l.backupRestoreRowDesc,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  context.pushNamed(RouteNames.backupRestore);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 格式说明
          OwCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: colors.brand, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l.backupFormatNote,
                    style: OwTextStyles.caption.copyWith(
                      color: colors.muted,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
