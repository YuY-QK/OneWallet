import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/bootstrap/ui_services.dart';
import 'package:onewallet/l10n/app_localizations.dart';
import 'package:onewallet/theme/ow_theme.dart';
import 'package:onewallet/widgets/ow_external_link.dart';

void main() {
  Widget buildApp({required Widget child, required ExternalUrlOpener opener}) {
    return ProviderScope(
      overrides: [externalUrlOpenerProvider.overrideWithValue(opener)],
      child: MaterialApp(
        theme: buildOwTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Center(child: child)),
      ),
    );
  }

  testWidgets('OwExternalLink_默认显示域名与图标', (tester) async {
    final url = Uri.parse('https://etherscan.io/address/0x123');
    await tester.pumpWidget(
      buildApp(
        child: OwExternalLink(url: url),
        opener: (_) async => true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('etherscan.io'), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new_rounded), findsOneWidget);
  });

  testWidgets('OwExternalLink_自定义标签显示标签与域名', (tester) async {
    final url = Uri.parse('https://www.alchemy.com/docs');
    await tester.pumpWidget(
      buildApp(
        child: OwExternalLink(url: url, label: '帮助文档'),
        opener: (_) async => true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('帮助文档'), findsOneWidget);
    expect(find.text('(www.alchemy.com)'), findsOneWidget);
  });

  testWidgets('OwExternalLink_点击弹出确认对话框_取消不打开', (tester) async {
    final url = Uri.parse('https://etherscan.io/address/0x123');
    var opened = false;
    await tester.pumpWidget(
      buildApp(
        child: OwExternalLink(url: url),
        opener: (u) async {
          opened = true;
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('etherscan.io'));
    await tester.pumpAndSettle();

    expect(find.text('即将离开 OneWallet'), findsOneWidget);
    expect(
      find.textContaining('https://etherscan.io/address/0x123'),
      findsOneWidget,
    );
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('继续访问'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.text('即将离开 OneWallet'), findsNothing);
    expect(opened, isFalse);
  });

  testWidgets('OwExternalLink_点击确认后调用系统浏览器打开', (tester) async {
    final url = Uri.parse('https://www.coingecko.com');
    Uri? openedUrl;
    await tester.pumpWidget(
      buildApp(
        child: OwExternalLink(url: url),
        opener: (u) async {
          openedUrl = u;
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('www.coingecko.com'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('继续访问'));
    await tester.pumpAndSettle();

    expect(openedUrl, url);
  });
}
