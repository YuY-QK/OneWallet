import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

void main() {
  group('P11 备份清单页面', () {
    testWidgets('空状态_没有钱包账户时显示引导添加', (tester) async {
      final rig = TestRig();
      await pumpApp(tester, rig, location: '/vault/checklist');

      expect(find.text('暂无钱包账户'), findsOneWidget);
      expect(find.text('添加钱包账户后，在此查看和管理各钱包的备份状况。'), findsOneWidget);
      expect(find.text('添加第一个账户'), findsOneWidget);
    });

    testWidgets('分类与徽章展示_根据 R34 和 R35 展示待处理与已完成组', (tester) async {
      final rig = TestRig();
      final now = DateTime.utc(2026, 11, 16, 12);
      rig.clock.now = now;

      // 待处理：未备份
      rig.addWallet('w_none', '小狐狸主号', source: WalletSource.metamask);
      // 待处理：无助记词
      rig.addWallet(
        'w_kl',
        'Bitget 无私钥',
        source: WalletSource.bitgetWallet,
        backup: const BackupStatus(keyless: true),
      );
      // 已完成：双重备份
      rig.addWallet(
        'w_dual',
        'Uni 钱包',
        source: WalletSource.uniswap,
        vaultItemId: 'item-1',
        backup: BackupStatus(
          offlineBackedUp: true,
          offlineVerifiedAt: now.subtract(const Duration(days: 30)),
        ),
      );
      // 已完成：仅保险库
      rig.addWallet('w_vault', 'Tron 钱包', vaultItemId: 'item-2');
      // 交易所账户（R37：应被排除在清单外）
      rig.addExchange('e1', 'Binance 主账户', ExchangeId.binance);

      await pumpApp(
        tester,
        rig,
        location: '/vault/checklist',
        size: const Size(390, 1200),
      );

      // 顶部汇总：4 个钱包，2 个已备份（交易所被排除）
      expect(find.text('2 / 4 个钱包已备份'), findsOneWidget);

      // 分组标题
      expect(find.text('待处理'), findsOneWidget);
      expect(find.text('已完成'), findsOneWidget);

      // 待处理条目
      expect(find.text('小狐狸主号'), findsOneWidget);
      expect(find.text('未备份'), findsOneWidget);
      expect(find.text('去入库'), findsOneWidget);
      expect(find.text('标记已离线备份'), findsWidgets);
      expect(find.text('标记为无助记词钱包'), findsOneWidget);

      expect(find.text('Bitget 无私钥'), findsOneWidget);
      expect(find.text('无助记词钱包'), findsOneWidget);
      expect(find.textContaining('这类钱包依赖服务商'), findsOneWidget);
      expect(find.text('重新标记'), findsOneWidget);

      // 已完成条目
      expect(find.text('Uni 钱包'), findsOneWidget);
      expect(find.text('Tron 钱包'), findsOneWidget);
      expect(find.text('已入库'), findsWidgets);
      expect(find.text('已离线备份'), findsWidgets);

      // 交易所账户未出现在清单中
      expect(find.text('Binance 主账户'), findsNothing);

      // 底部固定说明（R37）
      expect(find.text('交易所资产没有私钥可备份。请启用二次验证，并保管好账号凭据。'), findsOneWidget);
    });

    testWidgets('R36: 超过 180 天未核对提醒及今天已核对更新', (tester) async {
      final rig = TestRig();
      final now = DateTime.utc(2026, 11, 16, 12);
      rig.clock.now = now;

      // 181 天前核对过
      rig.addWallet(
        'w_overdue',
        '冷钱包',
        backup: BackupStatus(
          offlineBackedUp: true,
          offlineVerifiedAt: now.subtract(const Duration(days: 181)),
        ),
      );

      await pumpApp(tester, rig, location: '/vault/checklist');

      expect(find.text('冷钱包'), findsOneWidget);
      expect(find.text('超过 180 天未核对'), findsOneWidget);
      expect(find.text('今天已核对'), findsOneWidget);

      // 点击"今天已核对"
      await tester.tap(find.text('今天已核对'));
      await tester.pumpAndSettle();

      // 核对日期已更新为今天，超期警告消失
      expect(find.text('超过 180 天未核对'), findsNothing);
      expect(find.text('上次核对 2026-11-16'), findsOneWidget);
    });

    testWidgets('R38: 保险库更改后未导出备份提示', (tester) async {
      final rig = TestRig();
      final now = DateTime.utc(2026, 11, 16, 12);
      rig.clock.now = now;

      rig.settings.feed.value = AppSettings(
        vaultChangedAt: DateTime.utc(2026, 11, 10),
        lastBackupExportedAt: DateTime.utc(2026, 11, 5),
      );

      rig.addWallet('w1', 'Wallet 1', vaultItemId: 'v1');

      await pumpApp(tester, rig, location: '/vault/checklist');

      expect(find.text('加密备份文件：2026-11-05 导出'), findsOneWidget);
      expect(find.text('之后保险库有更改，尚未导出'), findsOneWidget);
      expect(find.text('导出加密备份'), findsOneWidget);
    });

    testWidgets('待处理项按估值降序排序', (tester) async {
      final rig = TestRig();
      final now = DateTime.utc(2026, 11, 16, 12);
      rig.clock.now = now;

      final wLow = rig.addWallet('w_low', '低估值钱包');
      final wHigh = rig.addWallet('w_high', '高估值钱包');

      final addrLow = rig.addAddress(
        'a_low',
        wLow.id,
        '0x1111111111111111111111111111111111111111',
        family: ChainFamily.evm,
      );
      final addrHigh = rig.addAddress(
        'a_high',
        wHigh.id,
        '0x2222222222222222222222222222222222222222',
        family: ChainFamily.evm,
      );

      rig.addHolding(
        wLow.id,
        addrLow.id,
        amount: '1',
        assetId: 'eth',
        price: '2000',
      );
      rig.addHolding(
        wHigh.id,
        addrHigh.id,
        amount: '10',
        assetId: 'eth',
        price: '2000',
      );

      rig.prices.feed.value = {
        'eth': Price(
          assetId: 'eth',
          quote: Quote.usd,
          price: Decimal.parse('2000'),
          updatedAt: now,
        ),
      };

      await pumpApp(tester, rig, location: '/vault/checklist');

      // 验证高估值排在低估值前面
      final highPos = tester.getTopLeft(find.text('高估值钱包')).dy;
      final lowPos = tester.getTopLeft(find.text('低估值钱包')).dy;
      expect(highPos, lessThan(lowPos));
    });

    testWidgets('标记已离线备份后移动到已完成组', (tester) async {
      final rig = TestRig();
      final now = DateTime.utc(2026, 11, 16, 12);
      rig.clock.now = now;

      rig.addWallet('w1', '测试钱包');

      await pumpApp(tester, rig, location: '/vault/checklist');

      expect(find.text('待处理'), findsOneWidget);
      expect(find.text('已完成'), findsNothing);

      await tester.tap(find.text('标记已离线备份'));
      await tester.pumpAndSettle();

      expect(find.text('待处理'), findsNothing);
      expect(find.text('已完成'), findsOneWidget);
      expect(find.text('测试钱包'), findsOneWidget);
    });
  });
}
