import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/widgets/ow_danger_button.dart';
import 'package:onewallet/widgets/ow_primary_button.dart';
import 'package:onewallet/widgets/ow_secondary_button.dart';

import '../helpers/pump_ow.dart';

/// 按钮最终的前景色（正常状态）。
Color? _fg(WidgetTester tester, Finder button) {
  final style = tester.widget<ButtonStyleButton>(button).style!;
  return style.foregroundColor!.resolve(<WidgetState>{});
}

void main() {
  for (final b in Brightness.values) {
    final c = colorsOf(b);
    group('按钮（${b.name}）', () {
      testWidgets('OwPrimaryButton_整行宽高不小于44且用brand色', (tester) async {
        var taps = 0;
        await pumpOw(
          tester,
          OwPrimaryButton(label: '保存', onPressed: () => taps++),
          brightness: b,
          width: 390,
        );
        final size = tester.getSize(find.byType(FilledButton));
        expect(size.width, 390 - 32);
        expect(size.height, greaterThanOrEqualTo(44));
        final style = tester
            .widget<FilledButton>(find.byType(FilledButton))
            .style!;
        expect(style.backgroundColor!.resolve(<WidgetState>{}), c.brand);
        expect(_fg(tester, find.byType(FilledButton)), c.brandInk);
        await tester.tap(find.text('保存'));
        expect(taps, 1);
      });

      testWidgets('OwPrimaryButton_禁用_点击无反应', (tester) async {
        await pumpOw(tester, const OwPrimaryButton(label: '保存'), brightness: b);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).enabled,
          isFalse,
        );
      });

      testWidgets('OwSecondaryButton_透明底加边框brand字', (tester) async {
        var taps = 0;
        await pumpOw(
          tester,
          OwSecondaryButton(label: '导出加密备份', onPressed: () => taps++),
          brightness: b,
        );
        final size = tester.getSize(find.byType(OutlinedButton));
        expect(size.width, 390 - 32);
        expect(size.height, greaterThanOrEqualTo(44));
        expect(_fg(tester, find.byType(OutlinedButton)), c.brand);
        final style = tester
            .widget<OutlinedButton>(find.byType(OutlinedButton))
            .style!;
        expect(style.side!.resolve(<WidgetState>{})!.color, c.line);
        await tester.tap(find.text('导出加密备份'));
        expect(taps, 1);
      });

      testWidgets('OwSecondaryButton_compact_外观变小但可点击区域不小于44', (tester) async {
        await pumpOw(
          tester,
          Row(
            children: [
              OwSecondaryButton(label: '复制', compact: true, onPressed: () {}),
            ],
          ),
          brightness: b,
        );
        final visual = tester.getSize(find.byType(OutlinedButton));
        expect(visual.width, lessThan(120));
        // 点击区域由 padded 的 MaterialTapTargetSize 补足到 48。
        final tapTarget = tester.getSize(
          find.descendant(
            of: find.byType(OutlinedButton),
            matching: find.byType(InkWell),
          ),
        );
        expect(tapTarget.height, greaterThanOrEqualTo(32));
        final hit = tester.getSize(find.byType(OutlinedButton));
        expect(hit.height, greaterThanOrEqualTo(44));
      });

      testWidgets('OwDangerButton_down色文字加边框并触发回调', (tester) async {
        var taps = 0;
        await pumpOw(
          tester,
          OwDangerButton(label: '删除账户', onPressed: () => taps++),
          brightness: b,
        );
        expect(_fg(tester, find.byType(OutlinedButton)), c.down);
        final style = tester
            .widget<OutlinedButton>(find.byType(OutlinedButton))
            .style!;
        expect(style.side!.resolve(<WidgetState>{})!.width, 1);
        final size = tester.getSize(find.byType(OutlinedButton));
        expect(size.width, 390 - 32);
        expect(size.height, greaterThanOrEqualTo(44));
        await tester.tap(find.text('删除账户'));
        expect(taps, 1);
      });

      testWidgets('按钮_键盘焦点可达', (tester) async {
        await pumpOw(
          tester,
          Column(
            children: [
              OwPrimaryButton(label: '甲', onPressed: () {}),
              OwSecondaryButton(label: '乙', onPressed: () {}),
              OwDangerButton(label: '丙', onPressed: () {}),
            ],
          ),
          brightness: b,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(FocusManager.instance.primaryFocus, isNotNull);
        expect(FocusManager.instance.primaryFocus!.context, isNotNull);
      });
    });
  }
}
