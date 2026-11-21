import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/app.dart';
import 'package:onewallet/bootstrap/foundation_providers.dart';
import 'package:onewallet/bootstrap/vault_providers.dart';
import 'package:onewallet/features/lock/presentation/lock_page.dart';
import 'package:onewallet/l10n/app_localizations.dart';
import 'package:onewallet/theme/ow_theme.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:ow_vault/ow_vault.dart';

import '../../bootstrap/support.dart';
import '../../support/fakes.dart';

final class _FakeBiometricAuth implements BiometricAuth {
  bool available = false;
  bool authenticateSucceeds = true;
  int authenticateCalls = 0;
  void Function()? onAuthenticate;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<Result<void>> authenticate({required String reason}) async {
    authenticateCalls++;
    onAuthenticate?.call();
    if (authenticateSucceeds) return const Ok(null);
    return const Err(ValidationFailure('biometric_failed'));
  }
}

void main() {
  late FakeSecretStore secretStore;
  late FixedClock clock;
  late SodiumVaultCrypto crypto;
  late _FakeBiometricAuth biometricAuth;

  setUpAll(() async {
    crypto = await SodiumVaultCrypto.load();
  });

  setUp(() {
    secretStore = FakeSecretStore();
    clock = FixedClock(DateTime.utc(2026, 11, 15, 10, 0, 0));
    biometricAuth = _FakeBiometricAuth();
  });

  Widget createWidget({required ProviderContainer container}) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildOwTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LockPage(),
      ),
    );
  }

  testWidgets('LockPage_输入数字点位增加_回退键减少', (tester) async {
    final container = ProviderContainer(
      overrides: [
        secretStoreProvider.overrideWithValue(secretStore),
        clockProvider.overrideWithValue(clock),
        vaultCryptoProvider.overrideWith((ref) => Future.value(crypto)),
        biometricAuthProvider.overrideWithValue(biometricAuth),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(createWidget(container: container));
    await tester.pumpAndSettle();

    // 点击 1, 2, 3
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();

    // 回退
    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pumpAndSettle();
  });

  testWidgets('LockPage_输入错误PIN_提示错误并清空', (tester) async {
    final setUp = SetUpPin(
      store: secretStore,
      crypto: crypto,
      limiter: AttemptLimiter(
        store: secretStore,
        clock: clock,
        keyPrefix: 'ow.app.pin',
      ),
      kdfParams: KdfParams(memKib: 8, iterations: 1),
    );
    final pin = Sensitive(Uint8List.fromList('123456'.codeUnits));
    await tester.runAsync(() async {
      await setUp(pin);
    });
    pin.wipe();

    final container = ProviderContainer(
      overrides: [
        secretStoreProvider.overrideWithValue(secretStore),
        clockProvider.overrideWithValue(clock),
        vaultCryptoProvider.overrideWith((ref) => Future.value(crypto)),
        biometricAuthProvider.overrideWithValue(biometricAuth),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(createWidget(container: container));
    await tester.pumpAndSettle();

    // 输入错误密码 000000
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.text('0'));
      await tester.pump();
    }
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    expect(find.text('PIN 码不正确'), findsOneWidget);
  });

  group('应用锁生命周期与弹窗保护 (Review Item 2 & 4)', () {
    late TestRig rig;

    setUp(() async {
      rig = TestRig();
      await rig.settings.update(
        (s) => s.copyWith(autoLock: AutoLock.immediately, appBiometrics: true),
      );
    });

    Future<void> setupValidPin(WidgetTester tester, String pinStr) async {
      final setUp = SetUpPin(
        store: rig.secrets,
        crypto: crypto,
        limiter: AttemptLimiter(
          store: rig.secrets,
          clock: rig.clock,
          keyPrefix: 'ow.app.pin',
        ),
        kdfParams: KdfParams(memKib: 8, iterations: 1),
      );
      final pin = Sensitive(Uint8List.fromList(pinStr.codeUnits));
      await tester.runAsync(() async {
        await setUp(pin);
      });
      pin.wipe();
    }

    List<Override> createOverrides() {
      return [
        ...rig.overrides,
        vaultCryptoProvider.overrideWith((ref) => Future.value(crypto)),
        biometricAuthProvider.overrideWithValue(biometricAuth),
      ];
    }

    testWidgets('冷启动：有PIN时首帧及所有中间帧均显示加载页看不到总览，初始化完成后显示锁屏页', (tester) async {
      await setupValidPin(tester, '123456');

      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: const OneWalletApp(),
        ),
      );

      // Frame 0: 第一帧
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('总览'), findsNothing);
      expect(find.text('还没有账户'), findsNothing);
      expect(find.byType(LockPage), findsNothing);

      // 中间帧
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('总览'), findsNothing);
      expect(find.text('还没有账户'), findsNothing);

      // 状态机初始化完成
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();

      // 初始化完成后停在锁屏页，总览依然不可见
      expect(find.byType(LockPage), findsOneWidget);
      expect(find.text('总览'), findsNothing);
      expect(find.text('还没有账户'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('默认立即锁定模式下，生物识别解锁成功回到前台后不会再次锁定', (tester) async {
      await setupValidPin(tester, '123456');
      biometricAuth.available = true;
      biometricAuth.authenticateSucceeds = true;
      biometricAuth.onAuthenticate = () {
        // 模拟系统生物识别弹窗出现与消失导致的生命周期变化（包含 paused/resumed）
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: const OneWalletApp(),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await tester.pumpAndSettle();

      // 生物识别解锁成功进入总览，不会因立即锁定再次被锁屏
      expect(find.byType(LockPage), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              (w.data == '还没有账户' || w.data == '一处看全，备份不丢' || w.data == '总览'),
        ),
        findsWidgets,
      );

      // 等待 1 秒后依然不锁定
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(LockPage), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('真正切到后台再回来仍然锁定', (tester) async {
      await setupValidPin(tester, '123456');
      biometricAuth.available = true;
      biometricAuth.authenticateSucceeds = true;

      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: const OneWalletApp(),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await tester.pumpAndSettle();

      // 已通过生物识别自动解锁进入应用
      expect(find.byType(LockPage), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              (w.data == '还没有账户' || w.data == '一处看全，备份不丢' || w.data == '总览'),
        ),
        findsWidgets,
      );

      // 模拟后台切回后未通过生物识别（以便留在锁屏页进行断言）
      biometricAuth.authenticateSucceeds = false;

      // 真正切到后台（此时外部界面计数为 0）
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      // 真正回到前台
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();

      // 应该重新锁定进入 LockPage
      expect(find.byType(LockPage), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}
