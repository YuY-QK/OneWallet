import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/widgets/empty_state.dart';
import 'package:onewallet/widgets/ow_primary_button.dart';

import '../helpers/pump_ow.dart';

void main() {
  for (final b in Brightness.values) {
    group('EmptyState（${b.name}）', () {
      testWidgets('带操作_显示主按钮并触发回调', (tester) async {
        var taps = 0;
        await pumpOw(
          tester,
          SizedBox(
            height: 500,
            child: EmptyState(
              icon: Icons.inbox_outlined,
              title: '还没有账户',
              body: '添加后显示在这里。',
              actionLabel: '添加第一个账户',
              onAction: () => taps++,
            ),
          ),
          brightness: b,
        );
        expect(find.text('还没有账户'), findsOneWidget);
        expect(find.text('添加后显示在这里。'), findsOneWidget);
        expect(find.byType(OwPrimaryButton), findsOneWidget);
        expect(styleOfText(tester, '还没有账户').color, colorsOf(b).ink);
        await tester.tap(find.text('添加第一个账户'));
        expect(taps, 1);
      });

      testWidgets('无操作_不显示按钮', (tester) async {
        await pumpOw(
          tester,
          const SizedBox(
            height: 500,
            child: EmptyState(
              icon: Icons.inbox_outlined,
              title: '空',
              body: '无',
            ),
          ),
          brightness: b,
        );
        expect(find.byType(OwPrimaryButton), findsNothing);
      });
    });
  }
}
