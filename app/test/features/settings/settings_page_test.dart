import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

void main() {
  late TestRig rig;

  setUp(() {
    rig = TestRig();
  });

  group('P18 设置首页', () {
    testWidgets('正常展示分组列表与默认设置项', (tester) async {
      await pumpApp(tester, rig, location: '/settings');

      expect(find.text('设置'), findsWidgets);
      expect(find.text('安全'), findsOneWidget);
      expect(find.text('数据'), findsOneWidget);
      expect(find.text('外观'), findsWidgets);
      expect(find.text('其他'), findsOneWidget);

      expect(find.text('应用锁与生物识别'), findsOneWidget);
      expect(find.text('加密备份'), findsOneWidget);
      expect(find.text('数据源'), findsOneWidget);
      expect(find.text('同步状态'), findsOneWidget);
      expect(find.text('计价货币'), findsOneWidget);
      expect(find.text('USD'), findsOneWidget);
      expect(find.text('隐藏小额币种'), findsOneWidget);
      expect(find.text('未识别代币'), findsOneWidget);
      expect(find.text('关于与帮助'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(find.text('清除全部数据'), findsOneWidget);
    });

    testWidgets('切换计价货币_弹窗选择CNY并成功更新', (tester) async {
      await pumpApp(tester, rig, location: '/settings');

      await tester.tap(find.text('计价货币'));
      await tester.pumpAndSettle();

      expect(find.text('USD (\$)'), findsOneWidget);
      expect(find.text('CNY (¥)'), findsOneWidget);

      await tester.tap(find.text('CNY (¥)'));
      await tester.pumpAndSettle();

      expect(rig.settings.feed.value.quote, Quote.cny);
      expect(find.text('CNY'), findsOneWidget);
    });

    testWidgets('切换隐藏小额币种开关_成功更新', (tester) async {
      rig.settings.feed.value = const AppSettings(hideSmall: true);
      await pumpApp(tester, rig, location: '/settings');

      final switchFinder = find.byType(Switch).first;
      expect(tester.widget<Switch>(switchFinder).value, isTrue);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(rig.settings.feed.value.hideSmall, isFalse);
    });

    testWidgets('切换主题模式_弹窗选择深色并成功更新', (tester) async {
      await pumpApp(tester, rig, location: '/settings');

      await tester.tap(find.text('外观').last);
      await tester.pumpAndSettle();

      expect(find.text('跟随系统'), findsWidgets);
      expect(find.text('浅色模式'), findsOneWidget);
      expect(find.text('深色模式'), findsOneWidget);

      await tester.tap(find.text('深色模式'));
      await tester.pumpAndSettle();

      expect(rig.settings.feed.value.theme, ThemePreference.dark);
    });

    testWidgets('点击未识别代币_展示底部抽屉并支持取消隐藏', (tester) async {
      await rig.tokenVisibility.setHidden('ethereum:0xscam', true);
      await pumpApp(tester, rig, location: '/settings');

      await tester.tap(find.text('未识别代币'));
      await tester.pumpAndSettle();

      expect(find.text('ethereum:0xscam'), findsOneWidget);
      expect(find.text('取消隐藏'), findsOneWidget);

      await tester.tap(find.text('取消隐藏'));
      await tester.pumpAndSettle();

      expect(await rig.tokenVisibility.hidden(), isEmpty);
    });

    testWidgets('点击清除全部数据_二次确认弹窗_取消不执行_确认执行清空', (tester) async {
      await pumpApp(tester, rig, location: '/settings');

      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('清除全部数据'));
      await tester.pumpAndSettle();

      expect(find.text('清除全部数据？'), findsOneWidget);
      expect(find.textContaining('此操作将清除本地全部钱包、交易所'), findsOneWidget);

      // 点取消
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(rig.wipeAllCalls, 0);

      // 再次点击并确认
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('清除全部数据'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '清除全部数据'));
      await tester.pumpAndSettle();

      expect(rig.wipeAllCalls, 1);
    });

    testWidgets('导航测试_点击安全与关于可跳转对应页面', (tester) async {
      final router = await pumpApp(tester, rig, location: '/settings');

      await tester.tap(find.text('应用锁与生物识别'));
      await tester.pumpAndSettle();
      expect(find.text('修改 PIN'), findsOneWidget);

      router.go('/settings');
      await tester.pumpAndSettle();

      await tester.tap(find.text('关于与帮助'));
      await tester.pumpAndSettle();
      expect(find.text('版本 1.0.0'), findsOneWidget);
    });
  });
}
