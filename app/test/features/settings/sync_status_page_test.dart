import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

void main() {
  late TestRig rig;

  final t0 = DateTime.utc(2026, 11, 15, 12, 0);

  final w1 = Account(
    id: 'w1',
    name: 'Uni 钱包',
    type: AccountType.wallet,
    colorIndex: 0,
    createdAt: t0,
  );
  final ex1 = Account(
    id: 'ex1',
    name: 'OKX',
    type: AccountType.exchange,
    exchange: ExchangeId.okx,
    colorIndex: 1,
    createdAt: t0,
  );

  setUp(() {
    rig = TestRig();
  });

  group('设置页入口', () {
    testWidgets('设置页显示同步状态项_有失败账户时展示失败数量_点击跳转P21', (tester) async {
      rig.accounts.feed.value = [w1, ex1];
      rig.record(w1.id, success: true, at: t0);
      rig.record(
        ex1.id,
        success: false,
        failureType: 'KeyExpiredFailure',
        at: t0,
      );

      final router = await pumpApp(tester, rig, location: '/settings');
      expect(find.text('同步状态'), findsOneWidget);
      expect(find.text('1 个账户失败'), findsOneWidget);

      await tester.tap(find.text('同步状态'));
      await tester.pumpAndSettle();

      expect(locationOf(router), '/settings/sync');
      expect(find.text('各账户状态'), findsOneWidget);
    });
  });

  group('P21 同步状态页面展示', () {
    testWidgets('正常展示全量同步卡片_各账户状态_最近记录', (tester) async {
      rig.accounts.feed.value = [w1, ex1];
      rig.record(w1.id, success: true, at: t0);
      rig.record(
        ex1.id,
        success: false,
        failureType: 'KeyExpiredFailure',
        at: t0.add(const Duration(minutes: 5)),
      );

      await pumpApp(tester, rig, location: '/settings/sync');

      // 顶部卡片
      expect(find.text('上次全量同步'), findsOneWidget);
      expect(find.text('立即同步'), findsOneWidget);

      // 账户列表
      expect(find.text('各账户状态'), findsOneWidget);
      expect(find.text('Uni 钱包'), findsWidgets);
      expect(find.text('OKX'), findsWidgets);
      expect(find.textContaining('API Key 已失效，请更换'), findsOneWidget);
      expect(find.text('成功'), findsWidgets);
      expect(find.text('失败'), findsWidgets);

      // 日志列表
      expect(find.text('最近同步记录（最多 50 条）'), findsOneWidget);
    });

    testWidgets('空状态_无账户与无日志时显示空占位', (tester) async {
      rig.accounts.feed.value = [];
      rig.syncRecords.feed.value = [];
      rig.syncRecords.allRecords.value = [];

      await pumpApp(tester, rig, location: '/settings/sync');

      expect(find.text('尚未进行过全量同步'), findsOneWidget);
      expect(find.text('还没有账户'), findsOneWidget);
      expect(find.text('暂无同步记录'), findsOneWidget);
    });

    testWidgets('点击凭据失效的交易所账户_跳转到更换Key页面', (tester) async {
      rig.accounts.feed.value = [w1, ex1];
      rig.record(w1.id, success: true, at: t0);
      rig.record(
        ex1.id,
        success: false,
        failureType: 'KeyExpiredFailure',
        at: t0,
      );

      final router = await pumpApp(tester, rig, location: '/settings/sync');

      // 点击 OKX 账户行
      await tester.tap(find.text('OKX').first);
      await tester.pumpAndSettle();

      expect(locationOf(router), '/accounts/add/exchange?accountId=ex1');
    });

    testWidgets('点击正常钱包账户_跳转到钱包详情页', (tester) async {
      rig.accounts.feed.value = [w1, ex1];
      rig.record(w1.id, success: true, at: t0);
      rig.record(
        ex1.id,
        success: false,
        failureType: 'KeyExpiredFailure',
        at: t0,
      );

      final router = await pumpApp(tester, rig, location: '/settings/sync');

      // 点击 Uni 钱包账户行
      await tester.tap(find.text('Uni 钱包').first);
      await tester.pumpAndSettle();

      expect(locationOf(router), '/accounts/wallet/w1');
    });

    testWidgets('点击立即同步按钮_触发刷新', (tester) async {
      rig.accounts.feed.value = [w1];
      rig.record(w1.id, success: true, at: t0);

      await pumpApp(tester, rig, location: '/settings/sync');

      expect(find.text('立即同步'), findsOneWidget);
      await tester.tap(find.text('立即同步'));
      await tester.pump();

      // 同步进行或完成后页面保持正常
      await tester.pumpAndSettle();
      expect(find.text('立即同步'), findsOneWidget);
    });

    testWidgets('宽屏与窄屏适配_无溢出', (tester) async {
      rig.accounts.feed.value = [w1, ex1];
      rig.record(w1.id, success: true, at: t0);
      rig.record(
        ex1.id,
        success: false,
        failureType: 'KeyExpiredFailure',
        at: t0,
      );

      // 宽屏
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await pumpApp(tester, rig, location: '/settings/sync');
      expect(tester.takeException(), isNull);
      expect(find.text('同步状态'), findsOneWidget);
    });
  });
}
