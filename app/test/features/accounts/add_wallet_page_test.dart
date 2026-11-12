import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

const _evm1 = '0x1111111111111111111111111111111111111111';
const _evm2 = '0x2222222222222222222222222222222222222222';
const _btc = '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa';

Finder get _nameField => find.byType(TextField).at(0);
Finder _addressField(int i) => find.byType(TextField).at(1 + i);

FilledButton _saveButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byType(FilledButton));

void main() {
  late TestRig rig;
  setUp(() => rig = TestRig());

  group('P04 添加账户', () {
    testWidgets('三个选项_点观察链上地址_进入P05', (tester) async {
      await pumpApp(tester, rig, location: '/accounts/add');
      expect(find.text('观察链上地址'), findsOneWidget);
      expect(find.text('连接交易所'), findsOneWidget);
      expect(find.text('导入助记词或私钥'), findsOneWidget);
      await tester.tap(find.text('观察链上地址'));
      await tester.pumpAndSettle();
      expect(find.text('账户名称'), findsOneWidget);
    });

    testWidgets('连接交易所_进入说明页', (tester) async {
      await pumpApp(tester, rig, location: '/accounts/add');
      await tester.tap(find.text('连接交易所'));
      await tester.pumpAndSettle();
      expect(find.text('此功能将在后续版本提供。'), findsOneWidget);
    });

    testWidgets('导入助记词_进入说明页', (tester) async {
      final router = await pumpApp(tester, rig, location: '/accounts/add');
      await tester.tap(find.text('导入助记词或私钥'));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/vault/import');
      expect(find.text('此功能将在后续版本提供。'), findsOneWidget);
    });
  });

  group('P05 添加钱包账户', () {
    testWidgets('初始状态_无错误_不显示链选择_保存可点', (tester) async {
      await pumpApp(tester, rig, location: '/accounts/add/wallet');
      expect(find.text('账户名称'), findsOneWidget);
      expect(find.text('来源钱包'), findsOneWidget);
      expect(find.text('备份状态'), findsOneWidget);
      expect(find.text('✓ 未备份'), findsOneWidget);
      expect(find.text('链（可多选）'), findsNothing);
      expect(find.text('请输入账户名称，最多 30 个字。'), findsNothing);
      expect(find.text('保存'), findsOneWidget);
      expect(_saveButton(tester).onPressed, isNotNull);
      // 扫码按钮本版不提供。
      expect(find.text('扫码'), findsNothing);
    });

    testWidgets('EVM地址_识别为EVM_六条链默认全选_可取消', (tester) async {
      await pumpApp(tester, rig, location: '/accounts/add/wallet');
      await tester.enterText(_addressField(0), _evm1);
      await tester.pumpAndSettle();
      expect(find.text('✓ 识别为 EVM 地址'), findsOneWidget);
      for (final n in [
        'Ethereum',
        'BNB Chain',
        'Arbitrum',
        'Optimism',
        'Base',
        'Polygon',
      ]) {
        expect(find.text('✓ $n'), findsOneWidget);
      }
      await tester.tap(find.text('✓ Base'));
      await tester.pumpAndSettle();
      expect(find.text('Base'), findsOneWidget);
      expect(find.text('✓ Base'), findsNothing);
    });

    testWidgets('Bitcoin地址_自动确定链_没有多选', (tester) async {
      await pumpApp(tester, rig, location: '/accounts/add/wallet');
      await tester.enterText(_addressField(0), _btc);
      await tester.pumpAndSettle();
      expect(find.text('✓ 识别为 Bitcoin 地址'), findsOneWidget);
      expect(find.text('链：Bitcoin（自动确定）'), findsOneWidget);
      expect(find.text('链（可多选）'), findsNothing);
    });

    testWidgets('校验错误_无法识别的地址_与必填名称', (tester) async {
      await pumpApp(tester, rig, location: '/accounts/add/wallet');
      await tester.enterText(_addressField(0), 'hello-not-an-address');
      await tester.pumpAndSettle();
      expect(find.text('无法识别的地址格式。请检查是否复制完整。'), findsOneWidget);
      await tester.ensureVisible(find.text('保存'));
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.text('请输入账户名称，最多 30 个字。'), findsOneWidget);
      expect(rig.accounts.feed.value, isEmpty);
    });

    testWidgets('重复地址_提示所属账户名_且不允许保存', (tester) async {
      final a = rig.addWallet('a1', '主钱包');
      rig.addAddress('d1', a.id, _evm1);
      await pumpApp(tester, rig, location: '/accounts/add/wallet');
      await tester.enterText(_nameField, '新钱包');
      await tester.enterText(
        _addressField(0),
        _evm1.toUpperCase().replaceFirst('0X', '0x'),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('已在账户「主钱包」中'), findsOneWidget);
      await tester.ensureVisible(find.text('保存'));
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(rig.accounts.feed.value, hasLength(1));
    });

    testWidgets('本次输入内重复_提示删除重复的一项', (tester) async {
      await pumpApp(tester, rig, location: '/accounts/add/wallet');
      await tester.enterText(_addressField(0), _evm1);
      await tester.ensureVisible(find.text('再添加一个地址'));
      await tester.tap(find.text('再添加一个地址'));
      await tester.pumpAndSettle();
      expect(find.text('地址 2'), findsOneWidget);
      await tester.enterText(_addressField(1), _evm1);
      await tester.pumpAndSettle();
      expect(find.textContaining('在本次输入中出现了不止一次'), findsOneWidget);
    });

    testWidgets('保存中_按钮禁用并显示保存中', (tester) async {
      rig.addresses.upsertGate = Completer<void>();
      await pumpApp(tester, rig, location: '/accounts/add/wallet');
      await tester.enterText(_nameField, 'Uni 钱包');
      await tester.enterText(_addressField(0), _evm1);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('保存'));
      await tester.tap(find.text('保存'));
      await tester.pump();
      await tester.pump();
      expect(find.text('保存中…'), findsOneWidget);
      expect(_saveButton(tester).onPressed, isNull);
      rig.addresses.upsertGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('保存中…'), findsNothing);
    });

    testWidgets('保存成功_写入账户_触发该账户同步_跳到P07', (tester) async {
      final router = await pumpApp(
        tester,
        rig,
        location: '/accounts/add/wallet',
      );
      await tester.enterText(_nameField, 'Uni 钱包');
      await tester.enterText(_addressField(0), _evm1);
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('✓ 已离线备份').evaluate().isEmpty
            ? find.text('已离线备份')
            : find.text('✓ 已离线备份'),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('保存'));
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      final account = rig.accounts.feed.value.single;
      expect(account.name, 'Uni 钱包');
      expect(account.backup.offlineBackedUp, isTrue);
      final saved = rig.addresses.feed.value.single;
      expect(saved.enabledChainIds, hasLength(6));
      // 同步：六条链各查询一次。
      expect(rig.registry[ChainFamily.evm].fetchCount, 6);
      expect(rig.syncRecords.feed.value.single.status, SyncStatus.success);
      expect(locationOf(router), '/accounts/wallet/${account.id}');
    });

    testWidgets('给已有账户添加地址_名称来源只读_不显示备份选择', (tester) async {
      final a = rig.addWallet('a1', '主钱包', source: WalletSource.metamask);
      rig.addAddress('d1', a.id, _evm1);
      final router = await pumpApp(
        tester,
        rig,
        location: '/accounts/add/wallet?accountId=a1',
      );
      expect(find.text('主钱包'), findsOneWidget);
      expect(find.text('MetaMask'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget); // 只有地址输入框
      expect(find.text('备份状态'), findsNothing);
      await tester.enterText(find.byType(TextField), _evm2);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('保存'));
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(rig.accounts.feed.value, hasLength(1));
      expect(rig.addresses.feed.value, hasLength(2));
      expect(locationOf(router), '/accounts/wallet/a1');
      expect(rig.registry[ChainFamily.evm].fetchCount, greaterThan(0));
    });

    testWidgets('已有账户不存在_显示说明', (tester) async {
      await pumpApp(
        tester,
        rig,
        location: '/accounts/add/wallet?accountId=zzz',
      );
      expect(find.text('找不到这个账户，它可能已被删除。'), findsOneWidget);
    });

    testWidgets('粘贴_读取剪贴板里的公开地址_空剪贴板提示', (tester) async {
      await pumpApp(tester, rig, location: '/accounts/add/wallet');
      await tester.tap(find.text('粘贴'));
      await tester.pumpAndSettle();
      expect(find.text('剪贴板里没有文字。'), findsOneWidget);
      rig.clipboard = _btc;
      await tester.pump(const Duration(seconds: 5));
      await tester.tap(find.text('粘贴'));
      await tester.pumpAndSettle();
      expect(find.text('✓ 识别为 Bitcoin 地址'), findsOneWidget);
    });

    testWidgets('EVM地址_未配置Key时提示_配置后不提示', (tester) async {
      await pumpApp(tester, rig, location: '/accounts/add/wallet');
      await tester.enterText(_addressField(0), _evm1);
      await tester.pumpAndSettle();
      expect(find.textContaining('尚未配置 Alchemy Key'), findsOneWidget);
    });

    testWidgets('EVM地址_已配置Key_不提示', (tester) async {
      rig.secrets.data['ow.datasource.alchemy.key'] = 'test-key-0000';
      await pumpApp(tester, rig, location: '/accounts/add/wallet');
      await tester.enterText(_addressField(0), _evm1);
      await tester.pumpAndSettle();
      expect(find.textContaining('尚未配置 Alchemy Key'), findsNothing);
    });
  });
}
