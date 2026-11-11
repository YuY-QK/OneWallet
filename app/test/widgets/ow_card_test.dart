import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/widgets/ow_card.dart';

import '../helpers/pump_ow.dart';

void main() {
  for (final b in Brightness.values) {
    testWidgets('OwCard_${b.name}_背景边框圆角内边距符合规范', (tester) async {
      await pumpOw(tester, const OwCard(child: Text('内容')), brightness: b);
      final c = colorsOf(b);
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(OwCard),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, c.surface);
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(10));
      expect(shape.side.color, c.line);
      expect(shape.side.width, 1);
      expect(material.elevation, 0);

      // 内边距 14：文字左边缘距卡片左边缘 14 + 1 像素边框以内。
      final cardLeft = tester.getTopLeft(find.byType(OwCard)).dx;
      final textLeft = tester.getTopLeft(find.text('内容')).dx;
      expect(textLeft - cardLeft, 14);
    });
  }
}
