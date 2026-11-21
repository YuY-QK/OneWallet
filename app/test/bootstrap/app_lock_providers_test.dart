import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/bootstrap/app_lock_providers.dart';
import 'package:onewallet/bootstrap/foundation_providers.dart';
import 'package:onewallet/bootstrap/vault_providers.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_vault/ow_vault.dart';

import '../support/fakes.dart';
import 'support.dart';

void main() {
  test('app_lock_providers_初始化与装配测试', () async {
    final secretStore = FakeSecretStore();
    final clock = FixedClock(DateTime.utc(2026, 11, 15));
    final sodiumCrypto = await SodiumVaultCrypto.load();

    final container = ProviderContainer(
      overrides: [
        secretStoreProvider.overrideWithValue(secretStore),
        clockProvider.overrideWithValue(clock),
        vaultCryptoProvider.overrideWith((ref) => Future.value(sodiumCrypto)),
      ],
    );
    addTearDown(container.dispose);

    final limiter = container.read(appLockLimiterProvider);
    expect(limiter, isA<AttemptLimiter>());

    final setUpPin = await container.read(setUpPinProvider.future);
    expect(setUpPin, isA<SetUpPin>());

    final verifyPin = await container.read(verifyPinProvider.future);
    expect(verifyPin, isA<VerifyPin>());

    final changePin = await container.read(changePinProvider.future);
    expect(changePin, isA<ChangePin>());

    final machine = await container.read(appLockStateMachineProvider.future);
    expect(machine, isA<AppLockStateMachine>());
    expect(machine.current, equals(const AppLockUninitialized()));
  });
}
