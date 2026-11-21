import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/widgets/ow_veil.dart';

import '../helpers/pump_ow.dart';

void main() {
  for (final b in Brightness.values) {
    testWidgets('OwVeil_${b.name}_展示提示文案与按钮且点击触发回调', (tester) async {
      var revealed = false;
      await pumpOw(
        tester,
        OwVeil(
          onReveal: () => revealed = true,
          message: '安全提示文案',
          buttonText: '点我查看',
        ),
        brightness: b,
      );

      expect(find.text('安全提示文案'), findsOneWidget);
      expect(find.text('点我查看'), findsOneWidget);

      await tester.tap(find.text('点我查看'));
      await tester.pump();
      expect(revealed, isTrue);
    });
  }
}
