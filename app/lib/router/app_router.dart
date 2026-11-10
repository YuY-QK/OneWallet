import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/accounts/presentation/accounts_page.dart';
import '../features/overview/presentation/overview_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/vault/presentation/vault_page.dart';
import '../l10n/app_localizations.dart';
import '../shell/adaptive_scaffold.dart';

abstract final class AppRoutes {
  static const overview = '/overview';
  static const accounts = '/accounts';
  static const vault = '/vault';
  static const settings = '/settings';
}

GoRouter buildAppRouter() {
  StatefulShellBranch branch(String path, Widget page) => StatefulShellBranch(
    routes: [GoRoute(path: path, builder: (_, _) => page)],
  );
  return GoRouter(
    initialLocation: AppRoutes.overview,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _Shell(shell: shell),
        branches: [
          branch(AppRoutes.overview, const OverviewPage()),
          branch(AppRoutes.accounts, const AccountsPage()),
          branch(AppRoutes.vault, const VaultPage()),
          branch(AppRoutes.settings, const SettingsPage()),
        ],
      ),
    ],
  );
}

class _Shell extends StatelessWidget {
  const _Shell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AdaptiveScaffold(
      selectedIndex: shell.currentIndex,
      onSelect: (i) =>
          shell.goBranch(i, initialLocation: i == shell.currentIndex),
      destinations: [
        AdaptiveDestination(
          label: l.tabOverview,
          icon: Icons.pie_chart_outline,
          selectedIcon: Icons.pie_chart,
        ),
        AdaptiveDestination(
          label: l.tabAccounts,
          icon: Icons.account_balance_wallet_outlined,
          selectedIcon: Icons.account_balance_wallet,
        ),
        AdaptiveDestination(
          label: l.tabVault,
          icon: Icons.lock_outline,
          selectedIcon: Icons.lock,
        ),
        AdaptiveDestination(
          label: l.tabSettings,
          icon: Icons.settings_outlined,
          selectedIcon: Icons.settings,
        ),
      ],
      body: shell,
    );
  }
}
