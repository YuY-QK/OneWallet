import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/bootstrap/app_bootstrap.dart';
import 'package:onewallet/bootstrap/bootstrap_host.dart';
import 'package:ow_data/ow_data.dart';

import 'support.dart';

/// 卸载宿主：关闭数据库并让 drift 的收尾计时器跑完，避免测试结束时仍有挂起计时器。
Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('启动失败_显示错误页文案_点重试后重新启动', (tester) async {
    var calls = 0;
    Future<BootstrapResult> bootstrap() async {
      calls++;
      return calls == 1
          ? const BootstrapFailure(BootstrapFailureKind.databaseOpenFailed)
          : BootstrapSuccess(
              database: OwDatabase(NativeDatabase.memory()),
              secrets: FakeSecretStore(),
            );
    }

    await tester.pumpWidget(BootstrapHost(bootstrap: bootstrap));
    // 第一帧：加载中。
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('无法打开本地数据'), findsOneWidget);
    expect(find.textContaining('不会自动删除或重建'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.text('重试'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(calls, 2);
    expect(find.text('无法打开本地数据'), findsNothing);
    expect(find.text('总览'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('各失败原因_各有对应文案', (tester) async {
    final expected = {
      BootstrapFailureKind.secureStorageFailed: '无法访问系统安全存储',
      BootstrapFailureKind.databaseKeyMissing: '找不到它的密钥',
      BootstrapFailureKind.databaseOpenFailed: '无法打开，文件可能已损坏',
    };
    for (final entry in expected.entries) {
      await tester.pumpWidget(
        BootstrapHost(
          key: ValueKey(entry.key),
          bootstrap: () async => BootstrapFailure(entry.key),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining(entry.value), findsOneWidget);
    }
  });

  testWidgets('启动成功_进入应用外壳', (tester) async {
    await tester.pumpWidget(
      BootstrapHost(
        bootstrap: () async => BootstrapSuccess(
          database: OwDatabase(NativeDatabase.memory()),
          secrets: FakeSecretStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('还没有账户'), findsOneWidget);
    expect(find.text('无法打开本地数据'), findsNothing);
    await unmount(tester);
  });
}
