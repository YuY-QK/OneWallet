import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/bootstrap/app_lock_providers.dart';
import 'package:onewallet/bootstrap/foundation_providers.dart';
import 'package:onewallet/bootstrap/vault_providers.dart';
import 'package:onewallet/features/settings/presentation/security_settings_page.dart';
import 'package:onewallet/l10n/app_localizations.dart';
import 'package:onewallet/theme/ow_theme.dart';
import 'package:onewallet/widgets/ow_row.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:ow_vault/ow_vault.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

final class SynchronousTestVaultCrypto implements VaultCrypto {
  SynchronousTestVaultCrypto(this.delegate);
  final VaultCrypto delegate;

  @override
  Uint8List randomBytes(int length) => delegate.randomBytes(length);

  @override
  Future<Uint8List> argon2id(
    Sensitive password,
    Uint8List salt,
    KdfParams params,
  ) async {
    final pwBytes = password.use(Uint8List.fromList);
    final res = delegate.keyedHash(salt, pwBytes, 32);
    return res;
  }

  @override
  Uint8List aeadEncrypt(
    Uint8List key,
    Uint8List nonce,
    Uint8List plaintext,
    Uint8List aad,
  ) => delegate.aeadEncrypt(key, nonce, plaintext, aad);

  @override
  Result<Uint8List> aeadDecrypt(
    Uint8List key,
    Uint8List nonce,
    Uint8List ciphertext,
    Uint8List aad,
  ) => delegate.aeadDecrypt(key, nonce, ciphertext, aad);

  @override
  Uint8List deriveSubkey(Uint8List masterKey, String context8, int subkeyId) =>
      delegate.deriveSubkey(masterKey, context8, subkeyId);

  @override
  Uint8List keyedHash(Uint8List key, Uint8List message, int outputLength) =>
      delegate.keyedHash(key, message, outputLength);

  @override
  bool constantTimeEquals(Uint8List a, Uint8List b) =>
      delegate.constantTimeEquals(a, b);
}

final class MemoryVaultStorage implements VaultStorage {
  Uint8List? _data;
  @override
  Future<Uint8List?> read() async => _data;
  @override
  Future<void> writeAtomic(Uint8List data) async =>
      _data = Uint8List.fromList(data);
  @override
  Future<void> delete() async => _data = null;
}

final class FakeHardwareKeyStore implements HardwareKeyStore {
  final _wrapped = <String, Uint8List>{};

  @override
  Future<Result<Uint8List>> wrap(String keyAlias, Uint8List plaintext) async {
    _wrapped[keyAlias] = Uint8List.fromList(plaintext);
    return Ok(Uint8List.fromList(plaintext));
  }

  @override
  Future<Result<Uint8List>> unwrap(
    String keyAlias,
    Uint8List wrapped, {
    required String reason,
  }) async {
    final data = _wrapped[keyAlias];
    if (data == null) return const Err(UnknownFailure('key not found'));
    return Ok(Uint8List.fromList(data));
  }

  @override
  Future<void> delete(String keyAlias) async => _wrapped.remove(keyAlias);
}

final class _TestPlatformCapabilities implements PlatformCapabilities {
  @override
  bool get biometrics => true;

  @override
  bool get hardwareKeystore => true;

  @override
  ScreenProtection get screenProtection => ScreenProtection.block;

  @override
  bool get camera => false;
}

final class _TestBiometricAuth implements BiometricAuth {
  bool succeeds = true;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<Result<void>> authenticate({required String reason}) async {
    return succeeds ? const Ok(null) : const Err(UnknownFailure());
  }
}

final class _TestDeviceIntegrity implements DeviceIntegrity {
  @override
  Future<bool> looksCompromised() async => false;
}

