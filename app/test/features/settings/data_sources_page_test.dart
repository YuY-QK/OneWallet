import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

const _fullKey = 'abcd1234efgh5678';
const _alchemyKeyStore = 'ow.datasource.alchemy.key';

/// 组件树里（文字或输入框内容）是否出现了 [secret]。
bool _treeContains(WidgetTester tester, String secret) {
  final inText = find.byWidgetPredicate(
    (w) =>
        (w is Text && (w.data ?? '').contains(secret)) ||
        (w is RichText && w.text.toPlainText().contains(secret)) ||
        (w is EditableText && w.controller.text.contains(secret)),
  );
  return tester.any(inText);
}

Future<void> _openEditor(WidgetTester tester, String name) async {
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}

Finder get _keyField => find.byType(TextField).first;

void main() {
  late TestRig rig;
  setUp(() => rig = TestRig());

  group('设置入口', () {
    testWidgets('设置页_列出数据源_点击进入P20', (tester) async {
      await pumpApp(tester, rig, location: '/settings');
      expect(find.text('数据源'), findsOneWidget);
      await tester.tap(find.text('数据源'));
      await tester.pumpAndSettle();
      expect(find.text('Alchemy'), findsOneWidget);
    });
  });

  group('P20 显示', () {
    testWidgets('未配置_服务商显示未配置_其余链即将支持且不可点_隐私说明', (tester) async {
      await pumpApp(tester, rig, location: '/settings/sources');
      expect(find.text('未配置'), findsNWidgets(2));
      expect(find.text('即将支持'), findsNWidgets(3));
      expect(find.text('查询余额时，你的地址和 IP 会被发送给所选的数据服务商。'), findsOneWidget);
      await tester.tap(find.text('Solana'));
      await tester.pumpAndSettle();
      expect(find.text('API Key'), findsNothing);
    });

    testWidgets('已配置_只显示已配置和前4位_不出现完整Key', (tester) async {
      rig.secrets.data[_alchemyKeyStore] = _fullKey;
      await pumpApp(tester, rig, location: '/settings/sources');
      expect(find.text('已配置'), findsOneWidget);
      expect(find.text('abcd***'), findsOneWidget);
      expect(_treeContains(tester, _fullKey), isFalse);
      await _openEditor(tester, 'Alchemy');
      expect(find.text('已配置 · abcd***'), findsOneWidget);
      expect(_treeContains(tester, _fullKey), isFalse);
      expect(tester.widget<TextField>(_keyField).controller!.text, isEmpty);
    });

    testWidgets('Key太短_不显示任何字符', (tester) async {
      rig.secrets.data[_alchemyKeyStore] = 'short1';
      await pumpApp(tester, rig, location: '/settings/sources');
      expect(find.text('已配置'), findsOneWidget);
      expect(_treeContains(tester, 'shor'), isFalse);
    });
  });

  group('P20 保存与清除', () {
    testWidgets('保存_写入安全存储_清空输入框_不回显明文', (tester) async {
      const typed = 'test-key-1234567890';
      await pumpApp(tester, rig, location: '/settings/sources');
      await _openEditor(tester, 'Alchemy');
      expect(tester.widget<TextField>(_keyField).obscureText, isTrue);
      await tester.enterText(_keyField, typed);
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(rig.secrets.data[_alchemyKeyStore], typed);
      expect(tester.widget<TextField>(_keyField).controller!.text, isEmpty);
      expect(find.text('已配置 · test***'), findsOneWidget);
      expect(find.text('已保存'), findsOneWidget);
      expect(_treeContains(tester, typed), isFalse);
    });

    testWidgets('显示开关_切换输入框是否遮挡', (tester) async {
      await pumpApp(tester, rig, location: '/settings/sources');
      await _openEditor(tester, 'Alchemy');
      await tester.tap(find.byTooltip('显示'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_keyField).obscureText, isFalse);
    });

    testWidgets('保存空内容_提示且不写入', (tester) async {
      await pumpApp(tester, rig, location: '/settings/sources');
      await _openEditor(tester, 'Alchemy');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.text('请输入 API Key。'), findsOneWidget);
      expect(rig.secrets.data.containsKey(_alchemyKeyStore), isFalse);
    });

    testWidgets('清除_删除已保存的Key', (tester) async {
      rig.secrets.data[_alchemyKeyStore] = _fullKey;
      await pumpApp(tester, rig, location: '/settings/sources');
      await _openEditor(tester, 'Alchemy');
      await tester.ensureVisible(find.text('清除 Key'));
      await tester.tap(find.text('清除 Key'));
      await tester.pumpAndSettle();
      expect(rig.secrets.data.containsKey(_alchemyKeyStore), isFalse);
      expect(find.text('清除 Key'), findsNothing);
      expect(find.text('未配置'), findsWidgets);
    });

    testWidgets('CoinGecko_保存后列表显示已配置', (tester) async {
      await pumpApp(tester, rig, location: '/settings/sources');
      await _openEditor(tester, 'CoinGecko');
      await tester.enterText(_keyField, 'cg-key-abcdefghijkl');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(
        rig.secrets.data['ow.datasource.coingecko.key'],
        'cg-key-abcdefghijkl',
      );
    });
  });

  group('P20 测试连接', () {
    testWidgets('Alchemy成功_用零地址查询', (tester) async {
      rig.secrets.data[_alchemyKeyStore] = _fullKey;
      await pumpApp(tester, rig, location: '/settings/sources');
      await _openEditor(tester, 'Alchemy');
      await tester.tap(find.text('测试连接'));
      await tester.pumpAndSettle();
      expect(find.text('连接正常。'), findsOneWidget);
      expect(rig.registry[ChainFamily.evm].fetched, [
        '0x0000000000000000000000000000000000000000',
      ]);
    });

    testWidgets('Alchemy失败_显示失败文案', (tester) async {
      rig.secrets.data[_alchemyKeyStore] = _fullKey;
      rig.registry[ChainFamily.evm].failure = const UnauthorizedFailure();
      await pumpApp(tester, rig, location: '/settings/sources');
      await _openEditor(tester, 'Alchemy');
      await tester.tap(find.text('测试连接'));
      await tester.pumpAndSettle();
      expect(find.textContaining('API Key 或 Secret 不正确'), findsOneWidget);
      expect(find.text('连接正常。'), findsNothing);
    });

    testWidgets('CoinGecko成功_查询BTC价格', (tester) async {
      await pumpApp(tester, rig, location: '/settings/sources');
      await _openEditor(tester, 'CoinGecko');
      await tester.tap(find.text('测试连接'));
      await tester.pumpAndSettle();
      expect(find.text('连接正常。'), findsOneWidget);
      expect(rig.priceSource.fetchedAssets, ['BTC']);
    });

    testWidgets('CoinGecko失败_显示失败文案', (tester) async {
      rig.priceSource.failure = const NetworkFailure();
      await pumpApp(tester, rig, location: '/settings/sources');
      await _openEditor(tester, 'CoinGecko');
      await tester.tap(find.text('测试连接'));
      await tester.pumpAndSettle();
      expect(find.textContaining('网络不可用'), findsOneWidget);
    });

    testWidgets('输入框有未保存内容_测试按钮禁用并提示', (tester) async {
      await pumpApp(tester, rig, location: '/settings/sources');
      await _openEditor(tester, 'Alchemy');
      await tester.enterText(_keyField, 'typed-but-not-saved');
      await tester.pumpAndSettle();
      expect(find.textContaining('先保存，再测试连接'), findsOneWidget);
      final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '测试连接'),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('P20 自定义RPC端点', () {
    Future<void> openAdvanced(WidgetTester tester) async {
      await _openEditor(tester, 'Alchemy');
      await tester.ensureVisible(find.text('高级：自定义 RPC 端点'));
      await tester.tap(find.text('高级：自定义 RPC 端点'));
      await tester.pumpAndSettle();
    }

    testWidgets('默认折叠_展开后六条链各一行', (tester) async {
      await pumpApp(tester, rig, location: '/settings/sources');
      await _openEditor(tester, 'Alchemy');
      expect(find.text('使用默认端点'), findsNothing);
      await tester.ensureVisible(find.text('高级：自定义 RPC 端点'));
      await tester.tap(find.text('高级：自定义 RPC 端点'));
      await tester.pumpAndSettle();
      expect(find.text('使用默认端点'), findsNWidgets(6));
    });

    testWidgets('非https_被拒绝并说明', (tester) async {
      await pumpApp(tester, rig, location: '/settings/sources');
      await openAdvanced(tester);
      final field = find.byType(TextField).at(1);
      await tester.ensureVisible(field);
      await tester.enterText(field, 'http://rpc.example.com');
      await tester.ensureVisible(find.text('保存端点').first);
      await tester.tap(find.text('保存端点').first);
      await tester.pumpAndSettle();
      expect(find.text('只接受 https 地址，且不能包含用户名或密码。'), findsOneWidget);
      expect(
        rig.secrets.data.containsKey('ow.datasource.ethereum.endpoint'),
        isFalse,
      );
    });

    testWidgets('https_保存后只显示域名_可恢复默认', (tester) async {
      await pumpApp(tester, rig, location: '/settings/sources');
      await openAdvanced(tester);
      final field = find.byType(TextField).at(1);
      await tester.ensureVisible(field);
      await tester.enterText(field, 'https://rpc.example.com/v1/path-secret');
      await tester.ensureVisible(find.text('保存端点').first);
      await tester.tap(find.text('保存端点').first);
      await tester.pumpAndSettle();
      expect(
        rig.secrets.data['ow.datasource.ethereum.endpoint'],
        'https://rpc.example.com/v1/path-secret',
      );
      expect(find.text('已设置自定义端点：rpc.example.com'), findsOneWidget);
      expect(_treeContains(tester, 'path-secret'), isFalse);
      await tester.ensureVisible(find.text('恢复默认'));
      await tester.tap(find.text('恢复默认'));
      await tester.pumpAndSettle();
      expect(
        rig.secrets.data.containsKey('ow.datasource.ethereum.endpoint'),
        isFalse,
      );
      expect(find.text('使用默认端点'), findsNWidgets(6));
    });
  });

  group('P20 不同屏宽下无溢出', () {
    for (final size in const [Size(390, 800), Size(1280, 900)]) {
      testWidgets('渲染_${size.width.toInt()}宽', (tester) async {
        rig.secrets.data[_alchemyKeyStore] = _fullKey;
        await pumpApp(tester, rig, location: '/settings/sources', size: size);
        await _openEditor(tester, 'Alchemy');
        expect(tester.takeException(), isNull);
      });
    }
  });
}
