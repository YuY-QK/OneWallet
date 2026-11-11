import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/widgets/ow_list_group.dart';
import 'package:onewallet/widgets/ow_row.dart';

import '../helpers/pump_ow.dart';

void main() {
  for (final b in Brightness.values) {
    group('OwListGroup（${b.name}）', () {
      testWidgets('三行_行间有两条分隔线', (tester) async {
        await pumpOw(
          tester,
          OwListGroup(
            children: [
              OwRow(title: '甲', onTap: () {}),
              const OwRow(title: '乙'),
              const OwRow(title: '丙'),
            ],
          ),
          brightness: b,
        );
        expect(find.byType(OwRow), findsNWidgets(3));
        final dividers = tester.widgetList<Divider>(find.byType(Divider));
        expect(dividers.length, 2);
        expect(dividers.every((d) => d.color == colorsOf(b).line), isTrue);
      });

      testWidgets('容器_圆角10加边框加surface底', (tester) async {
        await pumpOw(
          tester,
          const OwListGroup(children: [OwRow(title: '甲')]),
          brightness: b,
        );
        final material = tester.widget<Material>(
          find
              .descendant(
                of: find.byType(OwListGroup),
                matching: find.byType(Material),
              )
              .first,
        );
        final c = colorsOf(b);
        expect(material.color, c.surface);
        final shape = material.shape! as RoundedRectangleBorder;
        expect(shape.borderRadius, BorderRadius.circular(10));
        expect(shape.side.color, c.line);
      });

      testWidgets('只有一行_没有分隔线', (tester) async {
        await pumpOw(
          tester,
          const OwListGroup(children: [OwRow(title: '甲')]),
          brightness: b,
        );
        expect(find.byType(Divider), findsNothing);
      });

      testWidgets('组内可点击行_点击触发回调', (tester) async {
        var taps = 0;
        await pumpOw(
          tester,
          OwListGroup(
            children: [OwRow(title: '甲', onTap: () => taps++)],
          ),
          brightness: b,
        );
        await tester.tap(find.text('甲'));
        expect(taps, 1);
      });
    });
  }
}
