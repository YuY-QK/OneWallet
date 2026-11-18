import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/app.dart';
import 'package:onewallet/bootstrap/app_bootstrap.dart';
import 'package:onewallet/bootstrap/bootstrap_host.dart';
import 'package:onewallet/bootstrap/providers.dart';
import 'package:ow_application/ow_application.dart';
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
    // 进入应用前要读取数据库里的币种目录（真实的异步 IO）。
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(calls, 2);
    expect(find.text('无法打开本地数据'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            (w.data == '还没有账户' || w.data == '一处看全，备份不丢' || w.data == '总览'),
      ),
      findsWidgets,
    );
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
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data == '还没有账户' || w.data == '一处看全，备份不丢'),
      ),
      findsOneWidget,
    );
    expect(find.text('无法打开本地数据'), findsNothing);
    await unmount(tester);
  });

  testWidgets('数据库打开失败_点击清除本地数据并确认后调用wipe并重试成功', (tester) async {
    var wipeCalled = false;
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

    await tester.pumpWidget(
      BootstrapHost(
        bootstrap: bootstrap,
        onWipeAndRestart: () async {
          wipeCalled = true;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('清除本地数据并重新开始'), findsOneWidget);
    await tester.tap(find.text('清除本地数据并重新开始'));
    await tester.pumpAndSettle();

    expect(find.text('清除本地数据并重新开始？'), findsOneWidget);
    expect(find.textContaining('此操作将清除本地数据库与所有存储的凭据'), findsOneWidget);

    // 点取消：不调用 wipe
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(wipeCalled, isFalse);

    // 再次点击并确认
    await tester.tap(find.text('清除本地数据并重新开始'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清除并重新开始'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(wipeCalled, isTrue);
    expect(calls, 2);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            (w.data == '还没有账户' || w.data == '一处看全，备份不丢' || w.data == '总览'),
      ),
      findsWidgets,
    );
    await unmount(tester);
  });

  testWidgets('运行中通过 wipeAndRestartProvider 触发重置_清空并重启', (tester) async {
    int calls = 0;
    bool wipeCalled = false;
    Future<BootstrapResult> bootstrap() async {
      calls++;
      return BootstrapSuccess(
        database: OwDatabase(NativeDatabase.memory()),
        secrets: FakeSecretStore(),
      );
    }

    await tester.pumpWidget(
      BootstrapHost(
        bootstrap: bootstrap,
        onWipeAndRestart: () async {
          wipeCalled = true;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            (w.data == '还没有账户' || w.data == '一处看全，备份不丢' || w.data == '总览'),
      ),
      findsWidgets,
    );
    expect(calls, 1);

    // 从 ProviderScope 中调用 wipeAndRestartProvider
    final element = tester.element(find.byType(OneWalletApp));
    final container = ProviderScope.containerOf(element);
    await container.read(wipeAndRestartProvider)();
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(wipeCalled, isTrue);
    expect(calls, 2);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            (w.data == '还没有账户' || w.data == '一处看全，备份不丢' || w.data == '总览'),
      ),
      findsWidgets,
    );
    await unmount(tester);
  });

  testWidgets('删除保险库文件失败时不会进入重启_显示错误与重试入口', (tester) async {
    int calls = 0;
    Future<BootstrapResult> bootstrap() async {
      calls++;
      return calls == 1
          ? const BootstrapFailure(BootstrapFailureKind.databaseOpenFailed)
          : BootstrapSuccess(
              database: OwDatabase(NativeDatabase.memory()),
              secrets: FakeSecretStore(),
            );
    }

    final fakeVault = FakeVaultStorage()
      ..failDeleteWith = StateError('模拟删除保险库失败');
    final wipeAllData = WipeAllData(
      databaseDeleter: MemoryDatabaseOpener(),
      vaultStorage: fakeVault,
      secrets: FakeSecretStore(),
    );

    await tester.pumpWidget(
      BootstrapHost(bootstrap: bootstrap, wipeAllData: wipeAllData),
    );
    await tester.pumpAndSettle();

    // 初始处于启动失败页，点击清除数据
    expect(find.text('清除本地数据并重新开始'), findsOneWidget);
    await tester.tap(find.text('清除本地数据并重新开始'));
    await tester.pumpAndSettle();

    expect(find.text('清除本地数据并重新开始？'), findsOneWidget);
    await tester.tap(find.text('清除并重新开始'));
    await tester.pumpAndSettle();

    // 验证：未进入重启（calls 仍为 1）
    expect(calls, 1);
    // 显示"清除未完成，请重试"
    expect(find.text('清除未完成，请重试'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);

    // 修复故障后点击重试，可完成清除并进入重启
    fakeVault.failDeleteWith = null;
    await tester.tap(find.text('重试'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(calls, 2);
    expect(find.text('总览'), findsWidgets);
    await unmount(tester);
  });
}
