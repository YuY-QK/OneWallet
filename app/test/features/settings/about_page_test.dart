import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

void main() {
  late TestRig rig;

  setUp(() {
    rig = TestRig();
  });

  group('P22 关于与帮助', () {
    testWidgets('展示版本、CoinGecko署名、安全原则与常见问题', (tester) async {
      await pumpApp(tester, rig, location: '/settings/about');

      expect(find.text('关于与帮助'), findsOneWidget);
      expect(find.text('OneWallet'), findsOneWidget);
      expect(find.text('版本 1.0.0'), findsOneWidget);

      expect(find.text('价格数据来自 CoinGecko'), findsOneWidget);
      expect(find.text('安全设计说明'), findsOneWidget);
      expect(find.text('备份文件格式与解密工具'), findsOneWidget);
      expect(find.text('派生路径是什么？'), findsOneWidget);
      expect(find.text('开源许可'), findsOneWidget);
    });

    testWidgets('点击安全设计说明弹出详情对话框', (tester) async {
      await pumpApp(tester, rig, location: '/settings/about');

      await tester.tap(find.text('安全设计说明'));
      await tester.pumpAndSettle();

      expect(find.text('安全设计原则'), findsOneWidget);
      expect(find.textContaining('不上传至任何服务器'), findsOneWidget);
      expect(find.textContaining('杜绝被黑客恶意调用'), findsOneWidget);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('安全设计原则'), findsNothing);
    });

    testWidgets('点击备份文件格式弹出详情对话框', (tester) async {
      await pumpApp(tester, rig, location: '/settings/about');

      await tester.tap(find.text('备份文件格式与解密工具'));
      await tester.pumpAndSettle();

      expect(find.text('加密备份与离线解密'), findsOneWidget);
      expect(
        find.textContaining('Argon2id + XChaCha20-Poly1305'),
        findsOneWidget,
      );

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('加密备份与离线解密'), findsNothing);
    });

    testWidgets('点击常见问题项弹出解答', (tester) async {
      await pumpApp(tester, rig, location: '/settings/about');

      await tester.tap(find.text('派生路径是什么？'));
      await tester.pumpAndSettle();

      expect(find.textContaining('BIP44/84/86'), findsOneWidget);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
    });
  });
}
