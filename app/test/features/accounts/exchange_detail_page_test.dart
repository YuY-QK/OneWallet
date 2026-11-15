import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/features/accounts/presentation/add_exchange_page.dart';
import 'package:onewallet/widgets/ow_danger_button.dart';
import 'package:onewallet/widgets/ow_secondary_button.dart';
import 'package:onewallet/widgets/ow_skeleton.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

TestRig _rig() {
  final rig = TestRig();
  final a = rig.addExchange('ex1', 'Binance 主账户', ExchangeId.binance);
  rig.addExchangeHolding(
    a.id,
    sub: ExchangeSubAccount.spot,
    symbol: 'BTC',
    amount: '1.5',
    price: '50000',
  );
  rig.addExchangeHolding(
    a.id,
    sub: ExchangeSubAccount.funding,
    symbol: 'BTC',
    amount: '0.5',
    price: '50000',
  );
  rig.addExchangeHolding(
    a.id,
    sub: ExchangeSubAccount.spot,
    symbol: 'USDT',
    amount: '1000',
    price: '1',
  );
  rig.addExchangeHolding(
    a.id,
    sub: ExchangeSubAccount.futures,
    symbol: 'ETH',
    amount: '2',
    price: '3000',
  );
  rig.addExchangeHolding(
    a.id,
    sub: ExchangeSubAccount.earn,
    symbol: 'JUNK',
    amount: '500',
    assetId: null,
  );
  rig.record(a.id);
  return rig;
}

