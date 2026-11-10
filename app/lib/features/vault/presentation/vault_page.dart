import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../widgets/empty_state.dart';

/// P12 保险库首页。M0 只有未启用状态。
class VaultPage extends StatelessWidget {
  const VaultPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.tabVault)),
      body: EmptyState(
        icon: Icons.lock_outline,
        title: l.vaultIntroTitle,
        body: l.vaultIntroBody,
        actionLabel: l.vaultIntroAction,
        onAction: () =>
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(l.notAvailableYet))),
      ),
    );
  }
}
