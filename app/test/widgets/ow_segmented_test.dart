import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/widgets/ow_segmented.dart';

import '../helpers/pump_ow.dart';

const _segments = [
  OwSegment(value: 1, label: '24 小时'),
  OwSegment(value: 7, label: '7 天'),
  OwSegment(value: 30, label: '30 天'),
];

void main() {
  for (final b in Brightness.values) {
    group('OwSegmented（${b.name}）', () {
      testWidgets('选中项_用surface底并加深文字', (tester) async {
        await pumpOw(
          tester,
          OwSegmented<int>(segments: _segments, value: 7, onChanged: (_) {}),
          brightness: b,
        );
        final c = colorsOf(b);
        expect(styleOfText(tester, '7 天').color, c.ink);
        expect(styleOfText(tester, '7 天').fontWeight, FontWeight.w500);
        expect(styleOfText(tester, '30 天').color, c.muted);
        final bar = tester.widget<Material>(
          find
              .descendant(
                of: find.byType(OwSegmented<int>),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(bar.color, c.brandSoft);
        // 选中项的底块是 surface 色。
        final selectedBox = tester.widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(OwSegmented<int>),
            matching: find.byType(DecoratedBox),
          ),
        );
        expect(
          selectedBox.where(
            (d) => (d.decoration as BoxDecoration).color == c.surface,
          ),
          hasLength(1),
        );
      });

      testWidgets('点击另一项_回调其值', (tester) async {
        final changes = <int>[];
        await pumpOw(
          tester,
          OwSegmented<int>(
            segments: _segments,
            value: 1,
            onChanged: changes.add,
          ),
          brightness: b,
        );
        await tester.tap(find.text('30 天'));
        expect(changes, [30]);
      });

      testWidgets('点击已选中项_不回调', (tester) async {
        final changes = <int>[];
        await pumpOw(
          tester,
          OwSegmented<int>(
            segments: _segments,
            value: 1,
            onChanged: changes.add,
          ),
          brightness: b,
        );
        await tester.tap(find.text('24 小时'));
        expect(changes, isEmpty);
      });

      testWidgets('可点击区域_每项高度不小于44', (tester) async {
        await pumpOw(
          tester,
          OwSegmented<int>(segments: _segments, value: 1, onChanged: (_) {}),
          brightness: b,
        );
        for (final inkWell in tester.widgetList<InkWell>(
          find.byType(InkWell),
        )) {
          expect(inkWell.onTap, isNotNull);
        }
        final size = tester.getSize(find.byType(InkWell).first);
        expect(size.height, greaterThanOrEqualTo(44));
        expect(size.width, greaterThanOrEqualTo(44));
      });

      testWidgets('语义_选中项标记为已选中的按钮', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpOw(
          tester,
          OwSegmented<int>(segments: _segments, value: 7, onChanged: (_) {}),
          brightness: b,
        );
        expect(
          tester.getSemantics(find.bySemanticsLabel('7 天')),
          isSemantics(isButton: true, isSelected: true),
        );
        expect(
          tester.getSemantics(find.bySemanticsLabel('30 天')),
          isSemantics(isButton: true, isSelected: false),
        );
        handle.dispose();
      });
    });
  }
}
