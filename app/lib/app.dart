import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'l10n/app_localizations.dart';
import 'router/app_router.dart';
import 'theme/ow_theme.dart';

class OneWalletApp extends StatefulWidget {
  const OneWalletApp({super.key});

  @override
  State<OneWalletApp> createState() => _OneWalletAppState();
}

class _OneWalletAppState extends State<OneWalletApp> {
  late final GoRouter _router = buildAppRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      theme: buildOwTheme(Brightness.light),
      darkTheme: buildOwTheme(Brightness.dark),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _router,
    );
  }
}
