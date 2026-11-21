import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';

import 'bootstrap/providers.dart';
import 'l10n/app_localizations.dart';
import 'router/app_router.dart';
import 'theme/ow_theme.dart';

class OneWalletApp extends ConsumerStatefulWidget {
  const OneWalletApp({super.key, this.initialLocation});

  /// 初始路由，未指定时默认为总览。用于测试直接进入特定页面。
  final String? initialLocation;

  @override
  ConsumerState<OneWalletApp> createState() => _OneWalletAppState();
}

class _LockChangeNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

class _OneWalletAppState extends ConsumerState<OneWalletApp>
    with WidgetsBindingObserver {
  late final _lockNotifier = _LockChangeNotifier();
  StreamSubscription<AppLockState>? _lockSub;
  AppLockStateMachine? _appLock;
  late final GoRouter _router;
  bool _isBackgroundShielded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _router = buildAppRouter(
      initialLocation: widget.initialLocation ?? AppRoutes.overview,
      appLock: widget.initialLocation != null ? null : () => _appLock,
      refreshListenable: _lockNotifier,
    );
    _initAppLock();
  }

  Future<void> _initAppLock() async {
    final machine = await ref.read(appLockStateMachineProvider.future);
    if (!mounted) return;
    _appLock = machine;
    _lockSub = machine.stream.listen((_) {
      _lockNotifier.notify();
    });
    setState(() {});
    _lockNotifier.notify();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _appLock?.handleAppPaused();
      if (!_isBackgroundShielded) {
        setState(() => _isBackgroundShielded = true);
      }
    } else if (state == AppLifecycleState.inactive) {
      // inactive 仅覆盖隐私遮挡层，不记录后台时间
      if (!_isBackgroundShielded) {
        setState(() => _isBackgroundShielded = true);
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_isBackgroundShielded) {
        setState(() => _isBackgroundShielded = false);
      }
      final autoLockFuture = ref.read(settingsRepositoryProvider).watch().first;
      autoLockFuture.then((s) {
        _appLock?.handleAppResumed(s.autoLock);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lockSub?.cancel();
    _lockNotifier.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preference = ref.watch(themeModeProvider);
    final themeMode = switch (preference) {
      ThemePreference.system => ThemeMode.system,
      ThemePreference.light => ThemeMode.light,
      ThemePreference.dark => ThemeMode.dark,
    };

    // 冷启动时应用锁状态机初始化完成前，显示启动加载页，不渲染任何业务页面
    if (widget.initialLocation == null && _appLock == null) {
      return MaterialApp(
        onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
        theme: buildOwTheme(Brightness.light),
        darkTheme: buildOwTheme(Brightness.dark),
        themeMode: themeMode,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      theme: buildOwTheme(Brightness.light),
      darkTheme: buildOwTheme(Brightness.dark),
      themeMode: themeMode,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _router,
      builder: (context, child) {
        return Stack(
          children: [
            ?child,
            if (_isBackgroundShielded)
              Positioned.fill(
                child: ColoredBox(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF0E141C)
                      : const Color(0xFFF1F3F7),
                ),
              ),
          ],
        );
      },
    );
  }
}
