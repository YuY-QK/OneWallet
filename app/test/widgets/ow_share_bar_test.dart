import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/widgets/ow_share_bar.dart';

import '../helpers/pump_ow.dart';

Finder get _fill => find.descendant(
  of: find.byType(FractionallySizedBox),
  matching: find.byType(ColoredBox),
);

void main() {
  for (final b in Brightness.values) {
    group('OwShareBar（${b.name}）', () {
      testWidgets('高度4_底色line_填充色brand', (tester) async {
        await pumpOw(tester, const OwShareBar(fraction: 0.4), brightness: b);
        final c = colorsOf(b);
        expect(tester.getSize(find.byType(OwShareBar)).height, 4);
        expect(tester.widget<ColoredBox>(_fill).color, c.brand);
        final track = tester.widget<ColoredBox>(
          find
              .descendant(
                of: find.byType(OwShareBar),
                matching: find.byType(ColoredBox),
              )
              .first,
        );
        expect(track.color, c.line);
      });

      testWidgets('占比_填充宽度按比例', (tester) async {
        await pumpOw(
          tester,
          const SizedBox(width: 200, child: OwShareBar(fraction: 0.25)),
          brightness: b,
        );
        expect(tester.getSize(_fill).width, closeTo(50, 0.01));
      });

      testWidgets('越界与NaN_截到0到1之间', (tester) async {
        await pumpOw(
          tester,
          const SizedBox(
            width: 200,
            child: Column(
              children: [
                OwShareBar(fraction: 1.7),
                OwShareBar(fraction: -0.3),
                OwShareBar(fraction: double.nan),
              ],
            ),
          ),
          brightness: b,
        );
        final widths = tester.widgetList(_fill).length;
        expect(widths, 3);
        final sizes = _fill
            .evaluate()
            .map((e) => (e.renderObject! as RenderBox).size.width)
            .toList();
        expect(sizes, [200, 0, 0]);
      });

      testWidgets('语义_有说明时读出说明', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpOw(
          tester,
          const OwShareBar(fraction: 0.42, semanticLabel: '占总资产 42%'),
          brightness: b,
        );
        expect(find.bySemanticsLabel('占总资产 42%'), findsOneWidget);
        handle.dispose();
      });
    });
  }
}
