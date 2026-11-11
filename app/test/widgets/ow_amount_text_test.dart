import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/widgets/ow_amount_text.dart';

import '../helpers/pump_ow.dart';

void main() {
  for (final b in Brightness.values) {
    group('OwAmountText（${b.name}）', () {
      testWidgets('默认_使用IBMPlexMono与等宽数字', (tester) async {
        await pumpOw(tester, const OwAmountText(r'$128,450.32'), brightness: b);
        final style = styleOfText(tester, r'$128,450.32');
        expect(style.fontFamily, 'IBMPlexMono');
        expect(
          style.fontFeatures,
          contains(const FontFeature.tabularFigures()),
        );
        expect(style.color, colorsOf(b).ink);
      });

      testWidgets('隐藏_显示星号且不含原数字', (tester) async {
        await pumpOw(
          tester,
          const OwAmountText(r'$128,450.32', hidden: true),
          brightness: b,
        );
        expect(find.text('****'), findsOneWidget);
        expect(find.text(r'$128,450.32'), findsNothing);
        expect(styleOfText(tester, '****').fontFamily, 'IBMPlexMono');
      });

      testWidgets('涨跌语义_取对应主题色', (tester) async {
        await pumpOw(
          tester,
          const Column(
            children: [
              OwAmountText('+1', tone: OwAmountTone.up),
              OwAmountText('-1', tone: OwAmountTone.down),
              OwAmountText('0', tone: OwAmountTone.muted),
            ],
          ),
          brightness: b,
        );
        final c = colorsOf(b);
        expect(styleOfText(tester, '+1').color, c.up);
        expect(styleOfText(tester, '-1').color, c.down);
        expect(styleOfText(tester, '0').color, c.muted);
      });

      testWidgets('叠加样式_字号生效且仍是等宽字体', (tester) async {
        await pumpOw(
          tester,
          const OwAmountText('1', style: TextStyle(fontSize: 28)),
          brightness: b,
        );
        final style = styleOfText(tester, '1');
        expect(style.fontSize, 28);
        expect(style.fontFamily, 'IBMPlexMono');
      });
    });
  }
}
