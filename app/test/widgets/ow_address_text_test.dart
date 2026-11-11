import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/widgets/ow_address_text.dart';

import '../helpers/pump_ow.dart';

const _addr = '0x12ab34cd56ef78ab90cd12ef34ab56cd78ef9f3c';

void main() {
  for (final b in Brightness.values) {
    group('OwAddressText（${b.name}）', () {
      testWidgets('默认_缩略为前6后4且使用等宽字体', (tester) async {
        await pumpOw(tester, const OwAddressText(_addr), brightness: b);
        expect(find.text('0x12ab…9f3c'), findsOneWidget);
        expect(find.text(_addr), findsNothing);
        final style = styleOfText(tester, '0x12ab…9f3c');
        expect(style.fontFamily, 'IBMPlexMono');
        expect(style.color, colorsOf(b).ink);
      });

      testWidgets('full_显示完整地址', (tester) async {
        await pumpOw(
          tester,
          const OwAddressText(_addr, full: true),
          brightness: b,
        );
        expect(find.text(_addr), findsOneWidget);
        expect(styleOfText(tester, _addr).fontFamily, 'IBMPlexMono');
      });

      testWidgets('缩略时_读屏标签仍是完整地址', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpOw(tester, const OwAddressText(_addr), brightness: b);
        expect(find.bySemanticsLabel(_addr), findsOneWidget);
        handle.dispose();
      });
    });
  }
}
