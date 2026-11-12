import 'dart:async';

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

    testWidgets('点击交易所行_进入说明页', (tester) async {
      final router = await pumpApp(tester, _rig(), location: '/accounts');
      await tester.tap(find.text('Binance 主账户'));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/accounts/exchange/x1');
      expect(find.text('此功能将在后续版本提供。'), findsOneWidget);
    });

    testWidgets('右上角加号_进入P04', (tester) async {
      final router = await pumpApp(tester, _rig(), location: '/accounts');
      await tester.tap(find.byTooltip('添加账户'));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/accounts/add');
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
