import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/l10n/app_localizations.dart';
import 'package:onewallet/theme/ow_colors.dart';
import 'package:onewallet/theme/ow_theme.dart';

/// 浅色与深色下各取一次的令牌，用于断言颜色随主题变化。
OwColors colorsOf(Brightness b) =>
    b == Brightness.dark ? OwColors.dark : OwColors.light;

/// 在指定亮度的 OneWallet 主题下渲染 [child]（外层有 Scaffold 提供 Material）。
Future<void> pumpOw(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
  double width = 390,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildOwTheme(brightness),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    ),
  );
}

/// 取直接匹配 [text] 的 Text 的最终样式。
TextStyle styleOfText(WidgetTester tester, String text) {
  final richText = tester.widget<RichText>(
    find.descendant(of: find.text(text), matching: find.byType(RichText)).first,
  );
  return richText.text.style!;
}
