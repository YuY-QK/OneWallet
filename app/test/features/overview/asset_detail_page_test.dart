import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/features/overview/presentation/asset_detail_page.dart';
import 'package:onewallet/features/overview/presentation/widgets/asset_contract_row.dart';
import 'package:onewallet/features/overview/presentation/widgets/asset_distribution_row.dart';
import 'package:onewallet/widgets/formatters.dart';
import 'package:onewallet/widgets/ow_secondary_button.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

TestRig _detailRig() {
  final rig = TestRig();

  // 1 个钱包账户
  final w1 = rig.addWallet('w1', 'MetaMask 钱包');
  final d1 = rig.addAddress(
    'd1',
    w1.id,
    '0x1111111111111111111111111111111111111111',
  );

  // 1 个交易所账户
  final ex1 = rig.addExchange('ex1', 'Binance 主账户', ExchangeId.binance);

  // 钱包持仓：USDT (Arbitrum 合约代币 100 个)
  rig.addHolding(
    w1.id,
    d1.id,
    chainId: 'arbitrum',
    symbol: 'USDT',
    assetId: 'USDT',
    amount: '100',
    price: '1.00',
    token: const ContractToken(
      'arbitrum',
      '0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9',
    ),
  );

  // 交易所持仓：USDT (现货 200 个)
  rig.addExchangeHolding(
    ex1.id,
    sub: ExchangeSubAccount.spot,
    symbol: 'USDT',
    assetId: 'USDT',
    amount: '200',
    price: '1.00',
  );

  // 设置价格带 24h 涨幅
  rig.prices.feed.value = {
    'USDT': Price(
      assetId: 'USDT',
      quote: Quote.usd,
      price: Decimal.parse('1.00'),
      change24hPercent: Decimal.parse('0.05'),
      updatedAt: DateTime.utc(2026, 11, 12, 12),
    ),
  };

  // 记录最近同步时间（3分钟前，避免进入页面触发自动同步清空测试持仓）
  rig.record(w1.id, at: DateTime.utc(2026, 11, 12, 11, 57));
  rig.record(ex1.id, at: DateTime.utc(2026, 11, 12, 11, 57));

  return rig;
}

void main() {
  group('P09 币种详情 页面展示与交互', () {
    testWidgets('正常展示_价格_涨跌幅_总量_估值_分布_合约', (tester) async {
      final rig = _detailRig();
      await pumpApp(tester, rig, location: '/overview/asset/USDT');

      expect(find.byType(AssetDetailPage), findsOneWidget);
      expect(find.text('USDT'), findsWidgets);

      // 价格与 24h 涨跌
      expect(find.text(r'$1.00'), findsWidgets);
      expect(find.text('+0.05%'), findsOneWidget);

      // 持仓总量 300，估值 $300.00
      expect(find.text('300'), findsOneWidget);
      expect(find.text(r'$300.00'), findsOneWidget);

      // 分布项
      expect(find.byType(AssetDistributionRowTile), findsNWidgets(2));
      expect(find.text('MetaMask 钱包'), findsOneWidget);
      expect(find.text('Binance 主账户'), findsOneWidget);
      expect(find.text('Arbitrum'), findsWidgets);
      expect(find.text('现货'), findsOneWidget);

      // 合约项
      expect(find.byType(AssetContractRowTile), findsWidgets);
      expect(find.text('复制'), findsWidgets);
    });

    testWidgets('隐藏金额时_隐藏总量与估值_但保留占比', (tester) async {
      final rig = _detailRig();
      rig.settings.feed.value = const AppSettings(hideAmounts: true);
      await pumpApp(tester, rig, location: '/overview/asset/USDT');

      expect(find.text(hiddenAmountMask), findsWidgets);
      // 占比依然可见
      expect(find.textContaining('%'), findsWidgets);
    });

    testWidgets('无价格代币_估值与单价显示横杠', (tester) async {
      final rig = TestRig();
      final w1 = rig.addWallet('w1', '我的钱包');
      final d1 = rig.addAddress(
        'd1',
        w1.id,
        '0x2222222222222222222222222222222222222222',
      );
      rig.addHolding(
        w1.id,
        d1.id,
        chainId: 'ethereum',
        symbol: 'CUSTOM',
        assetId: 'CUSTOM',
        amount: '50',
        price: null,
      );
      rig.record(w1.id, at: DateTime.utc(2026, 11, 12, 11, 57));

      await pumpApp(tester, rig, location: '/overview/asset/CUSTOM');

      expect(find.byType(AssetDetailPage), findsOneWidget);
      expect(find.text('CUSTOM'), findsWidgets);
      expect(find.text('—'), findsWidgets);
      expect(find.text('50'), findsWidgets);
    });

    testWidgets('复制合约地址_写入剪贴板并提示已复制', (tester) async {
      final rig = _detailRig();
      await pumpApp(tester, rig, location: '/overview/asset/USDT');

      final copyButtons = find.widgetWithText(OwSecondaryButton, '复制');
      expect(copyButtons, findsWidgets);

      await tester.tap(copyButtons.first);
      await tester.pumpAndSettle();

      expect(rig.copied, isNotEmpty);
      expect(find.text('已复制合约地址'), findsOneWidget);
    });

    testWidgets('点击分布行_钱包跳转至P07_交易所跳转至P08', (tester) async {
      final rig = _detailRig();
      final router = await pumpApp(
        tester,
        rig,
        location: '/overview/asset/USDT',
      );

      // 点击钱包行
      await tester.tap(find.text('MetaMask 钱包'));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/accounts/wallet/w1');

      // 返回并重新进入
      router.go('/overview/asset/USDT');
      await tester.pumpAndSettle();

      // 点击交易所行
      await tester.tap(find.text('Binance 主账户'));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/accounts/exchange/ex1');
    });

    testWidgets('响应式_窄屏与宽屏正常排版无溢出', (tester) async {
      final rig = _detailRig();

      // 窄屏
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpApp(tester, rig, location: '/overview/asset/USDT');
      expect(tester.takeException(), isNull);

      // 宽屏
      tester.view.physicalSize = const Size(1280, 900);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
