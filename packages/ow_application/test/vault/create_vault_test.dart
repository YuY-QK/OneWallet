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
  late SodiumVaultCrypto crypto;
  late MemoryVaultStorage storage;
  late Vault vault;
  late MemorySecretStore secretStore;
  late FakePlatformCapabilities capabilities;
  late InMemorySettingsRepository settings;
  late FakeHardwareKeyStore hardwareKeyStore;
  late FakeClock clock;
  late AttemptLimiter limiter;
  late VaultAccess access;
  late CreateVault createVault;

  setUpAll(() async {
    crypto = await SodiumVaultCrypto.load();
  });

  setUp(() {
    storage = MemoryVaultStorage();
    vault = Vault(
      crypto: crypto,
      storage: storage,
      defaultParams: testKdfParams,
    );
    secretStore = MemorySecretStore();
    capabilities = FakePlatformCapabilities();
    settings = InMemorySettingsRepository(const AppSettings());
    hardwareKeyStore = FakeHardwareKeyStore();
    clock = FakeClock();
    limiter = AttemptLimiter(
      store: secretStore,
      clock: clock,
      keyPrefix: 'ow.vault.unlock',
    );
    access = VaultAccess(
      vault: vault,
      hardwareKeyStore: hardwareKeyStore,
      secretStore: secretStore,
      capabilities: capabilities,
      settings: settings,
      passwordLimiter: limiter,
    );
    createVault = CreateVault(
      vault: vault,
      vaultAccess: access,
      capabilities: capabilities,
      settings: settings,
      clock: clock,
    );
  });

  group('T4: CreateVault', () {
    test('密码过短（去首尾空白后 < 10 字符）被拒绝', () async {
      final shortPw = sensitiveString('  123456789  ');
      final res = await createVault(
        masterPassword: shortPw,
        enableBiometrics: false,
      );
      expect(res, isA<Err<CreateVaultOutcome>>());
      expect((res as Err).failure, isA<ValidationFailure>());
      expect(
        ((res as Err).failure as ValidationFailure).detail,
        'master_password_too_short',
      );
      expect(await vault.exists(), isFalse);
      shortPw.wipe();
    });

    test('已存在时返回 VaultAlreadyExistsFailure', () async {
      final pw = sensitiveString('MasterPassword123');
      final firstRes = await createVault(
        masterPassword: pw,
        enableBiometrics: false,
      );
      expect(firstRes, isA<Ok<CreateVaultOutcome>>());

      final secondRes = await createVault(
        masterPassword: pw,
        enableBiometrics: false,
      );
      expect(secondRes, isA<Err<CreateVaultOutcome>>());
      expect((secondRes as Err).failure, isA<VaultAlreadyExistsFailure>());
      pw.wipe();
    });

    test('开启生物识别：平台支持且包裹成功', () async {
      capabilities.hardwareKeystore = true;
      final pw = sensitiveString('MasterPassword123');
      final res = await createVault(masterPassword: pw, enableBiometrics: true);
      expect(res, isA<Ok<CreateVaultOutcome>>());
      expect((res as Ok<CreateVaultOutcome>).value.biometricsEnabled, isTrue);

      final s = await settings.watch().first;
      expect(s.vaultBiometrics, isTrue);
      expect(await secretStore.read('ow.vault.hw_wrapped'), isNotNull);
      pw.wipe();
    });

    test('开启生物识别：wrap 失败不影响创建，biometricsEnabled 为 false', () async {
      capabilities.hardwareKeystore = true;
      // 模拟硬件包裹失败：删除别名时异常或包装失败
      // 我们可以在假硬件存储中模拟 wrap 失败
      // 传入一个 wrap 返回 Err 的 HardwareKeyStore
      final failingHw = _FailingWrapHardwareKeyStore();
      final failingAccess = VaultAccess(
        vault: vault,
        hardwareKeyStore: failingHw,
        secretStore: secretStore,
        capabilities: capabilities,
        settings: settings,
        passwordLimiter: limiter,
      );
      final customCreateVault = CreateVault(
        vault: vault,
        vaultAccess: failingAccess,
        capabilities: capabilities,
        settings: settings,
        clock: clock,
      );

      final pw = sensitiveString('MasterPassword123');
      final res = await customCreateVault(
        masterPassword: pw,
        enableBiometrics: true,
      );
      expect(res, isA<Ok<CreateVaultOutcome>>());
      expect((res as Ok<CreateVaultOutcome>).value.biometricsEnabled, isFalse);

      final s = await settings.watch().first;
      expect(s.vaultBiometrics, isFalse);
      expect(await vault.exists(), isTrue);
      pw.wipe();
    });

    test('平台不支持硬件密钥时创建仍成功，biometricsEnabled 为 false', () async {
      capabilities.hardwareKeystore = false;
      final pw = sensitiveString('MasterPassword123');
      final res = await createVault(masterPassword: pw, enableBiometrics: true);
      expect(res, isA<Ok<CreateVaultOutcome>>());
      expect((res as Ok<CreateVaultOutcome>).value.biometricsEnabled, isFalse);

      final s = await settings.watch().first;
      expect(s.vaultBiometrics, isFalse);
      expect(await vault.exists(), isTrue);
      pw.wipe();
    });

    test('创建成功后 vaultChangedAt 被更新', () async {
      final now = clock.nowUtc();
      final pw = sensitiveString('MasterPassword123');
      await createVault(masterPassword: pw, enableBiometrics: false);

      final s = await settings.watch().first;
      expect(s.vaultChangedAt, now);
      pw.wipe();
    });
  });
}

final class _FailingWrapHardwareKeyStore implements HardwareKeyStore {
  @override
  Future<Result<Uint8List>> wrap(String keyAlias, Uint8List plaintext) async =>
      const Err(UnsupportedFailure('硬件包裹失败'));

  @override
  Future<Result<Uint8List>> unwrap(
    String keyAlias,
    Uint8List wrapped, {
    required String reason,
  }) async => const Err(UnsupportedFailure(''));

  @override
  Future<void> delete(String keyAlias) async {}
}
