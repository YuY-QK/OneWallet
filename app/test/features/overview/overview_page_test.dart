import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/widgets/ow_skeleton.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

const _addr = '0x1111111111111111111111111111111111111111';

/// 一个钱包账户，持有 2 ETH（$4,000）、一笔小额币和一笔无价格代币。
TestRig _richRig() {
  final rig = TestRig();
  final a = rig.addWallet('a1', 'Uni 钱包');
  final d = rig.addAddress('d1', a.id, _addr);
  rig.addHolding(a.id, d.id, amount: '2');
  rig.addHolding(
    a.id,
    d.id,
    symbol: 'DUST',
    assetId: 'DUST',
    amount: '0.1',
    price: '1',
  );
  rig.addHolding(
    a.id,
    d.id,
    symbol: 'JUNK',
    assetId: null,
    token: const ContractToken('ethereum', '0xjunk'),
  );
  // 最近一次同步是 3 分钟前：进入页面时不自动同步。
  rig.record(a.id, at: DateTime.utc(2026, 11, 12, 11, 57));
  // 让同步成功时写回与种子一致的持仓。
  rig.registry[ChainFamily.evm]
    ..onlyChain = 'ethereum'
    ..holdings = [
      RawHolding(
        token: const NativeToken('ethereum'),
        amount: Decimal.parse('2'),
      ),
    ];
  return rig;
}

Finder get _eye => find.byIcon(Icons.visibility_outlined);

