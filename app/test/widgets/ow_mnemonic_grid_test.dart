import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/widgets/ow_mnemonic_grid.dart';

import '../helpers/pump_ow.dart';

void main() {
  const words12 = [
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'about',
  ];

  for (final b in Brightness.values) {
    testWidgets('OwMnemonicGrid_${b.name}_正确展示12个词及序号', (tester) async {
      await pumpOw(tester, const OwMnemonicGrid(words: words12), brightness: b);

      for (var i = 1; i <= 12; i++) {
        expect(find.text('$i'), findsOneWidget);
      }
      expect(find.text('about'), findsOneWidget);
    });
  }
}