void main() {
  late SodiumVaultCrypto sodiumCrypto;
  late SynchronousTestVaultCrypto crypto;
  late TestRig rig;
  late _TestPlatformCapabilities capabilities;
  late _TestBiometricAuth biometricAuth;
  late _TestDeviceIntegrity deviceIntegrity;
  late FakeHardwareKeyStore hardwareStore;
  late MemoryVaultStorage vaultStorage;
  late Vault vault;
  late VaultAccess vaultAccess;
  late SetVaultBiometrics setVaultBiometrics;
  late ChangeMasterPassword changeMasterPassword;
  late SetUpPin setUpPin;
  late VerifyPin verifyPin;
  late ChangePin changePin;

  setUpAll(() async {
    sodiumCrypto = await SodiumVaultCrypto.load();
  });

  setUp(() {
    crypto = SynchronousTestVaultCrypto(sodiumCrypto);
    rig = TestRig();
    capabilities = _TestPlatformCapabilities();
    biometricAuth = _TestBiometricAuth();
    deviceIntegrity = _TestDeviceIntegrity();
    hardwareStore = FakeHardwareKeyStore();
    vaultStorage = MemoryVaultStorage();
    vault = Vault(
      storage: vaultStorage,
      crypto: crypto,
      defaultParams: KdfParams(memKib: 8, iterations: 1),
    );

    vaultAccess = VaultAccess(
      vault: vault,
      hardwareKeyStore: hardwareStore,
      secretStore: rig.secrets,
      capabilities: capabilities,
      settings: rig.settings,
      passwordLimiter: AttemptLimiter(
        store: rig.secrets,
        clock: rig.clock,
        keyPrefix: 'ow.vault.master',
      ),
    );

    setVaultBiometrics = SetVaultBiometrics(
      vaultAccess: vaultAccess,
      capabilities: capabilities,
      settings: rig.settings,
    );

    changeMasterPassword = ChangeMasterPassword(
      vaultAccess: vaultAccess,
      settings: rig.settings,
      clock: rig.clock,
    );

    final pinLimiter = AttemptLimiter(
      store: rig.secrets,
      clock: rig.clock,
      keyPrefix: 'ow.app.pin',
    );
    setUpPin = SetUpPin(
      store: rig.secrets,
      crypto: crypto,
      limiter: pinLimiter,
    );
    verifyPin = VerifyPin(
      store: rig.secrets,
      crypto: crypto,
      limiter: pinLimiter,
    );
    changePin = ChangePin(verifyPin: verifyPin, setUpPin: setUpPin);
  });

  Widget buildTestPage({List<dynamic> extraOverrides = const []}) {
    rig.capabilities = capabilities;
    return ProviderScope(
      overrides: [
        ...rig.overrides,
        biometricAuthProvider.overrideWithValue(biometricAuth),
        deviceIntegrityProvider.overrideWithValue(deviceIntegrity),
        setVaultBiometricsProvider.overrideWith((ref) => setVaultBiometrics),
        changeMasterPasswordProvider.overrideWith(
          (ref) => changeMasterPassword,
        ),
        verifyPinProvider.overrideWith((ref) => verifyPin),
        changePinProvider.overrideWith((ref) => changePin),
        ...extraOverrides.cast(),
      ],
      child: MaterialApp(
        theme: buildOwTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SecuritySettingsPage(),
      ),
    );
  }

  group('P18 设置页入口', () {
    testWidgets('设置页显示应用锁与生物识别项，点击跳转到 P19', (tester) async {
      final router = await pumpApp(tester, rig, location: '/settings');
      expect(find.text('应用锁与生物识别'), findsOneWidget);
      await tester.tap(find.text('应用锁与生物识别'));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/settings/security');
      expect(find.text('安全设置'), findsOneWidget);
    });
  });

  group('P19 页面初始渲染与基础设置', () {
    testWidgets('初始状态展示应用锁、保险库（未创建状态）与设备状态', (tester) async {
      await tester.pumpWidget(buildTestPage());
      await tester.pumpAndSettle();

      expect(find.text('安全设置'), findsOneWidget);
      expect(find.text('应用锁'), findsOneWidget);
      expect(find.text('修改 PIN'), findsOneWidget);
      expect(find.text('面容 / 指纹解锁'), findsOneWidget);
      expect(find.text('自动锁定'), findsOneWidget);
      expect(find.text('立即'), findsOneWidget);

      expect(find.text('保险库'), findsOneWidget);
      expect(find.text('面容 / 指纹解锁保险库'), findsOneWidget);
      expect(find.text('保险库尚未创建'), findsNWidgets(2));

      expect(find.text('设备'), findsOneWidget);
      expect(find.text('设备安全状态'), findsOneWidget);
      expect(find.text('未检测到越狱或 root'), findsOneWidget);
      expect(find.text('正常'), findsOneWidget);
    });

    testWidgets('切换自动锁定时间', (tester) async {
      await tester.pumpWidget(buildTestPage());
      await tester.pumpAndSettle();

      await tester.tap(find.text('自动锁定'));
      await tester.pumpAndSettle();

      expect(find.text('1 分钟后'), findsOneWidget);
      expect(find.text('5 分钟后'), findsOneWidget);

      await tester.tap(find.text('1 分钟后'));
      await tester.pumpAndSettle();

      expect(rig.settings.feed.value.autoLock, AutoLock.after1Min);
      expect(find.text('1 分钟后'), findsOneWidget);
    });

    testWidgets('开启与关闭应用锁生物识别', (tester) async {
      await tester.pumpWidget(buildTestPage());
      await tester.pumpAndSettle();

      final appBioFinder = find.widgetWithText(OwRow, '面容 / 指纹解锁');
      final switchFinder = find.descendant(
        of: appBioFinder,
        matching: find.byType(Switch),
      );

      // 开启
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(rig.settings.feed.value.appBiometrics, isTrue);

      // 关闭
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(rig.settings.feed.value.appBiometrics, isFalse);
    });
  });

  group('P19 修改 PIN 流程', () {
    testWidgets('完整流程：验证旧 PIN -> 输入新 PIN -> 确认并更新', (tester) async {
      const oldPinStr = '123456';
      const newPinStr = '654321';

      // 先初始化 PIN
      final oldSensitive = Sensitive(
        Uint8List.fromList(utf8.encode(oldPinStr)),
      );
      await setUpPin(oldSensitive);
      oldSensitive.wipe();

      await tester.pumpWidget(buildTestPage());
      await tester.pumpAndSettle();

      await tester.tap(find.text('修改 PIN'));
      await tester.pumpAndSettle();

      expect(find.text('输入当前 PIN'), findsOneWidget);

      // 1. 输入错误旧 PIN
      for (final digit in ['1', '1', '1', '1', '1', '1']) {
        await tester.tap(find.widgetWithText(InkWell, digit));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text('原 PIN 码不正确'), findsOneWidget);

      // 2. 输入正确旧 PIN
      for (final digit in oldPinStr.split('')) {
        await tester.tap(find.widgetWithText(InkWell, digit));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      // 进入输入新 PIN
      expect(find.text('输入新 PIN'), findsOneWidget);

      // 3. 输入新 PIN
      for (final digit in newPinStr.split('')) {
        await tester.tap(find.widgetWithText(InkWell, digit));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      // 进入确认新 PIN
      expect(find.text('确认新 PIN'), findsOneWidget);

      // 4. 输入不匹配的 PIN -> 显示不一致并退回新 PIN
      for (final digit in ['1', '2', '3', '7', '8', '9']) {
        await tester.tap(find.widgetWithText(InkWell, digit));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text('两次输入的 PIN 不一致，请重新输入'), findsOneWidget);

      // 5. 重新输入新 PIN
      for (final digit in newPinStr.split('')) {
        await tester.tap(find.widgetWithText(InkWell, digit));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      // 6. 输入匹配的确认 PIN
      for (final digit in newPinStr.split('')) {
        await tester.tap(find.widgetWithText(InkWell, digit));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      // 抽屉关闭并显示成功消息
      expect(find.text('输入新 PIN'), findsNothing);
      expect(find.text('PIN 码已修改'), findsOneWidget);

      // 验证新 PIN 生效
      final testSensitive = Sensitive(
        Uint8List.fromList(utf8.encode(newPinStr)),
      );
      final verifyRes = await verifyPin(testSensitive);
      testSensitive.wipe();
      expect(verifyRes is Ok, isTrue);
    });
  });

  group('P19 保险库设置（已初始化）', () {
    const masterPassword = 'testMasterPassword123';

    setUp(() async {
      rig.isVaultInitialized = true;
      final sensitive = Sensitive(
        Uint8List.fromList(utf8.encode(masterPassword)),
      );
      final res = await vault.create(sensitive);
      sensitive.wipe();
      if (res case Ok(:final value)) {
        value.close();
      }
    });

    testWidgets('开启与关闭保险库生物识别', (tester) async {
      await tester.pumpWidget(buildTestPage());
      await tester.pumpAndSettle();

      expect(find.text('保险库尚未创建'), findsNothing);

      final vaultBioFinder = find.widgetWithText(OwRow, '面容 / 指纹解锁保险库');
      final switchFinder = find.descendant(
        of: vaultBioFinder,
        matching: find.byType(Switch),
      );

      // 点击开启 -> 弹出主密码输入框
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(find.text('验证主密码'), findsOneWidget);

      // 输入正确密码
      await tester.enterText(find.byType(TextField), masterPassword);
      await tester.tap(find.text('验证并开启'));
      await tester.pump();
      await tester.runAsync(() async {
        for (var i = 0; i < 50; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          if (rig.settings.feed.value.vaultBiometrics) break;
        }
      });
      await tester.pumpAndSettle();

      expect(rig.settings.feed.value.vaultBiometrics, isTrue);

      // 点击关闭
      await tester.tap(switchFinder);
      await tester.pump();
      await tester.runAsync(() async {
        for (var i = 0; i < 50; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          if (!rig.settings.feed.value.vaultBiometrics) break;
        }
      });
      await tester.pumpAndSettle();

      expect(rig.settings.feed.value.vaultBiometrics, isFalse);
    });

    testWidgets('修改主密码流程', (tester) async {
      await tester.pumpWidget(buildTestPage());
      await tester.pumpAndSettle();

      await tester.tap(find.text('修改主密码'));
      await tester.pumpAndSettle();

      expect(find.text('修改主密码'), findsNWidgets(2)); // Title and Dialog Title

      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(3));

      // 1. 输入密码但过短
      await tester.enterText(fields.at(0), masterPassword);
      await tester.enterText(fields.at(1), 'short');
      await tester.enterText(fields.at(2), 'short');
      await tester.tap(find.text('确认修改'));
      await tester.pumpAndSettle();

      expect(find.text('主密码长度至少为 10 个字符'), findsOneWidget);

      // 2. 两次输入不一致
      await tester.enterText(fields.at(1), 'newPassword123');
      await tester.enterText(fields.at(2), 'mismatched123');
      await tester.tap(find.text('确认修改'));
      await tester.pumpAndSettle();

      expect(find.text('两次输入的主密码不一致'), findsOneWidget);

      // 3. 当前密码错误
      await tester.enterText(fields.at(0), 'wrongPassword123');
      await tester.enterText(fields.at(1), 'newPassword123');
      await tester.enterText(fields.at(2), 'newPassword123');
      await tester.runAsync(() async {
        await tester.tap(find.text('确认修改'));
        for (var i = 0; i < 50; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          if (find.text('当前主密码不正确').evaluate().isNotEmpty) break;
        }
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('当前主密码不正确'), findsOneWidget);

      // 4. 输入正确信息确认修改
      await tester.enterText(fields.at(0), masterPassword);
      await tester.enterText(fields.at(1), 'newPassword123');
      await tester.enterText(fields.at(2), 'newPassword123');
      await tester.runAsync(() async {
        await tester.tap(find.text('确认修改'));
        for (var i = 0; i < 50; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          if (find.text('主密码已修改').evaluate().isNotEmpty) break;
        }
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('主密码已修改'), findsOneWidget);

      // 验证新密码可以解锁保险库
      await tester.runAsync(() async {
        final newSensitive = Sensitive(
          Uint8List.fromList(utf8.encode('newPassword123')),
        );
        final sessionRes = await vault.unlockWithPassword(newSensitive);
        newSensitive.wipe();
        expect(sessionRes.isOk, isTrue);
        (sessionRes as Ok<VaultSession>).value.close();
      });
    });
  });
}
