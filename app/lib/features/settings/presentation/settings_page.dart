import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../../bootstrap/foundation_providers.dart';
import '../../../bootstrap/read_model_providers.dart';
import '../../../bootstrap/usecase_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../router/route_names.dart';
import '../../../theme/ow_colors.dart';
import '../../../theme/ow_text_styles.dart';
import '../../../widgets/ow_danger_button.dart';
import '../../../widgets/ow_list_group.dart';
import '../../../widgets/ow_pill.dart';
import '../../../widgets/ow_row.dart';
import '../controllers/sync_status_controller.dart';

/// P18 设置首页。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '${local.year}-$m-$d';
  }

  Future<void> _selectQuote(
    BuildContext context,
    WidgetRef ref,
    Quote current,
  ) async {
    final l = AppLocalizations.of(context)!;
    final selected = await showDialog<Quote>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l.settingsQuote),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(Quote.usd),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('USD (\$)'),
                if (current == Quote.usd) const Icon(Icons.check, size: 20),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(Quote.cny),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('CNY (¥)'),
                if (current == Quote.cny) const Icon(Icons.check, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
    if (selected != null && selected != current) {
      await ref
          .read(settingsRepositoryProvider)
          .update((s) => s.copyWith(quote: selected));
    }
  }

  Future<void> _selectTheme(
    BuildContext context,
    WidgetRef ref,
    ThemePreference current,
  ) async {
    final l = AppLocalizations.of(context)!;
    final selected = await showDialog<ThemePreference>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l.settingsTheme),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(ThemePreference.system),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l.settingsThemeSystem),
                if (current == ThemePreference.system)
                  const Icon(Icons.check, size: 20),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(ThemePreference.light),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l.settingsThemeLight),
                if (current == ThemePreference.light)
                  const Icon(Icons.check, size: 20),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(ThemePreference.dark),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l.settingsThemeDark),
                if (current == ThemePreference.dark)
                  const Icon(Icons.check, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
    if (selected != null && selected != current) {
      await ref
          .read(settingsRepositoryProvider)
          .update((s) => s.copyWith(theme: selected));
    }
  }

  void _showUnrecognizedTokensSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final l = AppLocalizations.of(ctx)!;
          final c = ctx.ow;
          final hiddenTokensAsync = ref.watch(hiddenTokensProvider);
          final hiddenTokens = hiddenTokensAsync.value ?? const <String>{};

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.settingsUnrecognizedTokens,
                  style: OwTextStyles.emphasis.copyWith(color: c.ink),
                ),
                const SizedBox(height: 6),
                Text(
                  l.settingsUnrecognizedTokensDesc,
                  style: OwTextStyles.caption.copyWith(color: c.muted),
                ),
                const SizedBox(height: 16),
                if (hiddenTokens.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        l.settingsUnrecognizedTokensEmpty,
                        style: OwTextStyles.body.copyWith(color: c.muted),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final tokenKey in hiddenTokens)
                          OwRow(
                            title: tokenKey,
                            monoTitle: true,
                            trailing: TextButton(
                              onPressed: () {
                                ref
                                    .read(tokenVisibilityRepositoryProvider)
                                    .setHidden(tokenKey, false);
                              },
                              child: const Text('取消隐藏'),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmWipe(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.settingsWipeConfirmTitle),
        content: Text(l.settingsWipeConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l.settingsWipeConfirmAction,
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(wipeAndRestartProvider)();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final c = context.ow;
    final settingsAsync = ref.watch(settingsProvider);
    final settings = settingsAsync.value ?? const AppSettings();
    final syncView = ref.watch(syncStatusViewProvider);
    final failedCount = syncView.asData?.value.failedCount ?? 0;

    final backupSubtitle = settings.lastBackupExportedAt != null
        ? l.settingsBackupLastExported(
            _formatDate(settings.lastBackupExportedAt!),
          )
        : l.settingsBackupNever;

    final themeLabel = switch (settings.theme) {
      ThemePreference.system => l.settingsThemeSystem,
      ThemePreference.light => l.settingsThemeLight,
      ThemePreference.dark => l.settingsThemeDark,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l.tabSettings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          // 安全
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, 6),
            child: Text(
              l.settingsSectionSecurity,
              style: OwTextStyles.caption.copyWith(color: c.muted),
            ),
          ),
          OwListGroup(
            children: [
              OwRow(
                title: l.settingsSecurity,
                subtitle: l.settingsSecurityBody,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l.settingsSecuritySoon)),
                  );
                },
              ),
              OwRow(
                title: l.settingsBackup,
                subtitle: backupSubtitle,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.pushNamed(RouteNames.backupExport),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 数据
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, 6),
            child: Text(
              l.settingsSectionData,
              style: OwTextStyles.caption.copyWith(color: c.muted),
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
              OwRow(
                title: l.settingsQuote,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      settings.quote.name.toUpperCase(),
                      style: OwTextStyles.body.copyWith(color: c.muted),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
                onTap: () => _selectQuote(context, ref, settings.quote),
              ),
              OwRow(
                title: l.settingsHideSmall,
                subtitle: l.settingsHideSmallBody,
                trailing: Switch(
                  value: settings.hideSmall,
                  onChanged: (val) {
                    ref
                        .read(settingsRepositoryProvider)
                        .update((s) => s.copyWith(hideSmall: val));
                  },
                ),
              ),
              OwRow(
                title: l.settingsUnrecognizedTokens,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showUnrecognizedTokensSheet(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 外观
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, 6),
            child: Text(
              l.settingsTheme,
              style: OwTextStyles.caption.copyWith(color: c.muted),
            ),
          ),
          OwListGroup(
            children: [
              OwRow(
                title: l.settingsTheme,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      themeLabel,
                      style: OwTextStyles.body.copyWith(color: c.muted),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
                onTap: () => _selectTheme(context, ref, settings.theme),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 其他
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, 6),
            child: Text(
              l.settingsSectionOther,
              style: OwTextStyles.caption.copyWith(color: c.muted),
            ),
          ),
          OwListGroup(
            children: [
              OwRow(
                title: l.settingsAbout,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.pushNamed(RouteNames.settingsAbout),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // 危险区
          OwDangerButton(
            label: l.settingsWipeAllData,
            onPressed: () => _confirmWipe(context, ref),
          ),
        ],
      ),
    );
  }
}
