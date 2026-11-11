import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/widgets/ow_avatar.dart';
import 'package:onewallet/widgets/ow_row.dart';

import '../helpers/pump_ow.dart';

void main() {
  for (final b in Brightness.values) {
    group('OwRow（${b.name}）', () {
      testWidgets('完整内容_头像标题副标题右侧都显示', (tester) async {
        await pumpOw(
          tester,
          const OwRow(
            avatar: OwAvatar(label: 'ETH'),
            title: 'Ethereum',
            subtitle: '3 个地址',
            trailing: Text('右侧'),
          ),
          brightness: b,
        );
        expect(find.text('Ethereum'), findsOneWidget);
        expect(find.text('3 个地址'), findsOneWidget);
        expect(find.text('右侧'), findsOneWidget);
        expect(find.byType(OwAvatar), findsOneWidget);
        final c = colorsOf(b);
        expect(styleOfText(tester, 'Ethereum').color, c.ink);
        expect(styleOfText(tester, '3 个地址').color, c.muted);
      });

      testWidgets('最小高度_只有标题时不低于54', (tester) async {
        await pumpOw(tester, const OwRow(title: '仅标题'), brightness: b);
        expect(
          tester.getSize(find.byType(OwRow)).height,
          greaterThanOrEqualTo(54),
        );
      });

      testWidgets('有onTap_点击触发回调且语义为按钮', (tester) async {
        final handle = tester.ensureSemantics();
        var taps = 0;
        await pumpOw(
          tester,
          OwRow(title: '可点击', onTap: () => taps++),
          brightness: b,
        );
        await tester.tap(find.text('可点击'));
        expect(taps, 1);
        expect(
          tester.getSemantics(find.byType(OwRow)),
          isSemantics(label: '可点击', isButton: true, hasTapAction: true),
        );
        handle.dispose();
      });

      testWidgets('有onTap_悬停时出现brandSoft底色', (tester) async {
        await pumpOw(
          tester,
          OwRow(title: '悬停', onTap: () {}),
          brightness: b,
        );
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        addTearDown(mouse.removePointer);
        await mouse.moveTo(tester.getCenter(find.text('悬停')));
        await tester.pumpAndSettle();
        final inkWell = tester.widget<InkWell>(find.byType(InkWell));
        expect(inkWell.hoverColor, colorsOf(b).brandSoft);
        expect(inkWell.focusColor, colorsOf(b).brandSoft);
      });

      testWidgets('无onTap_不可点击也没有按钮语义', (tester) async {
        await pumpOw(tester, const OwRow(title: '只读'), brightness: b);
        expect(find.byType(InkWell), findsNothing);
      });

      testWidgets('长标题_单行省略不溢出', (tester) async {
        await pumpOw(
          tester,
          OwRow(
            title: '很长' * 40,
            subtitle: '说明' * 40,
            trailing: const Text('1,234.56'),
          ),
          brightness: b,
          width: 320,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('monoTitle_标题使用等宽字体', (tester) async {
        await pumpOw(
          tester,
          const OwRow(title: '0x12ab…9f3c', monoTitle: true),
          brightness: b,
        );
        expect(styleOfText(tester, '0x12ab…9f3c').fontFamily, 'IBMPlexMono');
      });
    });
  }
}