void main() {
  group('P08 交易所账户详情 页面状态', () {
    testWidgets('加载_从未同步_骨架屏并触发该账户同步_完成后显示无资产', (tester) async {
      final rig = TestRig();
      rig.addExchange('ex1', 'Binance 主账户', ExchangeId.binance);
      await rig.secrets.write('ow.exchange.ex1.key', 'fake-key');
      await rig.secrets.write('ow.exchange.ex1.secret', 'fake-secret');
      final gate = Completer<void>();
      final exFake = rig.registry.exchangeFake(ExchangeId.binance);
      exFake.gate = gate;

      await pumpApp(
        tester,
        rig,
        location: '/accounts/exchange/ex1',
        settle: false,
      );
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(OwSkeleton), findsOneWidget);
      expect(exFake.fetchHoldingsCalls.length, 1);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(OwSkeleton), findsNothing);
      expect(find.text('该交易所目前没有可显示的资产'), findsOneWidget);
    });

    testWidgets('正常_总估值_APIKey正常标签_未包含产品提示_按币种列表', (tester) async {
      await pumpApp(tester, _rig(), location: '/accounts/exchange/ex1');
      expect(find.text('Binance 主账户'), findsOneWidget);
      expect(find.text('账户总估值'), findsOneWidget);
      // Total: 1.5*50k + 0.5*50k + 1000 + 2*3000 = 107,000
      expect(find.text(r'$107,000.00'), findsOneWidget);
      expect(find.text('API Key 正常 · 只读'), findsOneWidget);
      expect(find.textContaining('未包含：'), findsOneWidget);

      // 按币种 tab 默认选中
      expect(find.text('BTC'), findsWidgets);
      expect(find.text('ETH'), findsWidgets);
      expect(find.text('USDT'), findsWidgets);
    });

    testWidgets('按币种展开子账户明细', (tester) async {
      await pumpApp(tester, _rig(), location: '/accounts/exchange/ex1');
      // 点击 BTC 行展开明细
      await tester.tap(find.text('BTC').first);
      await tester.pumpAndSettle();

      expect(find.text('现货'), findsWidgets);
      expect(find.text('资金'), findsWidgets);
    });

    testWidgets('按子账户分段与明细展开', (tester) async {
      await pumpApp(tester, _rig(), location: '/accounts/exchange/ex1');

      // 切换到"按子账户"
      await tester.tap(find.text('按子账户'));
      await tester.pumpAndSettle();

      expect(find.text('现货'), findsOneWidget);
      expect(find.text('资金'), findsOneWidget);
      expect(find.text('合约'), findsOneWidget);
      expect(find.text('理财'), findsOneWidget);

      // 点击现货展开现货内币种
      await tester.tap(find.text('现货'));
      await tester.pumpAndSettle();

      expect(find.text('BTC'), findsWidgets);
      expect(find.text('USDT'), findsWidgets);
    });

    testWidgets('折叠未识别无估值币种', (tester) async {
      await pumpApp(tester, _rig(), location: '/accounts/exchange/ex1');

      expect(find.textContaining('1 个未识别或无估值的币种'), findsOneWidget);
      expect(find.text('JUNK'), findsNothing);

      await tester.tap(find.textContaining('1 个未识别或无估值的币种'));
      await tester.pumpAndSettle();

      expect(find.text('JUNK'), findsWidgets);
    });

    testWidgets('Key 失效状态_警告卡片与红标签', (tester) async {
      final rig = _rig();
      rig.record('ex1', success: false, failureType: 'UnauthorizedFailure');
      await pumpApp(tester, rig, location: '/accounts/exchange/ex1');

      expect(find.text('API Key 已失效'), findsWidgets);
      expect(find.textContaining('无法同步最新资产，请尽快更换'), findsOneWidget);
      // 旧缓存依然显示
      expect(find.text('BTC'), findsWidgets);
    });

    testWidgets('非Key错误同步失败_显示原因与上次成功时间_缓存数据仍显示', (tester) async {
      final rig = _rig();
      rig.record('ex1', success: false, failureType: 'NetworkFailure');
      await pumpApp(tester, rig, location: '/accounts/exchange/ex1');

      expect(find.textContaining('同步失败：网络不可用'), findsOneWidget);
      expect(find.textContaining('上次成功同步：3 分钟前'), findsOneWidget);
      expect(find.text('BTC'), findsWidgets);
    });

    testWidgets('充值地址区折叠展开与空状态', (tester) async {
      await pumpApp(tester, _rig(), location: '/accounts/exchange/ex1');

      expect(find.text('充值地址'), findsOneWidget);
      expect(find.text('由交易所控制，仅供查看'), findsOneWidget);
      expect(find.text('暂无充值地址'), findsNothing);

      await tester.tap(find.text('充值地址'));
      await tester.pumpAndSettle();

      expect(find.textContaining('此地址由交易所控制，仅供查看'), findsOneWidget);
      expect(find.text('暂无充值地址'), findsOneWidget);
    });

    testWidgets('更换 API Key 按钮_导航到 P06 携带 accountId', (tester) async {
      await pumpApp(tester, _rig(), location: '/accounts/exchange/ex1');

      final replaceBtn = find.widgetWithText(OwSecondaryButton, '更换 API Key');
      expect(replaceBtn, findsOneWidget);

      await tester.tap(replaceBtn);
      await tester.pumpAndSettle();

      expect(find.byType(AddExchangePage), findsOneWidget);
    });

    testWidgets('删除账户_二次确认对话框_取消不删除_确认后删除并返回', (tester) async {
      final rig = _rig();
      await pumpApp(tester, rig, location: '/accounts/exchange/ex1');

      final deleteBtn = find.widgetWithText(OwDangerButton, '删除账户');
      expect(deleteBtn, findsOneWidget);

      // 1. 点击删除按钮，弹出对话框
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      expect(find.text('删除交易所账户'), findsOneWidget);
      expect(find.textContaining('确定删除此交易所账户'), findsOneWidget);

      // 2. 取消
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(find.text('删除交易所账户'), findsNothing);
      expect(await rig.accounts.byId('ex1'), isNotNull);

      // 3. 再次点击并确认删除
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      await tester.tap(find.text('删除').last);
      await tester.pumpAndSettle();

      expect(await rig.accounts.byId('ex1'), isNull);
    });

    testWidgets('响应式布局无溢出（窄屏与宽屏）', (tester) async {
      final rig = _rig();
      // 窄屏
      tester.view.physicalSize = const Size(390 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(() => tester.view.reset());

      await pumpApp(tester, rig, location: '/accounts/exchange/ex1');
      expect(tester.takeException(), isNull);

      // 宽屏
      tester.view.physicalSize = const Size(1280 * 2, 900 * 2);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