void main() {
  group('P02 页面状态', () {
    testWidgets('空_没有账户_引导添加并进入P04', (tester) async {
      final rig = TestRig();
      final router = await pumpApp(tester, rig);
      expect(find.text('还没有账户'), findsOneWidget);
      await tester.tap(find.text('添加第一个账户'));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/accounts/add');
      // 空状态下不触发同步。
      expect(rig.registry[ChainFamily.evm].fetchCount, 0);
    });

    testWidgets('加载_无缓存_骨架屏加进度条_同步完成后显示内容', (tester) async {
      final rig = TestRig();
      final a = rig.addWallet('a1', 'Uni 钱包');
      rig.addAddress('d1', a.id, _addr, chains: {'ethereum'});
      final gate = Completer<void>();
      rig.registry[ChainFamily.evm]
        ..gate = gate
        ..holdings = [
          RawHolding(
            token: const NativeToken('ethereum'),
            amount: Decimal.parse('2'),
          ),
        ];
      await pumpApp(tester, rig, settle: false);
      await tester.pump();
      await tester.pump();
      expect(find.byType(OwSkeleton), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('总资产（USD）'), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(OwSkeleton), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text(r'$4,000.00'), findsWidgets);
    });

    testWidgets('加载_有缓存_先显示缓存并带进度条', (tester) async {
      final rig = _richRig();
      // 缓存已过期 → 进入时自动同步；同步卡住。
      rig.record('a1', at: DateTime.utc(2026, 11, 12, 10));
      rig.registry[ChainFamily.evm].gate = Completer<void>();
      await pumpApp(tester, rig, settle: false);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text(r'$4,000.00'), findsWidgets);
      expect(find.byType(OwSkeleton), findsNothing);
    });

    testWidgets('部分失败_提醒条_点击列出失败账户', (tester) async {
      final rig = _richRig();
      final b = rig.addWallet('a2', 'Bitcoin 钱包');
      rig.addAddress(
        'd2',
        b.id,
        '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa',
        family: ChainFamily.bitcoin,
      );
      rig.record(
        b.id,
        success: false,
        failureType: 'UnsupportedFailure.notIntegrated',
        at: DateTime.utc(2026, 11, 12, 11, 58),
      );
      await pumpApp(tester, rig);
      expect(find.text('1 个账户同步失败'), findsOneWidget);
      expect(find.text(r'$4,000.00'), findsWidgets);
      await tester.tap(find.text('1 个账户同步失败'));
      await tester.pumpAndSettle();
      expect(find.text('同步失败的账户'), findsOneWidget);
      expect(find.text('Bitcoin 钱包'), findsOneWidget);
      expect(find.textContaining('暂不支持'), findsOneWidget);
    });

    testWidgets('全部失败且无缓存_错误说明与重试', (tester) async {
      final rig = TestRig();
      final a = rig.addWallet('a1', 'Uni 钱包');
      rig.addAddress('d1', a.id, _addr, chains: {'ethereum'});
      rig.registry[ChainFamily.evm].failure = const ServiceDownFailure();
      await pumpApp(tester, rig);
      expect(find.text('同步失败'), findsOneWidget);
      expect(find.textContaining('所有账户都没能同步'), findsOneWidget);
      final before = rig.registry[ChainFamily.evm].fetchCount;
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(rig.registry[ChainFamily.evm].fetchCount, greaterThan(before));
    });

    testWidgets('离线_全部失败都是网络失败_显示缓存和离线提示', (tester) async {
      final rig = _richRig();
      rig.record('a1', at: DateTime.utc(2026, 11, 12, 10)); // 过期，进入时同步
      rig.registry[ChainFamily.evm].failure = const NetworkFailure();
      await pumpApp(tester, rig);
      expect(find.textContaining('当前离线，显示的是'), findsOneWidget);
      expect(find.textContaining('3 分钟前'), findsWidgets);
      expect(find.text(r'$4,000.00'), findsWidgets);
      expect(find.textContaining('个账户同步失败'), findsNothing);
    });
  });

  group('P02 内容', () {
    testWidgets('总资产卡片与底部统计行', (tester) async {
      final rig = _richRig();
      await pumpApp(tester, rig);
      expect(find.text('总资产（USD）'), findsOneWidget);
      expect(find.text(r'$4,000.00'), findsWidgets);
      expect(find.text('3 分钟前同步'), findsNothing);
      expect(find.textContaining('上次同步 3 分钟前'), findsOneWidget);
      expect(find.text('1 个币种无估值 · 已隐藏 1 个小额币种'), findsOneWidget);
      // 24 小时变化无数据时显示破折号。
      expect(find.text('24 小时变化 —'), findsOneWidget);
    });

    testWidgets('分布切换_按币种_按账户_按类型', (tester) async {
      final rig = _richRig();
      await pumpApp(tester, rig);
      expect(find.text('ETH'), findsWidgets);
      await tester.tap(find.text('按账户'));
      await tester.pumpAndSettle();
      expect(find.text('Uni 钱包'), findsOneWidget);
      await tester.tap(find.text('按类型'));
      await tester.pumpAndSettle();
      expect(find.text('链上钱包'), findsOneWidget);
      expect(find.text('交易所'), findsOneWidget);
    });

    testWidgets('点击账户行进入P07_点击币种行进入币种说明页', (tester) async {
      final rig = _richRig();
      final router = await pumpApp(tester, rig);
      await tester.tap(find.text('按账户'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Uni 钱包'));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/accounts/wallet/a1');

      router.go('/overview');
      await tester.pumpAndSettle();
      await tester.tap(find.text('按币种'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ETH').first);
      await tester.pumpAndSettle();
      expect(find.text('此功能将在后续版本提供。'), findsOneWidget);
    });

    testWidgets('隐藏金额_开关写入设置_金额显示为星号', (tester) async {
      final rig = _richRig();
      await pumpApp(tester, rig);
      expect(find.text(r'$4,000.00'), findsWidgets);
      await tester.tap(_eye);
      await tester.pumpAndSettle();
      expect(rig.settings.feed.value.hideAmounts, isTrue);
      expect(find.text(r'$4,000.00'), findsNothing);
      expect(find.text('****'), findsWidgets);
    });

    testWidgets('下拉刷新_触发全量同步', (tester) async {
      final rig = _richRig();
      await pumpApp(tester, rig);
      expect(rig.registry[ChainFamily.evm].fetchCount, 0);
      await tester.fling(
        find.byType(ListView).first,
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
      expect(rig.registry[ChainFamily.evm].fetchCount, greaterThan(0));
      expect(rig.priceSource.fetchCount, greaterThan(0));
    });

    testWidgets('进入页面_距上次同步不足5分钟_不自动同步', (tester) async {
      final rig = _richRig();
      await pumpApp(tester, rig);
      expect(rig.registry[ChainFamily.evm].fetchCount, 0);
    });

    testWidgets('进入页面_超过5分钟_自动同步', (tester) async {
      final rig = _richRig();
      rig.record('a1', at: DateTime.utc(2026, 11, 12, 11, 50));
      await pumpApp(tester, rig);
      expect(rig.registry[ChainFamily.evm].fetchCount, greaterThan(0));
    });
  });

  group('P02 不同屏宽下无溢出', () {
    for (final size in const [Size(390, 800), Size(1280, 900)]) {
      testWidgets('渲染_${size.width.toInt()}宽_无溢出异常', (tester) async {
        final rig = _richRig();
        await pumpApp(tester, rig, size: size);
        await tester.tap(find.text('按账户'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
