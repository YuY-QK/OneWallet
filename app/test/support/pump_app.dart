import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onewallet/l10n/app_localizations.dart';
import 'package:onewallet/router/app_router.dart';
import 'package:onewallet/theme/ow_theme.dart';

import 'fakes.dart';

/// 用假依赖渲染整个应用外壳，从 [location] 开始。返回路由器便于断言当前位置。
Future<GoRouter> pumpApp(
  WidgetTester tester,
  TestRig rig, {
  String location = '/overview',
  Size size = const Size(390, 800),
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = buildAppRouter(initialLocation: location);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: rig.overrides,
      child: MaterialApp.router(
        theme: buildOwTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return router;
}

/// 当前路由位置（含查询参数）。
String locationOf(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();
