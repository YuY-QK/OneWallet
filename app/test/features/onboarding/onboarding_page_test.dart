import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/bootstrap/app_lock_providers.dart';
import 'package:onewallet/bootstrap/foundation_providers.dart';
import 'package:onewallet/bootstrap/vault_providers.dart';
import 'package:onewallet/features/onboarding/presentation/onboarding_page.dart';
import 'package:onewallet/l10n/app_localizations.dart';
import 'package:onewallet/theme/ow_theme.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:ow_vault/ow_vault.dart';

import '../../bootstrap/support.dart';
import '../../support/fakes.dart';

final class _FakeBiometricAuth implements BiometricAuth {
  bool available = false;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<Result<void>> authenticate({required String reason}) async =>
      const Ok(null);
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
        home: const OnboardingPage(),
      ),
    );
  }

  testWidgets('OnboardingPage_完整设置PIN流程', (tester) async {
    final container = ProviderContainer(
      overrides: [
        secretStoreProvider.overrideWithValue(secretStore),
        clockProvider.overrideWithValue(clock),
        vaultCryptoProvider.overrideWith((ref) => Future.value(crypto)),
        biometricAuthProvider.overrideWithValue(biometricAuth),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        // 用极小参数加速测试
        setUpPinProvider.overrideWith(
          (ref) async => SetUpPin(
            store: secretStore,
            crypto: crypto,
            limiter: ref.watch(appLockLimiterProvider),
            kdfParams: KdfParams(memKib: 8, iterations: 1),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(createWidget(container: container));
    await tester.pumpAndSettle();

    // 1. 欢迎页验证
    expect(find.text('一处看全，备份不丢'), findsOneWidget);
    expect(find.text('只读，不转账'), findsOneWidget);
    expect(find.text('我已了解，开始使用'), findsOneWidget);
    expect(find.text('从备份恢复'), findsOneWidget);

    // 点击开始使用
    await tester.tap(find.text('我已了解，开始使用'));
    await tester.pumpAndSettle();

    // 2. 第一次输入 PIN
    expect(find.text('设置 6 位 PIN'), findsOneWidget);
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.text('1'));
      await tester.pumpAndSettle();
    }

    // 3. 第二次确认 PIN
    expect(find.text('请再次输入以确认'), findsOneWidget);
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.text('1'));
      await tester.pump();
    }
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    // PIN 已写入 SecretStore
    final stored = await secretStore.read('ow.app.pin.hash');
    expect(stored, isNotNull);
  });
}
