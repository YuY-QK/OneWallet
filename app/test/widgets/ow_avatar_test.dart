import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/widgets/ow_avatar.dart';

import '../helpers/pump_ow.dart';

BoxDecoration _decoration(WidgetTester tester) {
  final box = tester.widget<Container>(
    find.descendant(
      of: find.byType(OwAvatar),
      matching: find.byType(Container),
    ),
  );
  return box.decoration! as BoxDecoration;
}

void main() {
  for (final b in Brightness.values) {
    group('OwAvatar（${b.name}）', () {
      testWidgets('圆形_默认形状为圆', (tester) async {
        await pumpOw(tester, const OwAvatar(label: 'ETH'), brightness: b);
        final d = _decoration(tester);
        expect(d.shape, BoxShape.circle);
        expect(d.color, colorsOf(b).brandSoft);
        expect(tester.getSize(find.byType(OwAvatar)), const Size(30, 30));
      });

      testWidgets('圆角方形_用于交易所与保险库条目', (tester) async {
        await pumpOw(
          tester,
          const OwAvatar(label: 'BN', shape: OwAvatarShape.roundedSquare),
          brightness: b,
        );
        final d = _decoration(tester);
        expect(d.shape, BoxShape.rectangle);
        expect(d.borderRadius, BorderRadius.circular(7));
      });

      testWidgets('文字_等宽字体且用brand色', (tester) async {
        await pumpOw(tester, const OwAvatar(label: 'ETH'), brightness: b);
        final style = styleOfText(tester, 'ETH');
        expect(style.fontFamily, 'IBMPlexMono');
        expect(style.color, colorsOf(b).brand);
      });

      testWidgets('过长的标记_缩小而不溢出', (tester) async {
        await pumpOw(
          tester,
          const OwAvatar(label: 'LONGLONGLABEL'),
          brightness: b,
        );
        expect(tester.takeException(), isNull);
      });
    });
  }
}
