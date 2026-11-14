import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/widgets/ow_danger_button.dart';
import 'package:onewallet/widgets/ow_skeleton.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

const _lower = '0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed';
const _eip55 = '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed';
const _btc = '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa';

/// 有一个 EVM 地址的钱包；ETH 分布在 Ethereum（1.5）与 Base（0.5）。
TestRig _rig({bool withBitcoin = false}) {
  final rig = TestRig();
  final a = rig.addWallet(
    'a1',
    'Uni 钱包',
    source: WalletSource.uniswap,
    vaultItemId: 'v1',
  );
  final d = rig.addAddress('d1', a.id, _lower);
  rig.addHolding(a.id, d.id, amount: '1.5');
  rig.addHolding(a.id, d.id, chainId: 'base', amount: '0.5');
  rig.addHolding(
    a.id,
    d.id,
    symbol: 'JUNK',
    assetId: null,
    token: const ContractToken('ethereum', '0xjunk'),
  );
  if (withBitcoin) {
    rig.addAddress('d2', a.id, _btc, family: ChainFamily.bitcoin);
  }
  rig.record(a.id);
  return rig;
}

void main() {
  group('P07 页面状态', () {
    testWidgets('加载_从未同步_骨架屏并触发该账户同步_完成后显示无资产', (tester) async {
      final rig = TestRig();
      final a = rig.addWallet('a1', 'Uni 钱包');
      rig.addAddress('d1', a.id, _lower, chains: {'ethereum'});
      final gate = Completer<void>();
      rig.registry[ChainFamily.evm].gate = gate;
      await pumpApp(
        tester,
        rig,
        location: '/accounts/wallet/a1',
        settle: false,
      );
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(OwSkeleton), findsOneWidget);
      expect(rig.registry[ChainFamily.evm].fetchCount, 1);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(OwSkeleton), findsNothing);
      expect(find.text('该钱包目前没有可显示的资产'), findsOneWidget);
    });

    testWidgets('正常_总估值_备份标签_币种汇总', (tester) async {
      await pumpApp(tester, _rig(), location: '/accounts/wallet/a1');
      expect(find.text('Uni 钱包'), findsOneWidget);
      expect(find.text('账户总估值'), findsOneWidget);
      expect(find.text(r'$4,000.00'), findsWidgets);
      expect(find.text('已入库'), findsOneWidget);
      expect(find.text('ETH'), findsWidgets);
      expect(find.text('2'), findsOneWidget);
      expect(find.textContaining('同步失败'), findsNothing);
    });

    testWidgets('同步失败_显示原因与上次成功时间_缓存数据仍显示', (tester) async {
      final rig = _rig();
      rig.record('a1', success: false, failureType: 'NetworkFailure');
      await pumpApp(tester, rig, location: '/accounts/wallet/a1');
      expect(find.textContaining('同步失败：网络不可用'), findsOneWidget);
      expect(find.textContaining('上次成功同步：3 分钟前'), findsOneWidget);
      expect(find.text('ETH'), findsWidgets);
    });

    testWidgets('同步失败_上次成功时间取账户级记录而不是持仓的更新时间', (tester) async {
      final rig = _rig();
      // 持仓更新于 11:57；账户级最近成功时间是 11:40（20 分钟前）。
      rig.record('a1', at: DateTime.utc(2026, 11, 12, 11, 40));
      rig.record('a1', success: false, failureType: 'NetworkFailure');
      await pumpApp(tester, rig, location: '/accounts/wallet/a1');
      expect(find.textContaining('上次成功同步：20 分钟前'), findsOneWidget);
    });

    testWidgets('同步失败_从未成功过_说明没有缓存', (tester) async {
      final rig = TestRig();
      final a = rig.addWallet('a1', 'Uni 钱包');
      rig.addAddress('d1', a.id, _btc, family: ChainFamily.bitcoin);
      rig.record(
        a.id,
        success: false,
        failureType: 'UnsupportedFailure.notIntegrated',
      );
      await pumpApp(tester, rig, location: '/accounts/wallet/a1');
      expect(find.textContaining('暂不支持'), findsOneWidget);
      expect(find.textContaining('还没有成功同步过'), findsOneWidget);
      expect(find.text('该钱包目前没有可显示的资产'), findsNothing);
    });

    testWidgets('无资产_同步成功但没有持仓', (tester) async {
      final rig = TestRig();
      final a = rig.addWallet('a1', 'Uni 钱包');
      rig.addAddress('d1', a.id, _lower);
      rig.record(a.id);
      await pumpApp(tester, rig, location: '/accounts/wallet/a1');
      expect(find.text('该钱包目前没有可显示的资产'), findsOneWidget);
    });

    testWidgets('账户不存在_显示说明', (tester) async {
      await pumpApp(tester, _rig(), location: '/accounts/wallet/zzz');
      expect(find.text('找不到这个账户，它可能已被删除。'), findsOneWidget);
    });

    testWidgets('下拉刷新_只同步该账户', (tester) async {
      final rig = _rig();
      final b = rig.addWallet('a2', '另一个');
      rig.addAddress('d9', b.id, '0x9999999999999999999999999999999999999999');
      rig.record(b.id);
      await pumpApp(tester, rig, location: '/accounts/wallet/a1');
      expect(rig.registry[ChainFamily.evm].fetchCount, 0);
      await tester.fling(
        find.byType(ListView).first,
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
      final fetched = rig.registry[ChainFamily.evm].fetched;
      expect(fetched, isNotEmpty);
      expect(fetched.toSet(), {_lower});
    });
  });

  group('P07 资产分段', () {
    testWidgets('行可展开_显示各链明细', (tester) async {
      await pumpApp(tester, _rig(), location: '/accounts/wallet/a1');
      expect(find.text('Ethereum'), findsNothing);
      await tester.tap(find.text('ETH').first);
      await tester.pumpAndSettle();
      expect(find.text('Ethereum'), findsOneWidget);
      expect(find.text('Base'), findsOneWidget);
      expect(find.text('1.5'), findsOneWidget);
      expect(find.text('0.5'), findsOneWidget);
    });

    testWidgets('无估值币种_折叠在统计行里_展开后显示破折号', (tester) async {
      await pumpApp(tester, _rig(), location: '/accounts/wallet/a1');
      expect(find.text('JUNK'), findsNothing);
      await tester.tap(find.text('1 个未识别或无估值的币种'));
      await tester.pumpAndSettle();
      expect(find.text('JUNK'), findsWidgets);
      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('隐藏金额_估值与数量显示星号', (tester) async {
      final rig = _rig();
      rig.settings.feed.value = rig.settings.feed.value.copyWith(
        hideAmounts: true,
      );
      await pumpApp(tester, rig, location: '/accounts/wallet/a1');
      expect(find.text(r'$4,000.00'), findsNothing);
      expect(find.text('2'), findsNothing);
      expect(find.text('****'), findsWidgets);
    });
  });

  group('P07 地址分段与操作面板', () {
    Future<void> openAddresses(WidgetTester tester) async {
      await tester.tap(find.text('地址'));
      await tester.pumpAndSettle();
    }

    testWidgets('按链家族分组_缩略地址与估值', (tester) async {
      await pumpApp(
        tester,
        _rig(withBitcoin: true),
        location: '/accounts/wallet/a1',
      );
      await openAddresses(tester);
      expect(find.text('EVM'), findsWidgets);
      expect(find.text('Bitcoin'), findsWidgets);
      expect(find.text('0x5aAe…eAed'), findsOneWidget);
      expect(find.text('6 条链'), findsOneWidget);
      expect(find.text('1A1zP1…vfNa'), findsOneWidget);
      expect(find.text(r'$4,000.00'), findsWidgets);
    });

    testWidgets('添加地址_进入P05的追加模式', (tester) async {
      await pumpApp(tester, _rig(), location: '/accounts/wallet/a1');
      await openAddresses(tester);
      await tester.ensureVisible(find.text('添加地址'));
      await tester.tap(find.text('添加地址'));
      await tester.pumpAndSettle();
      expect(find.text('账户名称'), findsOneWidget);
      expect(find.text('备份状态'), findsNothing);
    });

    testWidgets('面板_完整EIP55地址_二维码_复制', (tester) async {
      final rig = _rig();
      await pumpApp(tester, rig, location: '/accounts/wallet/a1');
      await openAddresses(tester);
      await tester.tap(find.text('0x5aAe…eAed'));
      await tester.pumpAndSettle();
      expect(find.text(_eip55), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      await tester.tap(find.text('复制地址'));
      await tester.pumpAndSettle();
      expect(rig.copied, [_eip55]);
      expect(find.text('已复制'), findsOneWidget);
    });

    testWidgets('面板_列出各链浏览器和完整域名_点击用系统浏览器打开', (tester) async {
      final rig = _rig();
      await pumpApp(tester, rig, location: '/accounts/wallet/a1');
      await openAddresses(tester);
      await tester.tap(find.text('0x5aAe…eAed'));
      await tester.pumpAndSettle();
      expect(find.text('Ethereum · etherscan.io'), findsOneWidget);
      expect(find.text('Base · basescan.org'), findsOneWidget);
      expect(find.text('Polygon · polygonscan.com'), findsOneWidget);
      await tester.ensureVisible(find.text('Base · basescan.org'));
      await tester.tap(find.text('Base · basescan.org'));
      await tester.pumpAndSettle();
      expect(
        rig.opened.single.toString(),
        'https://basescan.org/address/$_eip55',
      );
    });

    testWidgets('面板_浏览器打不开_提示失败', (tester) async {
      final rig = _rig()..openSucceeds = false;
      await pumpApp(tester, rig, location: '/accounts/wallet/a1');
      await openAddresses(tester);
      await tester.tap(find.text('0x5aAe…eAed'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Ethereum · etherscan.io'));
      await tester.tap(find.text('Ethereum · etherscan.io'));
      await tester.pumpAndSettle();
      expect(find.text('无法打开系统浏览器。'), findsOneWidget);
    });

    testWidgets('只剩一个地址_不能删除并说明原因', (tester) async {
      await pumpApp(tester, _rig(), location: '/accounts/wallet/a1');
      await openAddresses(tester);
      await tester.tap(find.text('0x5aAe…eAed'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(OwDangerButton));
      expect(find.text('账户至少要保留一个地址，所以不能删除最后一个地址。'), findsOneWidget);
      final button = tester.widget<OutlinedButton>(
        find.descendant(
          of: find.byType(OwDangerButton),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('有多个地址_二次确认后删除', (tester) async {
      final rig = _rig(withBitcoin: true);
      await pumpApp(tester, rig, location: '/accounts/wallet/a1');
      await openAddresses(tester);
      await tester.tap(find.text('1A1zP1…vfNa'));
      await tester.pumpAndSettle();
      expect(find.text('口径说明：只含已确认余额，未确认交易不计入。'), findsOneWidget);
      await tester.ensureVisible(find.byType(OwDangerButton));
      await tester.tap(find.byType(OwDangerButton));
      await tester.pumpAndSettle();
      expect(find.text('删除这个地址？'), findsOneWidget);
      // 取消不删除。
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(rig.addresses.feed.value, hasLength(2));

      await tester.tap(find.byType(OwDangerButton));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('删除地址'),
        ),
      );
      await tester.pumpAndSettle();
      expect(rig.addresses.feed.value.map((a) => a.id), ['d1']);
      expect(find.text('1A1zP1…vfNa'), findsNothing);
    });
  });
}
