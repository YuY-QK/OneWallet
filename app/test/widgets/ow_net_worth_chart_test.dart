import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/theme/ow_theme.dart';
import 'package:onewallet/widgets/ow_net_worth_chart.dart';
import 'package:ow_domain/ow_domain.dart';

void main() {
  group('formatChartScale', () {
    test('大于等于 1000 显示为带 k 的一位小数', () {
      expect(
        formatChartScale(Decimal.parse('128450.32'), hidden: false),
        equals('128.5k'),
      );
      expect(
        formatChartScale(Decimal.parse('1000'), hidden: false),
        equals('1.0k'),
      );
      expect(
        formatChartScale(Decimal.parse('9999'), hidden: false),
        equals('10.0k'),
      );
    });

    test('小于 1000 且大于等于 1 显示为整数', () {
      expect(
        formatChartScale(Decimal.parse('999'), hidden: false),
        equals('999'),
      );
      expect(
        formatChartScale(Decimal.parse('12.5'), hidden: false),
        equals('13'),
      );
      expect(formatChartScale(Decimal.parse('1'), hidden: false), equals('1'));
    });

    test('小于 1 显示两位小数', () {
      expect(
        formatChartScale(Decimal.parse('0.85'), hidden: false),
        equals('0.85'),
      );
      expect(
        formatChartScale(Decimal.parse('0.05'), hidden: false),
        equals('0.05'),
      );
    });

    test('负数带负号', () {
      expect(
        formatChartScale(Decimal.parse('-1500'), hidden: false),
        equals('-1.5k'),
      );
    });

    test('hidden 为真时返回 ****', () {
      expect(
        formatChartScale(Decimal.parse('128450.32'), hidden: true),
        equals('****'),
      );
      expect(formatChartScale(Decimal.zero, hidden: true), equals('****'));
    });
  });

  group('OwNetWorthChart 组件', () {
    Widget buildTestHarness(Widget child) => MaterialApp(
      theme: buildOwTheme(Brightness.light),
      home: Scaffold(body: Center(child: child)),
    );

    testWidgets('多日快照正常绘制折线、端点与坐标', (tester) async {
      final snapshots = [
        Snapshot(
          date: DateTime.utc(2026, 11, 1),
          totalUsd: Decimal.parse('100000'),
          complete: true,
          byAccountUsd: {},
          byAssetUsd: {},
        ),
        Snapshot(
          date: DateTime.utc(2026, 11, 15),
          totalUsd: Decimal.parse('150000'),
          complete: true,
          byAccountUsd: {},
          byAssetUsd: {},
        ),
      ];

      await tester.pumpWidget(
        buildTestHarness(
          OwNetWorthChart(
            snapshots: snapshots,
            hidden: false,
            leftAxisLabel: '14 天前',
            rightAxisLabel: '今天',
            semanticLabel: '近 14 天净值曲线',
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.bySemanticsLabel('近 14 天净值曲线'), findsOneWidget);
    });

    testWidgets('最高最低值相等时正常绘制单线不抛异常', (tester) async {
      final snapshots = [
        Snapshot(
          date: DateTime.utc(2026, 11, 1),
          totalUsd: Decimal.parse('50000'),
          complete: true,
          byAccountUsd: {},
          byAssetUsd: {},
        ),
        Snapshot(
          date: DateTime.utc(2026, 11, 2),
          totalUsd: Decimal.parse('50000'),
          complete: true,
          byAccountUsd: {},
          byAssetUsd: {},
        ),
      ];

      await tester.pumpWidget(
        buildTestHarness(
          OwNetWorthChart(
            snapshots: snapshots,
            hidden: false,
            leftAxisLabel: '1 天前',
            rightAxisLabel: '今天',
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('不足两日快照时不抛异常', (tester) async {
      final snapshots = [
        Snapshot(
          date: DateTime.utc(2026, 11, 1),
          totalUsd: Decimal.parse('50000'),
          complete: true,
          byAccountUsd: {},
          byAssetUsd: {},
        ),
      ];

      await tester.pumpWidget(
        buildTestHarness(
          OwNetWorthChart(
            snapshots: snapshots,
            hidden: false,
            leftAxisLabel: '1 天前',
            rightAxisLabel: '今天',
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
