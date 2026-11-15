import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ow_application/ow_application.dart';

import '../features/accounts/presentation/accounts_page.dart';
import '../features/accounts/presentation/add_account_page.dart';
import '../features/accounts/presentation/add_exchange_page.dart';
import '../features/accounts/presentation/add_wallet_page.dart';
import '../features/accounts/presentation/exchange_detail_page.dart';
import '../features/accounts/presentation/wallet_detail_page.dart';
import '../features/common/presentation/coming_soon_page.dart';
import '../features/lock/presentation/lock_page.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import '../features/overview/presentation/asset_detail_page.dart';
import '../features/overview/presentation/overview_page.dart';
import '../features/settings/presentation/data_sources_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/settings/presentation/sync_status_page.dart';
import '../features/vault/presentation/vault_page.dart';
import '../features/vault/presentation/vault_setup_page.dart';
import '../l10n/app_localizations.dart';
import '../shell/adaptive_scaffold.dart';
import 'route_names.dart';

abstract final class AppRoutes {
  static const lock = '/lock';
  static const onboarding = '/onboarding';
  static const overview = '/overview';
  static const accounts = '/accounts';
  static const vault = '/vault';
  static const settings = '/settings';

  /// 四个 Tab 的根路径。只有处于根路径时，窄屏才显示底部导航栏。
  static const rootRoutes = {overview, accounts, vault, settings};
}

class _ShellRouterNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

class _ShellNavigationObserver extends NavigatorObserver {
  _ShellNavigationObserver(this.onChanged);
  final VoidCallback onChanged;

