import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/features/overview/controllers/overview_controller.dart';
import 'package:onewallet/features/overview/presentation/overview_page.dart';
import 'package:ow_domain/ow_domain.dart';

import '../support/fakes.dart';
import '../support/pump_app.dart';

void main() {
  testWidgets('集成测试：添加 EVM 地址 -> 总览显示资产', (tester) async {
    final rig = TestRig();
    rig.registry[ChainFamily.evm]
      ..onlyChain = 'ethereum'
      ..holdings = [
        RawHolding(
          token: const NativeToken('ethereum'),
          amount: Decimal.parse('2.5'),
        ),
      ];

    await pumpApp(
      tester,
      rig,
      location: '/overview',
      size: const Size(1024, 800),
    );

    // 1. 验证总览页初始为空状态
    expect(find.text('还没有账户'), findsOneWidget);
    expect(find.text('添加第一个账户'), findsOneWidget);

    // 2. 点击"添加第一个账户"，跳转至 P04 添加账户类型选择页
    await tester.tap(find.text('添加第一个账户'));
    await tester.pumpAndSettle();
    expect(find.text('添加账户'), findsOneWidget);
    expect(find.text('观察链上地址'), findsOneWidget);

    // 3. 点击"观察链上地址"，跳转至 P05 添加钱包页
    await tester.tap(find.text('观察链上地址'));
    await tester.pumpAndSettle();
    expect(find.text('账户名称'), findsOneWidget);

    // 4. 输入钱包名称与 EVM 地址
    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(2)); // 名称输入框 + 地址输入框
    await tester.enterText(textFields.at(0), '我的主钱包');
    await tester.enterText(
      textFields.at(1),
      '0x1111111111111111111111111111111111111111',
    );
    await tester.pumpAndSettle();

    // 验证识别为 EVM / Ethereum
    expect(find.text('Ethereum'), findsWidgets);
    expect(find.textContaining('EVM'), findsWidgets);

    // 5. 滚动并点击"保存"，保存钱包并触发异步同步
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();

    final saveButton = find.widgetWithText(FilledButton, '保存');
    expect(saveButton, findsOneWidget);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // 验证跳转到了钱包详情页
    expect(find.text('我的主钱包'), findsWidgets);

    // 6. 点击侧栏"总览"，切换回总览页
    final overviewTab = find.text('总览');
    expect(overviewTab, findsWidgets);
    await tester.tap(overviewTab.first);
    await tester.pumpAndSettle();

    // 触发全量同步（获取最新价格并计算估值）
    final overviewElement = tester.element(find.byType(OverviewPage));
    final container = ProviderScope.containerOf(overviewElement);
    await container.read(overviewSyncProvider.notifier).refresh();
    await tester.pumpAndSettle();

    // 7. 验证总览页成功显示资产
    // 2.5 ETH * $2000 = $5,000.00
    expect(find.text('还没有账户'), findsNothing);
    expect(find.textContaining('5,000'), findsWidgets);
    expect(find.text('ETH'), findsWidgets);
    expect(find.textContaining('2.5'), findsWidgets);
  });
}
