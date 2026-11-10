import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/app.dart';
import 'package:onewallet/shell/breakpoints.dart';

Future<void> pumpAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const ProviderScope(child: OneWalletApp()));
  await tester.pumpAndSettle();
}

void main() {
  test('Breakpoints_各宽度_归入正确档位', () {
    expect(Breakpoints.fromWidth(390), ScreenSize.compact);
    expect(Breakpoints.fromWidth(600), ScreenSize.medium);
    expect(Breakpoints.fromWidth(1023), ScreenSize.medium);
    expect(Breakpoints.fromWidth(1024), ScreenSize.expanded);
  });

  testWidgets('外壳_窄屏_使用底部导航', (tester) async {
    await pumpAt(tester, const Size(390, 800));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('还没有账户'), findsOneWidget);
  });

  testWidgets('外壳_中屏_使用图标侧栏', (tester) async {
    await pumpAt(tester, const Size(800, 900));
    expect(find.byType(NavigationBar), findsNothing);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse);
  });

  testWidgets('外壳_宽屏_使用带文字的侧栏', (tester) async {
    await pumpAt(tester, const Size(1280, 900));
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isTrue);
  });

  testWidgets('导航_点击保险库_切换到保险库页', (tester) async {
    await pumpAt(tester, const Size(390, 800));
    await tester.tap(find.text('保险库'));
    await tester.pumpAndSettle();
    expect(find.text('保险库尚未启用'), findsOneWidget);
  });

  testWidgets('主题_深色模式_正常渲染', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await pumpAt(tester, const Size(390, 800));
    expect(
      Theme.of(tester.element(find.byType(NavigationBar))).brightness,
      Brightness.dark,
    );
  });
}
