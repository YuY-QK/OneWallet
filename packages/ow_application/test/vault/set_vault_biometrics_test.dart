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
  group('T11: SetVaultBiometrics', () {
    late SodiumVaultCrypto crypto;
    late MemoryVaultStorage storage;
    late FakeHardwareKeyStore hardwareStore;
    late FakePlatformCapabilities capabilities;
    late Vault vault;
    late MemorySecretStore secretStore;
    late AttemptLimiter limiter;
    late InMemorySettingsRepository settingsRepo;
    late FakeClock clock;
    late VaultAccess vaultAccess;
    late SetVaultBiometrics setVaultBiometrics;

    const masterPasswordStr = 'MasterPassword123';

    setUpAll(() async {
      crypto = await SodiumVaultCrypto.load();
    });

    setUp(() async {
      storage = MemoryVaultStorage();
      hardwareStore = FakeHardwareKeyStore();
      capabilities = FakePlatformCapabilities(hardwareKeystore: true);

      vault = Vault(
        crypto: crypto,
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

      setVaultBiometrics = SetVaultBiometrics(
        vaultAccess: vaultAccess,
        capabilities: capabilities,
        settings: settingsRepo,
      );

      // 创建保险库
      final pw = sensitiveString(masterPasswordStr);
      final createRes = await vault.create(pw);
      createRes.valueOrNull!.close();
      pw.wipe();
    });

    test('开启需要主密码：未提供密码返回 ValidationFailure', () async {
      final res = await setVaultBiometrics(enable: true);
      expect(res, isA<Err<void>>());
      final failure = (res as Err<void>).failure;
      expect(failure, isA<ValidationFailure>());
      expect((failure as ValidationFailure).detail, 'credential_required');
    });

    test('平台不支持硬件密钥时返回 UnsupportedFailure', () async {
      capabilities.hardwareKeystore = false;
      final pw = sensitiveString(masterPasswordStr);
      final cred = PasswordCredential(pw);

      final res = await setVaultBiometrics(enable: true, credential: cred);
      pw.wipe();

      expect(res, isA<Err<void>>());
      expect((res as Err<void>).failure, isA<UnsupportedFailure>());
    });

    test('开启成功：写入硬件包裹、设置变为 true，后续可用生物识别解锁', () async {
      final pw = sensitiveString(masterPasswordStr);
      final cred = PasswordCredential(pw);

      final res = await setVaultBiometrics(enable: true, credential: cred);
      pw.wipe();

      expect(res, isA<Ok<void>>());

      // 验证设置已开启
      final currentSettings = await settingsRepo.watch().first;
      expect(currentSettings.vaultBiometrics, isTrue);

      // 验证可用生物识别解锁
      final bioRes = await vaultAccess.withSession(
        const BiometricCredential(reason: '测试'),
        (session) async => const Ok(null),
      );
      expect(bioRes, isA<Ok<void>>());
    });

    test('关闭幂等：多次调用关闭均成功，硬件包裹被删除', () async {
      // 先开启
      final pw = sensitiveString(masterPasswordStr);
      await setVaultBiometrics(
        enable: true,
        credential: PasswordCredential(pw),
      );
      pw.wipe();

      // 第一次关闭
      final res1 = await setVaultBiometrics(enable: false);
      expect(res1, isA<Ok<void>>());
      var currentSettings = await settingsRepo.watch().first;
      expect(currentSettings.vaultBiometrics, isFalse);

      // 第二次关闭（幂等）
      final res2 = await setVaultBiometrics(enable: false);
      expect(res2, isA<Ok<void>>());
      currentSettings = await settingsRepo.watch().first;
      expect(currentSettings.vaultBiometrics, isFalse);

      // 生物识别解锁失败（设置未开启）
      final bioRes = await vaultAccess.withSession(
        const BiometricCredential(reason: '测试'),
        (session) async => const Ok(null),
      );
      expect(bioRes, isA<Err<void>>());
      expect((bioRes as Err).failure, isA<BiometricUnavailableFailure>());
    });
  });
}
