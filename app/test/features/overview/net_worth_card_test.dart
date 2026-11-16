import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/features/overview/presentation/widgets/net_worth_card.dart';
import 'package:onewallet/l10n/app_localizations.dart';
import 'package:onewallet/theme/ow_theme.dart';
import 'package:onewallet/widgets/ow_net_worth_chart.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../support/fakes.dart';

void main() {
  late TestRig rig;

  Snapshot makeSnapshot(DateTime date, String totalUsd) => Snapshot(
    date: date,
    totalUsd: Decimal.parse(totalUsd),
    complete: true,
    byAccountUsd: {},
    byAssetUsd: {},
  );

  Widget buildCard(TestRig rig) => ProviderScope(
    overrides: rig.overrides,
    child: MaterialApp(
      theme: buildOwTheme(Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: SingleChildScrollView(child: NetWorthCard())),
    ),
  );

  setUp(() {
    rig = TestRig(now: DateTime.utc(2026, 11, 16, 12));
  });

  testWidgets('快照少于 2 天时居中显示不足两日提示且不绘制图表折线', (tester) async {
    await rig.snapshots.upsert(
      makeSnapshot(DateTime.utc(2026, 11, 16), '100000'),
    );

    await tester.pumpWidget(buildCard(rig));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('net_worth_card')), findsOneWidget);
    expect(find.byKey(const ValueKey('net_worth_chart_empty')), findsOneWidget);
    expect(find.text('至少需要两天的快照数据以绘制净值曲线'), findsOneWidget);
    expect(find.byKey(const ValueKey('net_worth_chart')), findsNothing);
  });

  testWidgets('快照大于等于 2 天时绘制净值图表', (tester) async {
    await rig.snapshots.upsert(
      makeSnapshot(DateTime.utc(2026, 11, 10), '90000'),
    );
    await rig.snapshots.upsert(
      makeSnapshot(DateTime.utc(2026, 11, 16), '128000'),
    );

    await tester.pumpWidget(buildCard(rig));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('net_worth_chart_empty')), findsNothing);
    expect(find.byKey(const ValueKey('net_worth_chart')), findsOneWidget);
    expect(find.byType(OwNetWorthChart), findsOneWidget);
  });

  testWidgets('切换 7天/30天/90天/全部 选项正常过滤时间范围', (tester) async {
    // 35 天前的一条（不在 7、30 天内，但在 90 天和全部内）
    await rig.snapshots.upsert(
      makeSnapshot(DateTime.utc(2026, 10, 10), '80000'),
    );
    // 10 天前的一条（在 30 天内，但在 7 天内不足 2 条）
    await rig.snapshots.upsert(
      makeSnapshot(DateTime.utc(2026, 11, 6), '95000'),
    );
    // 今天的快照
    await rig.snapshots.upsert(
      makeSnapshot(DateTime.utc(2026, 11, 16), '120000'),
    );

    await tester.pumpWidget(buildCard(rig));
    await tester.pumpAndSettle();

    // 默认 30 天：包含 11-06 与 11-16 共 2 条，展示图表
    expect(find.byKey(const ValueKey('net_worth_chart')), findsOneWidget);

    // 切到 7 天：只有 11-16 一条，少于 2 条，显示提示
    await tester.tap(find.text('7 天'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('net_worth_chart_empty')), findsOneWidget);

    // 切到 90 天：有 3 条，展示图表
    await tester.tap(find.text('90 天'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('net_worth_chart')), findsOneWidget);

    // 切到 全部：展示图表
    await tester.tap(find.text('全部'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('net_worth_chart')), findsOneWidget);
  });

  testWidgets('隐藏金额开启时图表以 **** 遮挡刻度', (tester) async {
    await rig.snapshots.upsert(
      makeSnapshot(DateTime.utc(2026, 11, 10), '90000'),
    );
    await rig.snapshots.upsert(
      makeSnapshot(DateTime.utc(2026, 11, 16), '128000'),
    );
    await rig.settings.update((s) => s.copyWith(hideAmounts: true));

    await tester.pumpWidget(buildCard(rig));
    await tester.pumpAndSettle();

    final chartFinder = find.byType(OwNetWorthChart);
    expect(chartFinder, findsOneWidget);
    final chartWidget = tester.widget<OwNetWorthChart>(chartFinder);
    expect(chartWidget.hidden, isTrue);
  });
}
