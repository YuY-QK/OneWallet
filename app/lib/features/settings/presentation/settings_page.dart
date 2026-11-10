import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../widgets/empty_state.dart';

/// P18 设置首页。M0 只有占位。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.tabSettings)),
      body: EmptyState(
        icon: Icons.settings_outlined,
        title: l.tabSettings,
        body: l.settingsPlaceholder,
      ),
    );
  }
}
