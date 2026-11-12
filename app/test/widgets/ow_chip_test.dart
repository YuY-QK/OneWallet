import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/widgets/ow_chip.dart';

import '../helpers/pump_ow.dart';

void main() {
  testWidgets('OwChip_选中_带对勾前缀且可点击区域不小于44', (tester) async {
    var taps = 0;
    await pumpOw(
      tester,
      OwChip(label: 'Ethereum', selected: true, onTap: () => taps++),
    );
    expect(find.text('✓ Ethereum'), findsOneWidget);
    expect(
      tester.getSize(find.byType(InkWell)).height,
      greaterThanOrEqualTo(44),
    );
    await tester.tap(find.byType(InkWell));
    expect(taps, 1);
  });

  testWidgets('OwChip_未选中_无前缀', (tester) async {
    await pumpOw(tester, OwChip(label: 'Base', selected: false, onTap: () {}));
    expect(find.text('Base'), findsOneWidget);
    expect(find.text('✓ Base'), findsNothing);
  });

  testWidgets('OwChip_无回调_不可点击', (tester) async {
    await pumpOw(tester, const OwChip(label: 'Bitcoin', selected: true));
    expect(find.byType(InkWell), findsNothing);
    expect(find.text('✓ Bitcoin'), findsOneWidget);
  });
}
