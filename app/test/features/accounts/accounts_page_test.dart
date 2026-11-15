import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/bootstrap/providers.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

const _addr = '0x1111111111111111111111111111111111111111';

TestRig _rig() {
  final rig = TestRig();
  final a = rig.addWallet('a1', 'Uni 钱包', source: WalletSource.metamask);
  final d = rig.addAddress('d1', a.id, _addr);
  rig.addHolding(a.id, d.id, amount: '2');
  rig.record(a.id);
  rig.addExchange('x1', 'Binance 主账户', ExchangeId.binance);
  rig.record(
    'x1',
    success: false,
    failureType: 'UnsupportedFailure.notIntegrated',
  );
  return rig;
}

void main() {
  group('P03 账户列表', () {
    testWidgets('空状态_引导添加', (tester) async {
      final router = await pumpApp(tester, TestRig(), location: '/accounts');
      expect(find.text('还没有账户'), findsOneWidget);
      await tester.tap(find.text('添加第一个账户'));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/accounts/add');
    });

    testWidgets('分组_钱包与交易所_每行有名称来源估值和失败标记', (tester) async {
      await pumpApp(tester, _rig(), location: '/accounts');
      expect(find.text('钱包'), findsOneWidget);
      expect(find.text('交易所'), findsOneWidget);
      expect(find.text('Uni 钱包'), findsOneWidget);
      expect(find.text('MetaMask'), findsOneWidget);
      expect(find.text(r'$4,000.00'), findsOneWidget);
      expect(find.text('Binance 主账户'), findsOneWidget);
      expect(find.text('Binance'), findsOneWidget);
      expect(find.text(r'$0.00'), findsOneWidget);
      // 只有交易所账户最近一次同步失败。
      expect(find.text('同步失败'), findsOneWidget);
    });

    testWidgets('账户正在同步_行上显示同步中，结束后恢复', (tester) async {
      final rig = _rig();
      final gate = Completer<void>();
      rig.registry[ChainFamily.evm].gate = gate;
      await pumpApp(tester, rig, location: '/accounts');
      expect(find.text('同步中'), findsNothing);

      final container = ProviderScope.containerOf(
        tester.element(find.text('Uni 钱包')),
      );
      final running = container.read(syncAccountProvider)('a1');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('同步中'), findsOneWidget);

      gate.complete();
      await running;
      await tester.pumpAndSettle();
      expect(find.text('同步中'), findsNothing);
    });

    testWidgets('隐藏金额开启_估值显示星号', (tester) async {
      final rig = _rig();
      rig.settings.feed.value = rig.settings.feed.value.copyWith(
        hideAmounts: true,
      );
      await pumpApp(tester, rig, location: '/accounts');
      expect(find.text(r'$4,000.00'), findsNothing);
      expect(find.text('****'), findsWidgets);
    });

    testWidgets('点击钱包行_进入P07', (tester) async {
      final router = await pumpApp(tester, _rig(), location: '/accounts');
      await tester.tap(find.text('Uni 钱包'));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/accounts/wallet/a1');
      expect(find.text('账户总估值'), findsOneWidget);
    });

    testWidgets('点击交易所行_进入P08', (tester) async {
      final router = await pumpApp(tester, _rig(), location: '/accounts');
      await tester.tap(find.text('Binance 主账户'));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/accounts/exchange/x1');
      expect(find.text('账户总估值'), findsOneWidget);
      expect(find.text('API Key 正常 · 只读'), findsOneWidget);
    });

    testWidgets('右上角加号_进入P04', (tester) async {
      final router = await pumpApp(tester, _rig(), location: '/accounts');
      await tester.tap(find.byTooltip('添加账户'));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/accounts/add');
    });

    testWidgets('顶部分段控件_点击地址簿_跳转到地址簿', (tester) async {
      final router = await pumpApp(tester, _rig(), location: '/accounts');
      expect(find.text('账户'), findsWidgets);
      expect(find.text('地址簿'), findsOneWidget);
      await tester.tap(find.text('地址簿'));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/accounts/addresses');
    });

    testWidgets('钱包显示备份状态胶囊', (tester) async {
      final rig = TestRig();
      final a1 = rig.addWallet(
        'w1',
        '未备份钱包',
        backup: const BackupStatus(offlineBackedUp: false),
      );
      final d1 = rig.addAddress('d1', a1.id, _addr);
      rig.addHolding(a1.id, d1.id, amount: '1');
      rig.record(a1.id);

      final a2 = rig.addWallet(
        'w2',
        '已备份钱包',
        backup: const BackupStatus(offlineBackedUp: true),
      );
      final d2 = rig.addAddress(
        'd2',
        a2.id,
        '0x2222222222222222222222222222222222222222',
      );
      rig.addHolding(a2.id, d2.id, amount: '1');
      rig.record(a2.id);

      await pumpApp(tester, rig, location: '/accounts');
      expect(find.text('未备份'), findsOneWidget);
      expect(find.text('已离线备份'), findsOneWidget);
    });

    testWidgets('排序切换_按估值与按名称', (tester) async {
      final rig = TestRig();
      final w1 = rig.addWallet('w1', 'Zebra 钱包');
      final d1 = rig.addAddress('d1', w1.id, _addr);
      rig.addHolding(w1.id, d1.id, amount: '2');
      rig.record(w1.id);

      final w2 = rig.addWallet('w2', 'Apple 钱包');
      final d2 = rig.addAddress(
        'd2',
        w2.id,
        '0x2222222222222222222222222222222222222222',
      );
      rig.addHolding(w2.id, d2.id, amount: '1');
      rig.record(w2.id);

      await pumpApp(tester, rig, location: '/accounts');

      // 默认按估值降序：Zebra ($4,000) 在 Apple ($2,000) 前面
      final zebraCenter = tester.getCenter(find.text('Zebra 钱包'));
      final appleCenter = tester.getCenter(find.text('Apple 钱包'));
      expect(zebraCenter.dy, lessThan(appleCenter.dy));

      // 切换为按名称排序
      await tester.tap(find.byKey(const ValueKey('accounts-sort-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('按名称排序'));
      await tester.pumpAndSettle();

      // 按名称升序：Apple 在 Zebra 前面
      final appleCenter2 = tester.getCenter(find.text('Apple 钱包'));
      final zebraCenter2 = tester.getCenter(find.text('Zebra 钱包'));
      expect(appleCenter2.dy, lessThan(zebraCenter2.dy));

      // 切换回按估值排序
      await tester.tap(find.byKey(const ValueKey('accounts-sort-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('按估值排序'));
      await tester.pumpAndSettle();

      final zebraCenter3 = tester.getCenter(find.text('Zebra 钱包'));
      final appleCenter3 = tester.getCenter(find.text('Apple 钱包'));
      expect(zebraCenter3.dy, lessThan(appleCenter3.dy));
    });

    testWidgets('更多按钮与长按右键_均可打开操作面板', (tester) async {
      await pumpApp(tester, _rig(), location: '/accounts');

      // 1. 点击更多按钮
      await tester.tap(find.byKey(const ValueKey('account-more-a1')));
      await tester.pumpAndSettle();
      expect(find.text('重命名'), findsOneWidget);
      expect(find.text('删除'), findsOneWidget);

      // 关闭底栏
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.text('重命名'), findsNothing);

      // 2. 长按行
      await tester.longPress(find.text('Uni 钱包'));
      await tester.pumpAndSettle();
      expect(find.text('重命名'), findsOneWidget);
      expect(find.text('删除'), findsOneWidget);

      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.text('重命名'), findsNothing);

      // 3. 次级点击（右键）
      await tester.tap(find.text('Uni 钱包'), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      expect(find.text('重命名'), findsOneWidget);
      expect(find.text('删除'), findsOneWidget);
    });

    testWidgets('重命名账户_输入合法名称并保存_成功更新', (tester) async {
      final rig = _rig();
      await pumpApp(tester, rig, location: '/accounts');

      await tester.tap(find.byKey(const ValueKey('account-more-a1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('重命名'));
      await tester.pumpAndSettle();

      expect(find.text('重命名账户'), findsOneWidget);
      expect(find.text('保存'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '我的主钱包');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(find.text('重命名账户'), findsNothing);
      expect(find.text('我的主钱包'), findsOneWidget);
      expect((await rig.accounts.byId('a1'))?.name, '我的主钱包');
    });

    testWidgets('重命名账户_输入空名称_显示错误提示且不更新', (tester) async {
      final rig = _rig();
      await pumpApp(tester, rig, location: '/accounts');

      await tester.tap(find.byKey(const ValueKey('account-more-a1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('重命名'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(find.text('请输入账户名称'), findsWidgets);
      expect(find.text('重命名账户'), findsOneWidget);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect((await rig.accounts.byId('a1'))?.name, 'Uni 钱包');
    });

    testWidgets('删除钱包账户_二次确认后删除', (tester) async {
      final rig = _rig();
      await pumpApp(tester, rig, location: '/accounts');

      await tester.tap(find.byKey(const ValueKey('account-more-a1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      expect(find.text('删除钱包账户'), findsOneWidget);
      expect(find.textContaining('将删除其地址、持仓缓存'), findsOneWidget);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('Uni 钱包'), findsOneWidget);
      expect(await rig.accounts.byId('a1'), isNotNull);

      await tester.tap(find.byKey(const ValueKey('account-more-a1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, '删除'));
      await tester.pumpAndSettle();

      expect(find.text('Uni 钱包'), findsNothing);
      expect(await rig.accounts.byId('a1'), isNull);
    });

    testWidgets('删除交易所账户_二次确认并清理凭据', (tester) async {
      final rig = _rig();
      await rig.secrets.write('ow.exchange.x1.key', 'test_key');
      await rig.secrets.write('ow.exchange.x1.secret', 'test_secret');

      await pumpApp(tester, rig, location: '/accounts');

      await tester.tap(find.byKey(const ValueKey('account-more-x1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      expect(find.text('删除交易所账户'), findsOneWidget);
      expect(find.textContaining('同时清除存储的 API 凭据'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, '删除'));
      await tester.pumpAndSettle();

      expect(find.text('Binance 主账户'), findsNothing);
      expect(await rig.accounts.byId('x1'), isNull);
      expect(await rig.secrets.read('ow.exchange.x1.key'), isNull);
    });
  });

  group('P03 与 P07 不同屏宽下无溢出', () {
    testWidgets('窄屏_详情替换列表', (tester) async {
      await pumpApp(
        tester,
        _rig(),
        location: '/accounts/wallet/a1',
        size: const Size(390, 800),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('账户总估值'), findsOneWidget);
      expect(find.text('Binance 主账户'), findsNothing);
    });

    testWidgets('宽屏_列表与详情并排', (tester) async {
      await pumpApp(
        tester,
        _rig(),
        location: '/accounts/wallet/a1',
        size: const Size(1280, 900),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('账户总估值'), findsOneWidget);
      expect(find.text('Binance 主账户'), findsOneWidget);
    });

    testWidgets('宽屏_未选中账户_显示占位', (tester) async {
      await pumpApp(
        tester,
        _rig(),
        location: '/accounts',
        size: const Size(1280, 900),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('选择一个账户查看详情。'), findsOneWidget);
    });
  });
}
