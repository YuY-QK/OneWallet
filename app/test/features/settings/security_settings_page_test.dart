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

  group('P19 安全设置', () {
    testWidgets('正常展示分组列表与默认状态', (tester) async {
      await pumpApp(tester, rig, location: '/settings/security');

      expect(find.text('应用锁与生物识别'), findsOneWidget);
      expect(find.text('应用锁'), findsOneWidget);
      expect(find.text('修改 PIN'), findsOneWidget);
      expect(find.text('生物识别解锁'), findsOneWidget);
      expect(find.text('自动锁定时间'), findsOneWidget);
      expect(find.text('立即'), findsOneWidget);

      expect(find.text('保险库'), findsOneWidget);
      expect(find.text('生物识别解锁保险库'), findsOneWidget);
      expect(find.text('修改主密码'), findsOneWidget);

      expect(find.text('设备'), findsOneWidget);
      expect(find.text('设备安全状态'), findsOneWidget);
      expect(find.text('正常'), findsOneWidget);
    });

    testWidgets('切换自动锁定时间_弹窗选择1分钟并成功更新', (tester) async {
      await pumpApp(tester, rig, location: '/settings/security');

      await tester.tap(find.text('自动锁定时间'));
      await tester.pumpAndSettle();

      expect(find.text('立即'), findsWidgets);
      expect(find.text('1 分钟'), findsOneWidget);
      expect(find.text('5 分钟'), findsOneWidget);

      await tester.tap(find.text('1 分钟'));
      await tester.pumpAndSettle();

      expect(rig.settings.feed.value.autoLock, AutoLock.after1Min);
      expect(find.text('1 分钟'), findsOneWidget);
    });

    testWidgets('切换应用锁与保险库生物识别开关', (tester) async {
      await pumpApp(tester, rig, location: '/settings/security');

      final switches = find.byType(Switch);
      expect(switches, findsNWidgets(2));

      // 切换应用锁生物识别
      await tester.tap(switches.at(0));
      await tester.pumpAndSettle();
      expect(rig.settings.feed.value.appBiometrics, isTrue);

      // 切换保险库生物识别
      await tester.tap(switches.at(1));
      await tester.pumpAndSettle();
      expect(rig.settings.feed.value.vaultBiometrics, isTrue);
    });

    testWidgets('点击暂未开放项弹出提示', (tester) async {
      await pumpApp(tester, rig, location: '/settings/security');

      await tester.tap(find.text('修改 PIN'));
      await tester.pump();
      expect(find.text('功能准备中'), findsOneWidget);
    });
  });
}
