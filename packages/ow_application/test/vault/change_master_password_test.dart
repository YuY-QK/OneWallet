import 'dart:convert';
import 'dart:typed_data';

import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:ow_vault/ow_vault.dart';
import 'package:test/test.dart';

import '../fakes/fake_repositories.dart';
import '../fakes/fake_services.dart';
import '../fakes/fake_vault.dart';

Sensitive sensitiveString(String s) =>
    Sensitive(Uint8List.fromList(utf8.encode(s)));

void main() {
  group('T10: ChangeMasterPassword', () {
    late SodiumVaultCrypto crypto;
    late MemoryVaultStorage storage;
    late FakeHardwareKeyStore hardwareStore;
    late FakePlatformCapabilities capabilities;
    late CountingVaultCrypto countingCrypto;
    late Vault vault;
    late MemorySecretStore secretStore;
    late AttemptLimiter limiter;
    late InMemorySettingsRepository settingsRepo;
    late FakeClock clock;
    late VaultAccess vaultAccess;
    late ChangeMasterPassword changeMasterPassword;

    const oldPasswordStr = 'correct-horse-battery-staple-1';
    const newPasswordStr = 'new-horse-battery-staple-2';
    const shortPasswordStr = 'short123';

    setUpAll(() async {
      crypto = await SodiumVaultCrypto.load();
    });

    setUp(() async {
      storage = MemoryVaultStorage();
      hardwareStore = FakeHardwareKeyStore();
      capabilities = FakePlatformCapabilities(hardwareKeystore: true);
      countingCrypto = CountingVaultCrypto(crypto);

      vault = Vault(
        crypto: countingCrypto,
        storage: storage,
        defaultParams: testKdfParams,
      );

      secretStore = MemorySecretStore();
      clock = FakeClock();
      limiter = AttemptLimiter(
        keyPrefix: 'ow.vault.unlock',
        store: secretStore,
        clock: clock,
      );
      settingsRepo = InMemorySettingsRepository(const AppSettings());

      vaultAccess = VaultAccess(
        vault: vault,
        hardwareKeyStore: hardwareStore,
        secretStore: secretStore,
        capabilities: capabilities,
        settings: settingsRepo,
        passwordLimiter: limiter,
      );

      changeMasterPassword = ChangeMasterPassword(
        vaultAccess: vaultAccess,
        settings: settingsRepo,
        clock: clock,
      );

      // 先创建保险库
      final oldPw = sensitiveString(oldPasswordStr);
      final createRes = await vault.create(oldPw);
      createRes.valueOrNull!.close();
      oldPw.wipe();

      // 开启生物识别设置并建立硬件包裹
      await settingsRepo.update((s) => s.copyWith(vaultBiometrics: true));
      final pwForWrap = sensitiveString(oldPasswordStr);
      await vaultAccess.withSession(
        PasswordCredential(pwForWrap),
        (session) async => vaultAccess.enableHardwareWrap(session),
      );
      pwForWrap.wipe();

      countingCrypto.argon2idCalls = 0;
    });

    test('新密码过短在解锁前被拒绝，不消耗 Argon2id 且不计入失败限制器', () async {
      final initialArgon = countingCrypto.argon2idCalls;
      final oldPw = sensitiveString(oldPasswordStr);
      final shortPw = sensitiveString(shortPasswordStr);

      final res = await changeMasterPassword(
        currentPassword: oldPw,
        newPassword: shortPw,
      );

      oldPw.wipe();
      shortPw.wipe();

      expect(res, isA<Err<void>>());
      final failure = (res as Err<void>).failure;
      expect(failure, isA<ValidationFailure>());
      expect(
        (failure as ValidationFailure).detail,
        'master_password_too_short',
      );

      // 验证未调用 Argon2id
      expect(countingCrypto.argon2idCalls, initialArgon);
      // 限制器未被增加
      final checkRes = await limiter.check();
      expect(checkRes, const Unlocked(0));
    });

    test('旧密码错误计入失败限制器', () async {
      final badOldPw = sensitiveString('wrong-password-1234');
      final newPw = sensitiveString(newPasswordStr);

      final res = await changeMasterPassword(
        currentPassword: badOldPw,
        newPassword: newPw,
      );

      badOldPw.wipe();
      newPw.wipe();

      expect(res, isA<Err<void>>());
      final failure = (res as Err<void>).failure;
      expect(failure, isA<WrongPasswordFailure>());

      // 限制器记录了一次失败
      final checkRes = await limiter.check();
      expect(checkRes, const Unlocked(1));
    });

    test('改后旧密码失效、新密码可用、硬件包裹仍可用，vaultChangedAt 被更新', () async {
      final oldPw = sensitiveString(oldPasswordStr);
      final newPw = sensitiveString(newPasswordStr);

      final res = await changeMasterPassword(
        currentPassword: oldPw,
        newPassword: newPw,
      );

      oldPw.wipe();
      newPw.wipe();

      expect(res, isA<Ok<void>>());

      // 验证 vaultChangedAt 更新
      final currentSettings = await settingsRepo.watch().first;
      expect(currentSettings.vaultChangedAt, clock.nowUtc());

      // 1. 旧密码解锁失败
      final oldPwRetry = sensitiveString(oldPasswordStr);
      final failRes = await vaultAccess.withSession(
        PasswordCredential(oldPwRetry),
        (session) async => const Ok(null),
      );
      oldPwRetry.wipe();
      expect(failRes, isA<Err<void>>());
      expect((failRes as Err<void>).failure, isA<WrongPasswordFailure>());

      // 2. 新密码解锁成功
      final newPwRetry = sensitiveString(newPasswordStr);
      final okRes = await vaultAccess.withSession(
        PasswordCredential(newPwRetry),
        (session) async => const Ok(null),
      );
      newPwRetry.wipe();
      expect(okRes, isA<Ok<void>>());

      // 3. 硬件包裹（生物识别）仍可用
      final bioRes = await vaultAccess.withSession(
        const BiometricCredential(reason: '测试'),
        (session) async => const Ok(null),
      );
      expect(bioRes, isA<Ok<void>>());
    });
  });
}
