import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/widgets/ow_external_link.dart';
import 'package:ow_directory/ow_directory.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

void main() {
  group('WalletSourceMapping 与 ThirdPartyDirectory 互通性验证', () {
    test('对应表里的每个 id 在 ThirdPartyDirectory 中都存在且是已核对的钱包', () {
      final dir = ThirdPartyDirectory.builtin();
      for (final MapEntry(key: dirId, value: source)
          in WalletSourceMapping.directoryIdToSource.entries) {
        final entry = dir.byId(dirId);
        expect(entry, isNotNull, reason: '目录中必须存在 $dirId');
        expect(entry!.kind, DirectoryKind.wallet, reason: '$dirId 必须是钱包类型');
        expect(entry.isVerified, isTrue, reason: '$dirId 必须是已核对条目');
        expect(WalletSourceMapping.toWalletSource(dirId), source);
        expect(WalletSourceMapping.toDirectoryId(source), dirId);
      }
    });

    test('未知目录 id 映射为 other，other 反推为 null', () {
      expect(WalletSourceMapping.toWalletSource('phantom'), WalletSource.other);
      expect(
        WalletSourceMapping.toWalletSource('non-existent'),
        WalletSource.other,
      );
      expect(WalletSourceMapping.toWalletSource(null), WalletSource.other);
      expect(WalletSourceMapping.toDirectoryId(WalletSource.other), isNull);
      expect(WalletSourceMapping.toDirectoryId(null), isNull);
    });
  });

  group('P05 来源钱包目录选择与搜索', () {
    late TestRig rig;
    setUp(() => rig = TestRig());

    testWidgets('来源钱包选择器_支持搜索_选择后更新并保存正确字段', (tester) async {
      await pumpApp(tester, rig, location: '/accounts/add/wallet');
      expect(find.text('来源钱包'), findsOneWidget);
      expect(find.text('其他'), findsOneWidget);

      // 点击来源钱包选择框弹出底部弹层
      await tester.tap(find.byKey(const ValueKey('wallet-source-field')));
      await tester.pumpAndSettle();

      // 弹层中包含搜索框
      expect(find.text('搜索钱包…'), findsOneWidget);
      expect(find.text('MetaMask'), findsOneWidget);
      expect(find.text('Phantom'), findsOneWidget);

      // 输入搜索过滤
      await tester.enterText(
        find.widgetWithText(TextField, '搜索钱包…'),
        'phantom',
      );
      await tester.pumpAndSettle();

      expect(find.text('MetaMask'), findsNothing);
      expect(find.text('Phantom'), findsOneWidget);

      // 选中 Phantom
      await tester.tap(find.text('Phantom'));
      await tester.pumpAndSettle();

      // 弹层关闭，主表单显示 Phantom
      expect(find.text('Phantom'), findsOneWidget);

      // 输入名称与地址并保存
      await tester.enterText(find.byType(TextField).at(0), '我的Phantom');
      await tester.enterText(
        find.byType(TextField).at(1),
        '0x1111111111111111111111111111111111111111',
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('保存'));
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // 验证保存的账户：walletSourceId 为 phantom，walletSource 派生为 other
      final account = rig.accounts.feed.value.single;
      expect(account.name, '我的Phantom');
      expect(account.walletSourceId, 'phantom');
      expect(account.walletSource, WalletSource.other);
    });
  });

  group('P07 与 P20 目录链接展示', () {
    late TestRig rig;
    setUp(() => rig = TestRig());

    testWidgets('P07 钱包详情显示来源钱包官网外链', (tester) async {
      final a = rig.addWallet('w1', '小狐狸钱包', walletSourceId: 'metamask');
      rig.addAddress('d1', a.id, '0x1111111111111111111111111111111111111111');
      rig.record(a.id);

      await pumpApp(tester, rig, location: '/accounts/wallet/w1');
      expect(find.text('小狐狸钱包'), findsWidgets);
      expect(find.widgetWithText(OwExternalLink, 'MetaMask'), findsOneWidget);
    });

    testWidgets('P20 价格源显示 CoinGecko 署名和外链；服务商编辑面板显示官网与 Key 文档', (
      tester,
    ) async {
      await pumpApp(tester, rig, location: '/settings/sources');

      // 列表中价格行展示署名与外链
      expect(find.text('价格数据来自 CoinGecko'), findsOneWidget);

      // 点击 Alchemy 服务商打开编辑面板
      await tester.tap(find.text('Alchemy'));
      await tester.pumpAndSettle();

      expect(find.text('Alchemy 设置'), findsOneWidget);
      expect(find.widgetWithText(OwExternalLink, '官网'), findsOneWidget);
      expect(find.widgetWithText(OwExternalLink, '获取 API Key'), findsOneWidget);
    });
  });
}
