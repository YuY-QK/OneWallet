import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../../bootstrap/usecase_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../router/route_names.dart';
import '../../../theme/ow_colors.dart';
import '../../../theme/ow_text_styles.dart';
import '../../../widgets/ow_list_group.dart';
import '../../../widgets/ow_pill.dart';
import '../../../widgets/ow_row.dart';
import '../controllers/sync_status_controller.dart';

/// P18 设置首页。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$m-$d';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final colors = context.ow;
    final syncView = ref.watch(syncStatusViewProvider);
    final failedCount = syncView.asData?.value.failedCount ?? 0;

    final settings =
        ref.watch(settingsProvider).asData?.value ?? const AppSettings();
    final lastExport = settings.lastBackupExportedAt;
    final vaultChanged = settings.vaultChangedAt;
    final hasUnbackedChanges =
        vaultChanged != null &&
        (lastExport == null || vaultChanged.isAfter(lastExport));

    final backupSubtitle = hasUnbackedChanges
        ? l.settingsBackupUnbacked
        : (lastExport != null
              ? l.settingsBackupLastExport(_formatDate(lastExport))
              : l.settingsBackupNever);

    return Scaffold(
      appBar: AppBar(title: Text(l.tabSettings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, 6),
            child: Text(
              l.settingsSectionSecurity,
              style: OwTextStyles.caption.copyWith(color: colors.muted),
            ),
          ),
          OwListGroup(
            children: [
              OwRow(
                title: l.settingsSecurity,
                subtitle: l.settingsSecuritySubtitle,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.goNamed(RouteNames.settingsSecurity),
              ),
              OwRow(
                title: l.settingsBackup,
                subtitle: backupSubtitle,
                trailing: hasUnbackedChanges
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OwPill(
                            label: l.settingsBackupUnbacked,
                            tone: OwPillTone.orange,
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      )
                    : const Icon(Icons.chevron_right_rounded),
                onTap: () => context.goNamed(RouteNames.backup),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, 6),
            child: Text(
              l.settingsSectionData,
              style: OwTextStyles.caption.copyWith(color: context.ow.muted),
            ),
          ),
          OwListGroup(
            children: [
              OwRow(
                title: l.settingsSources,
                subtitle: l.settingsSourcesBody,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.pushNamed(RouteNames.settingsSources),
              ),
              OwRow(
                title: l.settingsSync,
                subtitle: failedCount > 0
                    ? l.settingsSyncFailedCount(failedCount)
                    : l.settingsSyncBody,
                trailing: failedCount > 0
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OwPill(
                            label: l.syncStatusFailed,
                            tone: OwPillTone.red,
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      )
                    : const Icon(Icons.chevron_right_rounded),
                onTap: () => context.goNamed(RouteNames.settingsSync),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
