import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

class _OneWalletAppState extends ConsumerState<OneWalletApp> {
  late final GoRouter _router = buildAppRouter(
    initialLocation: widget.initialLocation ?? AppRoutes.overview,
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preference = ref.watch(themeModeProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      theme: buildOwTheme(Brightness.light),
      darkTheme: buildOwTheme(Brightness.dark),
      themeMode: switch (preference) {
        ThemePreference.system => ThemeMode.system,
        ThemePreference.light => ThemeMode.light,
        ThemePreference.dark => ThemeMode.dark,
      },
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _router,
    );
  }
}
