import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/widgets/ow_pill.dart';

import '../helpers/pump_ow.dart';

void main() {
  for (final b in Brightness.values) {
    group('OwPill（${b.name}）', () {
      for (final tone in OwPillTone.values) {
        testWidgets('${tone.name}_有文字且底色与字色取自主题', (tester) async {
          await pumpOw(
            tester,
            OwPill(label: '状态', tone: tone),
            brightness: b,
          );
          expect(find.text('状态'), findsOneWidget);

          final c = colorsOf(b);
          final (bg, fg) = switch (tone) {
            OwPillTone.green => (c.upSoft, c.up),
            OwPillTone.red => (c.downSoft, c.down),
            OwPillTone.orange => (c.warnSoft, c.warn),
          };
          expect(styleOfText(tester, '状态').color, fg);
          final box = tester.widget<DecoratedBox>(
            find.descendant(
              of: find.byType(OwPill),
              matching: find.byType(DecoratedBox),
            ),
          );
          expect((box.decoration as BoxDecoration).color, bg);
        });
      }

      testWidgets('文字样式_标签规格11.5号500字重', (tester) async {
        await pumpOw(
          tester,
          const OwPill(label: '已入库', tone: OwPillTone.green),
          brightness: b,
        );
        final style = styleOfText(tester, '已入库');
        expect(style.fontSize, 11.5);
        expect(style.fontWeight, FontWeight.w500);
      });
    });
  }
}
