import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<Result<void>> authenticate({required String reason}) async {
    authenticateCalls++;
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
}
