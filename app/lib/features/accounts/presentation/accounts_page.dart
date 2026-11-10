import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../widgets/empty_state.dart';

/// P03 账户列表。M0 只有空状态。
class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.tabAccounts)),
      body: EmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: l.accountsEmptyTitle,
        body: l.accountsEmptyBody,
      ),
    );
  }
}
