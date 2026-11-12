import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/accounts/presentation/accounts_page.dart';
import '../features/accounts/presentation/add_account_page.dart';
import '../features/accounts/presentation/add_wallet_page.dart';
import '../features/common/presentation/coming_soon_page.dart';
import '../features/overview/presentation/overview_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/vault/presentation/vault_page.dart';
import '../l10n/app_localizations.dart';
import '../shell/adaptive_scaffold.dart';
import 'route_names.dart';

abstract final class AppRoutes {
  static const overview = '/overview';
  static const accounts = '/accounts';
  static const vault = '/vault';
  static const settings = '/settings';
}

/// 构建应用路由。路径与路由名见 IMPLEMENTATION_SPEC 7.1；参数只传 id。
GoRouter buildAppRouter({String initialLocation = AppRoutes.overview}) {
  StatefulShellBranch branch(
    String path,
    Widget page, {
    List<RouteBase>? sub,
  }) => StatefulShellBranch(
    routes: [
      GoRoute(path: path, builder: (_, _) => page, routes: sub ?? const []),
    ],
  );
  Widget soon(BuildContext context, String title) =>
      ComingSoonPage(title: title);
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _Shell(shell: shell),
        branches: [
          branch(
            AppRoutes.overview,
            const OverviewPage(),
            sub: [
              GoRoute(
                path: 'asset/:assetId',
                name: RouteNames.assetDetail,
                builder: (c, _) => soon(c, AppLocalizations.of(c)!.tabOverview),
              ),
            ],
          ),
          branch(
            AppRoutes.accounts,
            const AccountsPage(),
            sub: [
              GoRoute(
                path: 'add',
                name: RouteNames.accountAdd,
                builder: (_, _) => const AddAccountPage(),
              ),
              GoRoute(
                path: 'add/wallet',
                name: RouteNames.walletAdd,
                builder: (_, state) => AddWalletPage(
                  key: ValueKey(state.uri.toString()),
                  accountId: state.uri.queryParameters['accountId'],
                ),
              ),
              GoRoute(
                path: 'add/exchange',
                name: RouteNames.exchangeAdd,
                builder: (c, _) =>
                    soon(c, AppLocalizations.of(c)!.accountAddExchangeTitle),
              ),
              GoRoute(
                path: 'wallet/:id',
                name: RouteNames.walletDetail,
                builder: (c, state) =>
                    soon(c, AppLocalizations.of(c)!.tabAccounts),
              ),
              GoRoute(
                path: 'exchange/:id',
                name: RouteNames.exchangeDetail,
                builder: (c, _) => soon(c, AppLocalizations.of(c)!.tabAccounts),
              ),
            ],
          ),
          branch(
            AppRoutes.vault,
            const VaultPage(),
            sub: [
              GoRoute(
                path: 'import',
                name: RouteNames.vaultImport,
                builder: (c, _) =>
                    soon(c, AppLocalizations.of(c)!.accountAddImportTitle),
              ),
            ],
          ),
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
