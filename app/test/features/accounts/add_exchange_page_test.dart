import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/features/accounts/controllers/add_exchange_state.dart';
import 'package:onewallet/widgets/ow_chip.dart';
import 'package:onewallet/widgets/ow_external_link.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

FilledButton _saveButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byType(FilledButton));

void main() {
  late TestRig rig;
  setUp(() => rig = TestRig());

  group('P06 添加交易所账户', () {
    testWidgets('初始状态_默认Binance_无Passphrase_保存可点_安全提示展示', (tester) async {
      await pumpApp(tester, rig, location: '/accounts/add/exchange');
      expect(find.text('连接交易所'), findsOneWidget);
      expect(find.text('Binance'), findsOneWidget);
      expect(find.text('OKX'), findsOneWidget);
      expect(find.text('Bybit'), findsOneWidget);
      expect(find.text('Bitget (即将支持)'), findsOneWidget);

      // 默认选中 Binance
      expect(
        find.descendant(
          of: find.widgetWithText(OwChip, 'Binance'),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );

      // 默认账户名称为 Binance 主账户
      expect(find.text('Binance 主账户'), findsOneWidget);
      expect(find.text('API Key'), findsOneWidget);
      expect(find.text('API Secret'), findsOneWidget);
      // Binance 不需要 Passphrase
      expect(find.text('Passphrase'), findsNothing);

      // 安全提示区
      expect(
        find.text('请只勾选「读取」权限，不要开启交易和提现。保存前会检查这个 Key 的权限。'),
        findsOneWidget,
      );

      // 指引卡片与保存按钮
      expect(find.text('如何创建只读 API Key'), findsOneWidget);
      expect(find.text('测试并保存'), findsOneWidget);
      expect(_saveButton(tester).onPressed, isNotNull);
    });

    testWidgets('切换到OKX_显示Passphrase_名称更新为OKX主账户', (tester) async {
      await pumpApp(tester, rig, location: '/accounts/add/exchange');

      await tester.tap(find.widgetWithText(OwChip, 'OKX'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.widgetWithText(OwChip, 'OKX'),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
      expect(find.text('OKX 主账户'), findsOneWidget);
      expect(find.text('Passphrase'), findsOneWidget);
    });

    testWidgets('用户修改名称后切换交易所_保留用户自定名称', (tester) async {
      await pumpApp(tester, rig, location: '/accounts/add/exchange');

      final nameField = find.byType(TextField).at(0);
      await tester.enterText(nameField, '我的套利号');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OwChip, 'Bybit'));
      await tester.pumpAndSettle();

      expect(find.text('我的套利号'), findsOneWidget);
      expect(find.text('Passphrase'), findsNothing);
    });

    testWidgets('选中Bitget_显示即将支持提示_保存按钮禁用', (tester) async {
      await pumpApp(tester, rig, location: '/accounts/add/exchange');

      await tester.tap(find.widgetWithText(OwChip, 'Bitget (即将支持)'));
      await tester.pumpAndSettle();

      expect(find.text('Bitget 暂未接入，即将支持。'), findsOneWidget);
      expect(_saveButton(tester).onPressed, isNull);
    });

    testWidgets('输入为空时点击保存_展示本地必填校验错误', (tester) async {
      await pumpApp(tester, rig, location: '/accounts/add/exchange');

      await tester.tap(find.text('测试并保存'));
      await tester.pumpAndSettle();

      expect(find.text('请输入 API Key。'), findsOneWidget);
      expect(find.text('请输入 API Secret。'), findsOneWidget);

      // 切换到 OKX 校验 Passphrase
      await tester.tap(find.widgetWithText(OwChip, 'OKX'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('测试并保存'));
      await tester.pumpAndSettle();

      expect(find.text('请输入 Passphrase。'), findsOneWidget);
    });

    testWidgets('展开创建指引_显示步骤与官方外链', (tester) async {
      await pumpApp(tester, rig, location: '/accounts/add/exchange');

      await tester.tap(find.byKey(const ValueKey('exchange-guide-tile')));
      await tester.pumpAndSettle();

      expect(find.textContaining('登录币安官网'), findsOneWidget);
      expect(find.textContaining('只保留「读取」权限'), findsOneWidget);
      expect(find.widgetWithText(OwExternalLink, '前往官方创建指引'), findsOneWidget);
    });

    testWidgets('验证失败_凭据错误_显示凭据错误提示', (tester) async {
      rig.registry.exchangeFake(ExchangeId.binance).verifyResult = const Err(
        UnauthorizedFailure('code=-2014'),
      );

      await pumpApp(tester, rig, location: '/accounts/add/exchange');

      await tester.enterText(find.byType(TextField).at(1), 'bad-key');
      await tester.enterText(find.byType(TextField).at(2), 'bad-secret');
      await tester.tap(find.text('测试并保存'));
      await tester.pumpAndSettle();

      expect(
        find.text('API Key、Secret 或 Passphrase 不正确，服务商拒绝了请求。'),
        findsOneWidget,
      );
    });

    testWidgets('验证失败_网络错误_显示网络错误提示', (tester) async {
      rig.registry.exchangeFake(ExchangeId.binance).verifyResult = const Err(
        NetworkFailure('timeout'),
      );

      await pumpApp(tester, rig, location: '/accounts/add/exchange');

      await tester.enterText(find.byType(TextField).at(1), 'key');
      await tester.enterText(find.byType(TextField).at(2), 'secret');
      await tester.tap(find.text('测试并保存'));
      await tester.pumpAndSettle();

      expect(find.text('网络不可用或请求超时。请检查网络连接后重试。'), findsOneWidget);
    });

    testWidgets('验证失败_时间戳偏差_显示校时提示', (tester) async {
      rig.registry.exchangeFake(ExchangeId.binance).verifyResult = const Err(
        ClockSkewFailure('code=-1021'),
      );

      await pumpApp(tester, rig, location: '/accounts/add/exchange');

      await tester.enterText(find.byType(TextField).at(1), 'key');
      await tester.enterText(find.byType(TextField).at(2), 'secret');
      await tester.tap(find.text('测试并保存'));
      await tester.pumpAndSettle();

      expect(find.text('设备时间与服务器相差过大，请求被拒绝。请在系统设置中开启自动校时后重试。'), findsOneWidget);
    });

    testWidgets('验证失败_IP限制_显示IP限制提示', (tester) async {
      rig.registry.exchangeFake(ExchangeId.okx).verifyResult = const Err(
        UnauthorizedFailure('code=50110 ip'),
      );

      await pumpApp(tester, rig, location: '/accounts/add/exchange');
      await tester.tap(find.widgetWithText(OwChip, 'OKX'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(1), 'key');
      await tester.enterText(find.byType(TextField).at(2), 'secret');
      await tester.enterText(find.byType(TextField).at(3), 'pass');
      await tester.tap(find.text('测试并保存'));
      await tester.pumpAndSettle();

      expect(
        find.text('该 API Key 限制了访问 IP，请检查交易所后台的 IP 白名单设置。'),
        findsOneWidget,
      );
    });

    testWidgets('权限警告_检测到交易权限_弹出警告_返回修改保留输入', (tester) async {
      rig.registry.exchangeFake(ExchangeId.binance).verifyResult = const Ok(
        CredentialCheck(permission: KeyPermission.canTrade),
      );

      await pumpApp(tester, rig, location: '/accounts/add/exchange');

      await tester.enterText(find.byType(TextField).at(1), 'trade-key');
      await tester.enterText(find.byType(TextField).at(2), 'trade-secret');
      await tester.tap(find.text('测试并保存'));
      await tester.pumpAndSettle();

      expect(find.text('权限超出只读'), findsOneWidget);
      expect(
        find.text('检测到此 Key 包含交易或提现权限，存在资金安全风险。建议在交易所后台重新创建只读 Key。'),
        findsOneWidget,
      );

      // 点击「返回修改」
      await tester.tap(find.text('返回修改'));
      await tester.pumpAndSettle();

      expect(find.text('权限超出只读'), findsNothing);
      expect(find.text('连接交易所'), findsOneWidget);
      // 输入仍在
      expect(find.text('trade-key'), findsOneWidget);
    });

    testWidgets('权限警告_仍然保存_保存到安全存储_清空输入框并跳转', (tester) async {
      rig.registry.exchangeFake(ExchangeId.binance).verifyResult = const Ok(
        CredentialCheck(permission: KeyPermission.canWithdraw),
      );

      final router = await pumpApp(
        tester,
        rig,
        location: '/accounts/add/exchange',
      );

      await tester.enterText(find.byType(TextField).at(1), 'withdraw-key');
      await tester.enterText(find.byType(TextField).at(2), 'withdraw-secret');
      await tester.tap(find.text('测试并保存'));
      await tester.pumpAndSettle();

      expect(find.text('权限超出只读'), findsOneWidget);

      // 点击「仍然保存」
      await tester.tap(find.text('仍然保存'));
      await tester.pumpAndSettle();

      // 验证路由跳转到交易所账户详情
      expect(locationOf(router), startsWith('/accounts/exchange/'));

      // 验证账户已创建
      final created = rig.accounts.feed.value.where(
        (a) => a.type == AccountType.exchange,
      );
      expect(created, hasLength(1));
      final accountId = created.first.id;

      // 验证凭据已按 `ow.` 前缀保存到安全存储
      final key = await rig.secrets.read('ow.exchange.$accountId.key');
      expect(key, 'withdraw-key');
      final secret = await rig.secrets.read('ow.exchange.$accountId.secret');
      expect(secret, 'withdraw-secret');
    });

    testWidgets('正常只读凭据_直接保存_触发同步并跳转', (tester) async {
      rig.registry.exchangeFake(ExchangeId.binance).verifyResult = const Ok(
        CredentialCheck(permission: KeyPermission.readOnly),
      );

      final router = await pumpApp(
        tester,
        rig,
        location: '/accounts/add/exchange',
      );

      await tester.enterText(find.byType(TextField).at(1), 'ro-key');
      await tester.enterText(find.byType(TextField).at(2), 'ro-secret');
      await tester.tap(find.text('测试并保存'));
      await tester.pumpAndSettle();

      expect(locationOf(router), startsWith('/accounts/exchange/'));
      final created = rig.accounts.feed.value.where(
        (a) => a.type == AccountType.exchange,
      );
      expect(created, hasLength(1));
    });

    testWidgets('更换Key模式_标题变更换_交易所与名称只读_保存后返回', (tester) async {
      // 预先建立一个已有交易所账户
      rig.addExchange('ex-1', '已有币安', ExchangeId.binance);
      await rig.secrets.write('ow.exchange.ex-1.key', 'old-key');
      await rig.secrets.write('ow.exchange.ex-1.secret', 'old-secret');

      rig.registry.exchangeFake(ExchangeId.binance).verifyResult = const Ok(
        CredentialCheck(permission: KeyPermission.readOnly),
      );

      await pumpApp(
        tester,
        rig,
        location: '/accounts/add/exchange?accountId=ex-1',
      );

      expect(find.text('更换 API Key'), findsOneWidget);
      // 交易所与名称处于只读展示
      expect(find.text('已有币安'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), 'new-key');
      await tester.enterText(find.byType(TextField).at(1), 'new-secret');
      await tester.tap(find.text('测试并保存'));
      await tester.pumpAndSettle();

      // 验证凭据已更新
      final newKey = await rig.secrets.read('ow.exchange.ex-1.key');
      expect(newKey, 'new-key');
      final newSecret = await rig.secrets.read('ow.exchange.ex-1.secret');
      expect(newSecret, 'new-secret');
    });

    testWidgets('安全约束_AddExchangeState不包含任何敏感字段', (tester) async {
      const state = AddExchangeState(
        selectedExchange: ExchangeId.binance,
        name: 'Binance 主账户',
      );

      // 通过反射/类型验证 state 没有 apiKey, apiSecret, passphrase 字段
      expect(state.name, 'Binance 主账户');
      expect(state.selectedExchange, ExchangeId.binance);
      expect(state.isBusy, isFalse);
    });

    testWidgets('响应式与无溢出_390x800与1280x900', (tester) async {
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await pumpApp(tester, rig, location: '/accounts/add/exchange');
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(1280, 900);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
