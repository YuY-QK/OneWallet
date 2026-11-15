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
  group('T17: 内存与日志防泄漏测试', () {
    late SodiumVaultCrypto crypto;

    const secretMnemonic =
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
    const secretMnemonic2 =
        'legal winner thank year wave sausage worth useful legal winner thank yellow';
    const secretEvmKey =
        '0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
    const secretBtcKey = '5HueCGU8rMjxEXxiPuD5BDku4MkFqeZyd4dZ1jvhTVqvbTLvyTJ';
    const secretPassword = 'MasterPassword123';
    const secretPassphrase = 'my-bip39-passphrase';
    const secretApiKey = 'my-secret-api-key-999';
    const secretApiSecret = 'my-super-secret-api-secret-888';

    final sensitiveCorpus = [
      'abandon',
      'about',
      'legal',
      'winner',
      'yellow',
      secretMnemonic,
      secretMnemonic2,
      secretEvmKey,
      secretBtcKey,
      secretPassword,
      secretPassphrase,
      secretApiKey,
      secretApiSecret,
    ];

    void assertNoLeaks(String text, {String? context}) {
      for (final secret in sensitiveCorpus) {
        expect(
          text.contains(secret),
          isFalse,
          reason: '泄露了敏感数据 "$secret"${context != null ? " 在 $context" : ""}',
        );
      }
    }

    setUpAll(() async {
      crypto = await SodiumVaultCrypto.load();
    });

    test('全部结果对象的 toString() 不包含任何敏感词', () {
      final summary = const BackupSummary(
        accountsCount: 1,
        addressesCount: 2,
        vaultItemsCount: 3,
        hasCredentials: true,
      );
      assertNoLeaks(summary.toString(), context: 'BackupSummary.toString');

      final preview = BackupPreview(
        createdAt: DateTime.utc(2026, 1, 1),
        appVersion: '1.0.0',
        accountsCount: 1,
        addressesCount: 2,
        vaultItemsCount: 3,
        hasCredentials: true,
        skippedCount: 0,
      );
      assertNoLeaks(preview.toString(), context: 'BackupPreview.toString');

      final pending = PendingRestore(
        BackupPayload(
          exportedAt: DateTime.utc(2026, 1, 1),
          accounts: const [],
          addresses: const [],
          vaultItems: const [],
          settings: BackupSettings.of(const AppSettings()),
        ),
        BackupHeader(
          containerVersion: 1,
          createdAt: DateTime.utc(2026, 1, 1),
          appVersion: '1.0.0',
          kdfParams: testKdfParams,
        ),
      );
      assertNoLeaks(pending.toString(), context: 'PendingRestore.toString');
      pending.dispose();

      final report = const RestoreReport(
        accountsAdded: 1,
        accountsSkipped: 0,
        addressesAdded: 2,
        addressesSkipped: 0,
        itemsAdded: 1,
        itemsSkipped: 0,
        credentialsAdded: 1,
        unreadable: [],
      );
      assertNoLeaks(report.toString(), context: 'RestoreReport.toString');

      final imported = const ImportedItem(
        id: 'item-1',
        kind: VaultItemKind.mnemonic,
        fingerprint: 'fp-1',
      );
      assertNoLeaks(imported.toString(), context: 'ImportedItem.toString');

      final derived = const DerivedAddress(
        family: ChainFamily.evm,
        address: '0x9858EfFD232B4033E47d90003D41EC34EcaEda94',
        scheme: DerivationScheme.evmStandard,
        index: 0,
        alreadyWatched: false,
      );
      assertNoLeaks(derived.toString(), context: 'DerivedAddress.toString');

      final creds = ExchangeCredentials(
        apiKey: sensitiveString(secretApiKey),
        apiSecret: sensitiveString(secretApiSecret),
      );
      assertNoLeaks(creds.toString(), context: 'ExchangeCredentials.toString');
      creds.apiKey.wipe();
      creds.apiSecret.wipe();

      const lockState = Unlocked(3);
      assertNoLeaks(lockState.toString(), context: 'LockState.toString');

      const appLockUninit = AppLockUninitialized();
      assertNoLeaks(
        appLockUninit.toString(),
        context: 'AppLockUninitialized.toString',
      );
      const appLockLocked = AppLockLocked();
      assertNoLeaks(
        appLockLocked.toString(),
        context: 'AppLockLocked.toString',
      );
      const appLockUnlocked = AppLockUnlocked();
      assertNoLeaks(
        appLockUnlocked.toString(),
        context: 'AppLockUnlocked.toString',
      );
    });

    test('导入与派生失败时的 Failure.detail 和 toString() 不泄露明文', () async {
      final storage = MemoryVaultStorage();
      final vault = Vault(
        crypto: crypto,
        storage: storage,
        defaultParams: testKdfParams,
      );
      final secretStore = MemorySecretStore();
      final capabilities = FakePlatformCapabilities();
      final hardwareStore = FakeHardwareKeyStore();
      final settingsRepo = InMemorySettingsRepository(const AppSettings());
      final clock = FakeClock();
      final limiter = AttemptLimiter(
        keyPrefix: 'ow.vault.unlock',
        store: secretStore,
        clock: clock,
      );
      final vaultAccess = VaultAccess(
        vault: vault,
        hardwareKeyStore: hardwareStore,
        secretStore: secretStore,
        capabilities: capabilities,
        settings: settingsRepo,
        passwordLimiter: limiter,
      );
      final vaultMetaRepo = InMemoryVaultMetaRepository();
      final accountRepo = InMemoryAccountRepository();

      final importVaultItem = ImportVaultItem(
        vaultAccess: vaultAccess,
        vaultMetaRepo: vaultMetaRepo,
        accountRepo: accountRepo,
        settings: settingsRepo,
        ids: SequentialIds(),
        clock: clock,
      );

      // 创建保险库
      final pw = sensitiveString(secretPassword);
      final cRes = await vault.create(pw);
      cRes.valueOrNull!.close();

      final cred = PasswordCredential(pw);

      // 1. 非法助记词导入失败
      final badMnemonicStr = '$secretMnemonic badwordxyz';
      final badSens = sensitiveString(badMnemonicStr);
      final fail1 = await importVaultItem(
        credential: cred,
        name: 'Bad Mnemonic',
        input: MnemonicInput(
          mnemonic: badSens,
          passphrase: sensitiveString(secretPassphrase),
        ),
      );
      badSens.wipe();

      expect(fail1, isA<Err<ImportedItem>>());
      final f1 = (fail1 as Err<ImportedItem>).failure;
      assertNoLeaks(
        f1.toString(),
        context: 'Invalid Mnemonic Failure.toString',
      );
      if (f1 is ValidationFailure && f1.detail != null) {
        assertNoLeaks(f1.detail!, context: 'Invalid Mnemonic Failure.detail');
      }

      // 2. 非法私钥导入失败
      final badKeySens = sensitiveString('${secretEvmKey}ZZZZ');
      final fail2 = await importVaultItem(
        credential: cred,
        name: 'Bad Key',
        input: PrivateKeyInput(family: ChainFamily.evm, key: badKeySens),
      );
      badKeySens.wipe();

      expect(fail2, isA<Err<ImportedItem>>());
      final f2 = (fail2 as Err<ImportedItem>).failure;
      assertNoLeaks(f2.toString(), context: 'Invalid Key Failure.toString');
      if (f2 is ValidationFailure && f2.detail != null) {
        assertNoLeaks(f2.detail!, context: 'Invalid Key Failure.detail');
      }

      // 3. 错误密码解锁失败
      final wrongPw = sensitiveString('${secretPassword}_wrong');
      final fail3 = await vaultAccess.withSession(
        PasswordCredential(wrongPw),
        (session) async => const Ok(null),
      );
      wrongPw.wipe();

      expect(fail3, isA<Err<void>>());
      final f3 = (fail3 as Err<void>).failure;
      assertNoLeaks(f3.toString(), context: 'Wrong Password Failure.toString');

      pw.wipe();
    });
  });
}