  void _notify() {
    WidgetsBinding.instance.addPostFrameCallback((_) => onChanged());
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _notify();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _notify();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _notify();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _notify();
}

/// 构建应用路由。路径与路由名见 IMPLEMENTATION_SPEC 7.1；参数只传 id。
GoRouter buildAppRouter({
  String initialLocation = AppRoutes.overview,
  AppLockStateMachine? Function()? appLock,
  Listenable? refreshListenable,
}) {
  final overviewKey = GlobalKey<NavigatorState>(debugLabel: 'overview');
  final accountsKey = GlobalKey<NavigatorState>(debugLabel: 'accounts');
  final vaultKey = GlobalKey<NavigatorState>(debugLabel: 'vault');
  final settingsKey = GlobalKey<NavigatorState>(debugLabel: 'settings');
  final branchKeys = [overviewKey, accountsKey, vaultKey, settingsKey];

  final notifier = _ShellRouterNotifier();

  StatefulShellBranch branch(
    String path,
    Widget page, {
    required GlobalKey<NavigatorState> navigatorKey,
    List<RouteBase>? sub,
  }) => StatefulShellBranch(
    navigatorKey: navigatorKey,
    observers: [_ShellNavigationObserver(notifier.notify)],
    routes: [
      GoRoute(path: path, builder: (_, _) => page, routes: sub ?? const []),
    ],
  );
  Widget soon(BuildContext context, String title) =>
      ComingSoonPage(title: title);
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      if (appLock == null) return null;
      final machine = appLock();
      if (machine == null) return null;
      final path = state.uri.path;
      final lockState = machine.current;

      if (lockState is AppLockUninitialized) {
        if (path == AppRoutes.onboarding ||
            path.startsWith('/settings/backup/restore')) {
          return null;
        }
        return AppRoutes.onboarding;
      }

      if (lockState is AppLockLocked) {
        if (path == AppRoutes.lock) return null;
        return AppRoutes.lock;
      }

      if (lockState is AppLockUnlocked) {
        if (path == AppRoutes.lock || path == AppRoutes.onboarding) {
          return AppRoutes.overview;
        }
        return null;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.lock,
        name: RouteNames.lock,
        builder: (_, _) => const LockPage(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        name: RouteNames.onboarding,
        builder: (_, _) => const OnboardingPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _Shell(
          shell: shell,
          branchKeys: branchKeys,
          notifier: notifier,
          state: state,
        ),
        branches: [
          branch(
            AppRoutes.overview,
            const OverviewPage(),
            navigatorKey: overviewKey,
            sub: [
              GoRoute(
                path: 'asset/:assetId',
                name: RouteNames.assetDetail,
                builder: (c, state) =>
                    AssetDetailPage(assetId: state.pathParameters['assetId']!),
              ),
            ],
          ),
          branch(
            AppRoutes.accounts,
            const AccountsPage(),
            navigatorKey: accountsKey,
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
                builder: (_, state) => AddExchangePage(
                  key: ValueKey(state.uri.toString()),
                  accountId: state.uri.queryParameters['accountId'],
                ),
              ),
              GoRoute(
                path: 'wallet/:id',
                name: RouteNames.walletDetail,
                builder: (c, state) => AccountsPage(
                  detail: WalletDetailPage(
                    key: ValueKey(state.pathParameters['id']),
                    accountId: state.pathParameters['id']!,
                  ),
                ),
              ),
              GoRoute(
                path: 'exchange/:id',
                name: RouteNames.exchangeDetail,
                builder: (c, state) => AccountsPage(
                  detail: ExchangeDetailPage(
                    key: ValueKey(state.pathParameters['id']),
                    accountId: state.pathParameters['id']!,
                  ),
                ),
              ),
              GoRoute(
                path: 'addresses',
                name: RouteNames.addressBook,
                builder: (c, state) =>
                    const Scaffold(body: Center(child: Text('地址簿'))),
              ),
            ],
          ),
          branch(
            AppRoutes.vault,
            const VaultPage(),
            navigatorKey: vaultKey,
            sub: [
              GoRoute(
                path: 'setup',
                name: RouteNames.vaultSetup,
                builder: (c, _) => const VaultSetupPage(),
              ),
              GoRoute(
                path: 'import',
                name: RouteNames.vaultImport,
                builder: (c, _) =>
                    soon(c, AppLocalizations.of(c)!.accountAddImportTitle),
              ),
              GoRoute(
                path: 'item/:id',
                name: RouteNames.vaultItem,
                builder: (c, _) => soon(c, '密钥详情'),
              ),
            ],
          ),
          branch(
            AppRoutes.settings,
            const SettingsPage(),
            navigatorKey: settingsKey,
            sub: [
              GoRoute(
                path: 'sources',
                name: RouteNames.settingsSources,
                builder: (_, _) => const DataSourcesPage(),
              ),
              GoRoute(
                path: 'sync',
                name: RouteNames.settingsSync,
                builder: (_, _) => const SyncStatusPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class _Shell extends StatefulWidget {
  const _Shell({
    required this.shell,
    required this.branchKeys,
    required this.notifier,
    required this.state,
  });

  final StatefulNavigationShell shell;
  final List<GlobalKey<NavigatorState>> branchKeys;
  final _ShellRouterNotifier notifier;
  final GoRouterState state;

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  @override
  void initState() {
    super.initState();
    widget.notifier.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(_Shell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notifier != widget.notifier) {
      oldWidget.notifier.removeListener(_rebuild);
      widget.notifier.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    widget.notifier.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final navKey = widget.branchKeys[widget.shell.currentIndex];
    final hasPushedRoute = navKey.currentState?.canPop() ?? false;
    final currentPath = GoRouter.of(context)
        .routerDelegate
        .currentConfiguration
        .uri
        .path;
    final isMatchedRoot = AppRoutes.rootRoutes.contains(currentPath);
    final showBottomNav = !hasPushedRoute && isMatchedRoot;

    return AdaptiveScaffold(
      selectedIndex: widget.shell.currentIndex,
      onSelect: (i) => widget.shell.goBranch(
        i,
        initialLocation: i == widget.shell.currentIndex,
      ),
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
      showBottomNav: showBottomNav,
      body: widget.shell,
    );
  }
}
