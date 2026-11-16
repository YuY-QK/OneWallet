import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../../bootstrap/foundation_providers.dart';
import '../../../bootstrap/usecase_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/ow_colors.dart';
import '../../../theme/ow_text_styles.dart';
import '../../../widgets/ow_list_group.dart';
import '../../../widgets/ow_pill.dart';
import '../../../widgets/ow_row.dart';

/// P19 安全设置。
class SecuritySettingsPage extends ConsumerWidget {
  const SecuritySettingsPage({super.key});

  Future<void> _selectAutoLock(
    BuildContext context,
    WidgetRef ref,
    AutoLock current,
  ) async {
    final l = AppLocalizations.of(context)!;
    final selected = await showDialog<AutoLock>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l.securityAutoLock),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(AutoLock.immediately),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l.securityAutoLockImmediately),
                if (current == AutoLock.immediately)
                  const Icon(Icons.check, size: 20),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(AutoLock.after1Min),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l.securityAutoLock1Min),
                if (current == AutoLock.after1Min)
                  const Icon(Icons.check, size: 20),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(AutoLock.after5Min),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l.securityAutoLock5Min),
                if (current == AutoLock.after5Min)
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
          .update((s) => s.copyWith(autoLock: selected));
    }
  }

  void _showPendingNotice(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l.securityFeaturePending)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final c = context.ow;
    final settingsAsync = ref.watch(settingsProvider);
    final settings = settingsAsync.value ?? const AppSettings();

    final autoLockLabel = switch (settings.autoLock) {
      AutoLock.immediately => l.securityAutoLockImmediately,
      AutoLock.after1Min => l.securityAutoLock1Min,
      AutoLock.after5Min => l.securityAutoLock5Min,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l.settingsSecurity)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, 6),
            child: Text(
              l.securitySectionAppLock,
              style: OwTextStyles.caption.copyWith(color: c.muted),
            ),
          ),
          OwListGroup(
            children: [
              OwRow(
                title: l.securityPin,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showPendingNotice(context),
              ),
              OwRow(
                title: l.securityAppBiometrics,
                trailing: Switch(
                  value: settings.appBiometrics,
                  onChanged: (val) {
                    ref
                        .read(settingsRepositoryProvider)
                        .update((s) => s.copyWith(appBiometrics: val));
                  },
                ),
              ),
              OwRow(
                title: l.securityAutoLock,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      autoLockLabel,
                      style: OwTextStyles.body.copyWith(color: c.muted),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
                onTap: () => _selectAutoLock(context, ref, settings.autoLock),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, 6),
            child: Text(
              l.securitySectionVault,
              style: OwTextStyles.caption.copyWith(color: c.muted),
            ),
          ),
          OwListGroup(
            children: [
              OwRow(
                title: l.securityVaultBiometrics,
                subtitle: l.securityVaultBiometricsDesc,
                trailing: Switch(
                  value: settings.vaultBiometrics,
                  onChanged: (val) {
                    ref
                        .read(settingsRepositoryProvider)
                        .update((s) => s.copyWith(vaultBiometrics: val));
                  },
                ),
              ),
              OwRow(
                title: l.securityChangeMasterPassword,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showPendingNotice(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, 6),
            child: Text(
              l.securitySectionDevice,
              style: OwTextStyles.caption.copyWith(color: c.muted),
            ),
          ),
          OwListGroup(
            children: [
              OwRow(
                title: l.securityDeviceStatus,
                subtitle: l.securityDeviceNormalDesc,
                trailing: OwPill(
                  label: l.securityDeviceNormal,
                  tone: OwPillTone.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
