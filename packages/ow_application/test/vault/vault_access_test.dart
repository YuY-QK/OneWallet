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
  late SodiumVaultCrypto rawCrypto;
  late CountingVaultCrypto crypto;
  late MemoryVaultStorage storage;
  late Vault vault;
  late MemorySecretStore secretStore;
  late FakePlatformCapabilities capabilities;
  late InMemorySettingsRepository settings;
  late FakeHardwareKeyStore hardwareKeyStore;
  late FakeClock clock;
  late AttemptLimiter limiter;
  late VaultAccess access;

  setUpAll(() async {
    rawCrypto = await SodiumVaultCrypto.load();
  });

  setUp(() async {
    crypto = CountingVaultCrypto(rawCrypto);
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

    // 先创建一个测试保险库
    final pw = sensitiveString('MasterPassword123');
    final createRes = await vault.create(pw);
    createRes.valueOrNull!.close();
    pw.wipe();
    crypto.argon2idCalls = 0;
  });

  group('T2: VaultAccess 主密码路径', () {
    test('空密码不计次数且不执行 Argon2id', () async {
      final emptyPw = sensitiveString('');
      final res = await access.withSession(
        PasswordCredential(emptyPw),
        (session) async => const Ok(null),
      );
      expect(res, isA<Err<void>>());
      expect((res as Err).failure, isA<WrongPasswordFailure>());
      expect(crypto.argon2idCalls, 0);

      final state = await limiter.check();
      expect((state as Unlocked).failures, 0);
      emptyPw.wipe();
    });

    test('锁定期间不执行 Argon2id', () async {
      // 产生 5 次失败，使之锁定
      for (var i = 0; i < 5; i++) {
        await limiter.recordFailure();
      }
      expect(await limiter.check(), isA<Locked>());

      crypto.argon2idCalls = 0;
      final pw = sensitiveString('WrongPass');
      final res = await access.withSession(
        PasswordCredential(pw),
        (session) async => const Ok(null),
      );
      expect(res, isA<Err<void>>());
      expect((res as Err).failure, isA<LockedOutFailure>());
      expect(crypto.argon2idCalls, 0);
      pw.wipe();
    });

    test('VaultCorruptedFailure 不计错误次数', () async {
      // 破坏存储中的数据
      storage.bytes![0] ^= 0xFF;

      final pw = sensitiveString('MasterPassword123');
      final res = await access.withSession(
        PasswordCredential(pw),
        (session) async => const Ok(null),
      );
      expect(res, isA<Err<void>>());
      expect((res as Err).failure, isA<VaultCorruptedFailure>());

      final state = await limiter.check();
      expect((state as Unlocked).failures, 0);
      pw.wipe();
    });

    test('密码错误计次数，成功后清零次数', () async {
      final wrongPw = sensitiveString('WrongPass');
      final errRes = await access.withSession(
        PasswordCredential(wrongPw),
        (session) async => const Ok(null),
      );
      expect(errRes, isA<Err<void>>());
      expect((errRes as Err).failure, isA<WrongPasswordFailure>());

      var state = await limiter.check();
      expect((state as Unlocked).failures, 1);
      wrongPw.wipe();

      final correctPw = sensitiveString('MasterPassword123');
      final okRes = await access.withSession(
        PasswordCredential(correctPw),
        (session) async => const Ok('hello'),
      );
      expect(okRes, isA<Ok<String>>());
      expect((okRes as Ok).value, 'hello');

      state = await limiter.check();
      expect((state as Unlocked).failures, 0);
      correctPw.wipe();
    });

    test('body 抛异常时会话仍被关闭', () async {
      final pw = sensitiveString('MasterPassword123');
      VaultSession? capturedSession;

      try {
        await access.withSession<void>(PasswordCredential(pw), (session) async {
          capturedSession = session;
          throw StateError('测试异常');
        });
        fail('应该抛出异常');
      } catch (e) {
        expect(e, isA<StateError>());
      }

      // 断言会话已被关闭：再次对 closed 会话操作会抛出 StateError
      expect(capturedSession, isNotNull);
      expect(() => capturedSession!.exportMasterKey(), throwsStateError);
      pw.wipe();
    });
  });

  group('T3: VaultAccess 生物识别路径', () {
    test('平台不支持、设置未开、没有包裹返回 BiometricUnavailableFailure', () async {
      const cred = BiometricCredential(reason: '验证');

      // 1. 设置未开
      var res = await access.withSession(cred, (s) async => const Ok(null));
      expect(res, isA<Err<void>>());
      expect((res as Err).failure, isA<BiometricUnavailableFailure>());

      // 开启设置，但平台不支持硬件 KeyStore
      await settings.update((s) => s.copyWith(vaultBiometrics: true));
      capabilities.hardwareKeystore = false;
      res = await access.withSession(cred, (s) async => const Ok(null));
      expect(res, isA<Err<void>>());
      expect((res as Err).failure, isA<BiometricUnavailableFailure>());

      // 平台支持，但没有包裹
      capabilities.hardwareKeystore = true;
      res = await access.withSession(cred, (s) async => const Ok(null));
      expect(res, isA<Err<void>>());
      expect((res as Err).failure, isA<BiometricUnavailableFailure>());
    });

    test('unwrap 失败 -> 删除包裹，设置保持开启，下次主密码解锁后自动重新包裹 (R30)', () async {
      await settings.update((s) => s.copyWith(vaultBiometrics: true));
      final pw = sensitiveString('MasterPassword123');

      // 先用主密码解锁并启用包裹
      await access.withSession(
        PasswordCredential(pw),
        (session) async => access.enableHardwareWrap(session),
      );
      expect(await secretStore.read('ow.vault.hw_wrapped'), isNotNull);

      // 模拟 unwrap 失败（例如指纹变更）
      hardwareKeyStore.failUnwrap = true;
      const bioCred = BiometricCredential(reason: '测试指纹');
      final bioRes = await access.withSession(
        bioCred,
        (s) async => const Ok(null),
      );
      expect(bioRes, isA<Err<void>>());
      expect((bioRes as Err).failure, isA<BiometricUnavailableFailure>());

      // 包裹已被删除，但设置保持开启
      expect(await secretStore.read('ow.vault.hw_wrapped'), isNull);
      final currentSettings = await settings.watch().first;
      expect(currentSettings.vaultBiometrics, isTrue);

      // 下次主密码解锁后自动重新包裹 (R30)
      hardwareKeyStore.failUnwrap = false;
      await access.withSession(
        PasswordCredential(pw),
        (session) async => const Ok(null),
      );
      expect(await secretStore.read('ow.vault.hw_wrapped'), isNotNull);

      // 用户取消生物识别：返回 BiometricUnavailableFailure('user_canceled')，但不删除包裹
      hardwareKeyStore.cancelUnwrap = true;
      final cancelRes = await access.withSession(
        bioCred,
        (s) async => const Ok(null),
      );
      expect(cancelRes, isA<Err<void>>());
      final cancelFailure = (cancelRes as Err).failure;
      expect(cancelFailure, isA<BiometricUnavailableFailure>());
      expect(cancelFailure.detail, 'user_canceled');
      // 包裹依然保留在 secretStore 中，没有被删除
      expect(await secretStore.read('ow.vault.hw_wrapped'), isNotNull);

      pw.wipe();
    });

    test('包裹过期（保险库重建后）同样删除包裹并返回 BiometricUnavailableFailure', () async {
      await settings.update((s) => s.copyWith(vaultBiometrics: true));
      final pw1 = sensitiveString('MasterPassword123');

      // 第一次创建并包装
      await access.withSession(
        PasswordCredential(pw1),
        (session) async => access.enableHardwareWrap(session),
      );
      expect(await secretStore.read('ow.vault.hw_wrapped'), isNotNull);
      pw1.wipe();

      // 外部用不同密码重建保险库
      await storage.delete();
      final pw2 = sensitiveString('NewPassword456');
      final recreateRes = await vault.create(pw2);
      recreateRes.valueOrNull!.close();
      pw2.wipe();

      // 此时旧包裹解出的是旧主密钥，去解锁新保险库会失败，应清除包裹并返回 BiometricUnavailableFailure
      const bioCred = BiometricCredential(reason: '测试');
      final res = await access.withSession(
        bioCred,
        (s) async => const Ok(null),
      );
      expect(res, isA<Err<void>>());
      expect((res as Err).failure, isA<BiometricUnavailableFailure>());
      expect(await secretStore.read('ow.vault.hw_wrapped'), isNull);
    });

    test('allowBiometric: false 时拒绝生物识别', () async {
      const bioCred = BiometricCredential(reason: '测试');
      final res = await access.withSession(
        bioCred,
        (s) async => const Ok(null),
        allowBiometric: false,
      );
      expect(res, isA<Err<void>>());
      expect((res as Err).failure, isA<ValidationFailure>());
      expect(
        ((res as Err).failure as ValidationFailure).detail,
        'password_required',
      );
    });

    test('生物识别成功不改变错误次数', () async {
      await settings.update((s) => s.copyWith(vaultBiometrics: true));
      final pw = sensitiveString('MasterPassword123');

      await access.withSession(
        PasswordCredential(pw),
        (session) async => access.enableHardwareWrap(session),
      );

      // 先故意产生 2 次密码错误
      await limiter.recordFailure();
      await limiter.recordFailure();
      var state = await limiter.check();
      expect((state as Unlocked).failures, 2);

      // 生物识别解锁成功
      const bioCred = BiometricCredential(reason: '测试');
      final res = await access.withSession(
        bioCred,
        (session) async => const Ok('success'),
      );
      expect((res as Ok).value, 'success');

      // 错误次数仍然保持为 2，不被清零
      state = await limiter.check();
      expect((state as Unlocked).failures, 2);

      pw.wipe();
    });
  });
}
