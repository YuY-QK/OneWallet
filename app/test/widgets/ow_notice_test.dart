import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/widgets/ow_notice.dart';

import '../helpers/pump_ow.dart';

Color? _background(WidgetTester tester) => tester
    .widget<Material>(
      find
          .descendant(
            of: find.byType(OwNotice),
            matching: find.byType(Material),
          )
          .first,
    )
    .color;

void main() {
  for (final b in Brightness.values) {
    group('OwNotice（${b.name}）', () {
      for (final tone in OwNoticeTone.values) {
        testWidgets('${tone.name}_文字与底色取自主题且带图标', (tester) async {
          await pumpOw(
            tester,
            OwNotice(message: '提醒内容', tone: tone),
            brightness: b,
          );
          final c = colorsOf(b);
          final (bg, fg) = switch (tone) {
            OwNoticeTone.warn => (c.warnSoft, c.warn),
            OwNoticeTone.error => (c.downSoft, c.down),
            OwNoticeTone.info => (c.brandSoft, c.ink),
          };
          expect(find.text('提醒内容'), findsOneWidget);
          expect(_background(tester), bg);
          expect(styleOfText(tester, '提醒内容').color, fg);
          expect(find.byType(Icon), findsOneWidget);
        });
      }

      testWidgets('无onTap_没有箭头也不可点击', (tester) async {
        await pumpOw(tester, const OwNotice(message: '仅提示'), brightness: b);
        expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
        expect(find.byType(InkWell), findsNothing);
      });

      testWidgets('有onTap_带右箭头且点击触发回调', (tester) async {
        var taps = 0;
        await pumpOw(
          tester,
          OwNotice(message: '去处理', onTap: () => taps++),
          brightness: b,
        );
        expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
        await tester.tap(find.text('去处理'));
        expect(taps, 1);
        expect(
          tester.getSize(find.byType(OwNotice)).height,
          greaterThanOrEqualTo(44),
        );
      });
    });
  }
}
