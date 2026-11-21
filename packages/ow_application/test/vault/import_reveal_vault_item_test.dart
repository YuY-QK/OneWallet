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
  late InMemoryVaultMetaRepository vaultMetaRepo;
  late InMemoryAccountRepository accountRepo;
  late SequentialIds ids;
  late ImportVaultItem importVaultItem;
  late RevealVaultItem revealVaultItem;

  const validMnemonic =
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
  const masterPasswordStr = 'MasterPassword123';

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
    vaultMetaRepo = InMemoryVaultMetaRepository();
    accountRepo = InMemoryAccountRepository();
    ids = SequentialIds();

    importVaultItem = ImportVaultItem(
      vaultAccess: access,
      vaultMetaRepo: vaultMetaRepo,
      accountRepo: accountRepo,
      settings: settings,
      ids: ids,
      clock: clock,
    );
    revealVaultItem = RevealVaultItem(vaultAccess: access);

    final pw = sensitiveString(masterPasswordStr);
    final createRes = await vault.create(pw);
    createRes.valueOrNull!.close();
    pw.wipe();
    crypto.argon2idCalls = 0;
  });

  group('T5: ImportVaultItem 往返与校验', () {
    test('助记词（不带 passphrase、空 passphrase、带 passphrase）导入与 Reveal 往返', () async {
      final cred = PasswordCredential(sensitiveString(masterPasswordStr));

      // 1. 不带 passphrase
      final m1 = sensitiveString(
        '  Abandon  ABANDON abandon abandon abandon abandon abandon abandon abandon abandon abandon about  ',
      );
      final res1 = await importVaultItem(
        credential: cred,
        name: 'Mnemonic 1',
        input: MnemonicInput(mnemonic: m1),
      );
      expect(res1, isA<Ok<ImportedItem>>());
      final item1 = (res1 as Ok<ImportedItem>).value;

      final revRes1 = await revealVaultItem(itemId: item1.id, credential: cred);
      expect(revRes1, isA<Ok<VaultItemSecret>>());
      final sec1 = (revRes1 as Ok<VaultItemSecret>).value as MnemonicSecret;
      expect(sec1.mnemonic.use((b) => utf8.decode(b)), validMnemonic);
      expect(sec1.passphrase, isNull);
      sec1.wipe();
      m1.wipe();

      // 2. 空 passphrase
      final m2 = sensitiveString(
        'legal winner thank year wave sausage worth useful legal winner thank yellow',
      );
      final passEmpty = sensitiveString('');
      final res2 = await importVaultItem(
        credential: cred,
        name: 'Mnemonic 2',
        input: MnemonicInput(mnemonic: m2, passphrase: passEmpty),
      );
      expect(res2, isA<Ok<ImportedItem>>());
      final item2 = (res2 as Ok<ImportedItem>).value;

      final revRes2 = await revealVaultItem(itemId: item2.id, credential: cred);
      expect(revRes2, isA<Ok<VaultItemSecret>>());
      final sec2 = (revRes2 as Ok<VaultItemSecret>).value as MnemonicSecret;
      expect(sec2.passphrase, isNotNull);
      expect(sec2.passphrase!.use((b) => utf8.decode(b)), '');
      sec2.wipe();
      m2.wipe();
      passEmpty.wipe();

      // 3. 带 passphrase
      final m3 = sensitiveString(
        'letter advice cage absurd amount doctor acoustic avoid letter advice cage above',
      );
      final pass3 = sensitiveString('my-secret-passphrase');
      final res3 = await importVaultItem(
        credential: cred,
        name: 'Mnemonic 3',
        input: MnemonicInput(mnemonic: m3, passphrase: pass3),
      );
      expect(res3, isA<Ok<ImportedItem>>());
      final item3 = (res3 as Ok<ImportedItem>).value;

      final revRes3 = await revealVaultItem(itemId: item3.id, credential: cred);
      expect(revRes3, isA<Ok<VaultItemSecret>>());
      final sec3 = (revRes3 as Ok<VaultItemSecret>).value as MnemonicSecret;
      expect(
        sec3.passphrase!.use((b) => utf8.decode(b)),
        'my-secret-passphrase',
      );
      sec3.wipe();
      m3.wipe();
      pass3.wipe();

      cred.password.wipe();
    });

    test('4 种家族私钥导入与 Reveal 往返', () async {
      final cred = PasswordCredential(sensitiveString(masterPasswordStr));

      // EVM
      final evmRaw = sensitiveString(
        '0x0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF',
      );
      final evmRes = await importVaultItem(
        credential: cred,
        name: 'EVM Key',
        input: PrivateKeyInput(family: ChainFamily.evm, key: evmRaw),
      );
      expect(evmRes, isA<Ok<ImportedItem>>());
      final evmItem = (evmRes as Ok<ImportedItem>).value;
      final evmRev = await revealVaultItem(
        itemId: evmItem.id,
        credential: cred,
      );
      final evmSec = (evmRev as Ok<VaultItemSecret>).value as PrivateKeySecret;
      expect(
        evmSec.key.use((b) => utf8.decode(b)),
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      );
      evmSec.wipe();
      evmRaw.wipe();

      // Tron
      final tronRaw = sensitiveString(
        '0X0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      );
      final tronRes = await importVaultItem(
        credential: cred,
        name: 'Tron Key',
        input: PrivateKeyInput(family: ChainFamily.tron, key: tronRaw),
      );
      expect(tronRes, isA<Ok<ImportedItem>>());
      final tronItem = (tronRes as Ok<ImportedItem>).value;
      final tronRev = await revealVaultItem(
        itemId: tronItem.id,
        credential: cred,
      );
      final tronSec =
          (tronRev as Ok<VaultItemSecret>).value as PrivateKeySecret;
      expect(
        tronSec.key.use((b) => utf8.decode(b)),
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      );
      tronSec.wipe();
      tronRaw.wipe();

      // Bitcoin (WIF)
      const btcWif = 'KwDiBf89QgGbjEhKnhXJuH7LrciVrZi3qYjgd9M7rFU73sVHnoWn';
      final btcRaw = sensitiveString(btcWif);
      final btcRes = await importVaultItem(
        credential: cred,
        name: 'Bitcoin Key',
        input: PrivateKeyInput(family: ChainFamily.bitcoin, key: btcRaw),
      );
      expect(btcRes, isA<Ok<ImportedItem>>());
      final btcItem = (btcRes as Ok<ImportedItem>).value;
      final btcRev = await revealVaultItem(
        itemId: btcItem.id,
        credential: cred,
      );
      final btcSec = (btcRev as Ok<VaultItemSecret>).value as PrivateKeySecret;
      expect(btcSec.key.use((b) => utf8.decode(b)), btcWif);
      btcSec.wipe();
      btcRaw.wipe();

      // Solana (Base58 32-byte seed)
      const solB58 = '4vJ9JU1bJJE96FWSJKvHsmmFADCg4gpZQff4P3bkLKi';
      final solRaw = sensitiveString(solB58);
      final solRes = await importVaultItem(
        credential: cred,
        name: 'Solana Key',
        input: PrivateKeyInput(family: ChainFamily.solana, key: solRaw),
      );
      expect(solRes, isA<Ok<ImportedItem>>());
      final solItem = (solRes as Ok<ImportedItem>).value;
      final solRev = await revealVaultItem(
        itemId: solItem.id,
        credential: cred,
      );
      final solSec = (solRev as Ok<VaultItemSecret>).value as PrivateKeySecret;
      expect(solSec.key.use((b) => utf8.decode(b)), solB58);
      solSec.wipe();
      solRaw.wipe();

      cred.password.wipe();
    });

    test('格式错误时不执行 Argon2id', () async {
      final cred = PasswordCredential(sensitiveString(masterPasswordStr));
      crypto.argon2idCalls = 0;

      // 助记词词数错误
      final badMnemonic = sensitiveString('abandon abandon about');
      final res1 = await importVaultItem(
        credential: cred,
        name: 'Bad Mnemonic',
        input: MnemonicInput(mnemonic: badMnemonic),
      );
      expect(res1, isA<Err<ImportedItem>>());
      expect(crypto.argon2idCalls, 0);
      badMnemonic.wipe();

      // 私钥十六进制长度错误
      final badKey = sensitiveString('0x1234');
      final res2 = await importVaultItem(
        credential: cred,
        name: 'Bad Key',
        input: PrivateKeyInput(family: ChainFamily.evm, key: badKey),
      );
      expect(res2, isA<Err<ImportedItem>>());
      expect(crypto.argon2idCalls, 0);
      badKey.wipe();

      cred.password.wipe();
    });

    test('重复导入返回 duplicate failure 且 detail 含有已有条目的 id', () async {
      final cred = PasswordCredential(sensitiveString(masterPasswordStr));

      final m1 = sensitiveString(validMnemonic);
      final res1 = await importVaultItem(
        credential: cred,
        name: 'Item 1',
        input: MnemonicInput(mnemonic: m1),
      );
      expect(res1, isA<Ok<ImportedItem>>());
      final firstId = (res1 as Ok<ImportedItem>).value.id;

      // 相同助记词重复导入
      final res2 = await importVaultItem(
        credential: cred,
        name: 'Item 2',
        input: MnemonicInput(mnemonic: m1),
      );
      expect(res2, isA<Err<ImportedItem>>());
      expect((res2 as Err).failure, isA<ValidationFailure>());
      expect(((res2 as Err).failure as ValidationFailure).detail, firstId);

      m1.wipe();
      cred.password.wipe();
    });

    test('元数据写入失败时保险库里的条目被删掉（补偿）', () async {
      final cred = PasswordCredential(sensitiveString(masterPasswordStr));

      // 制造元数据仓储异常
      final failingMeta = _FailingVaultMetaRepository();
      final customImport = ImportVaultItem(
        vaultAccess: access,
        vaultMetaRepo: failingMeta,
        accountRepo: accountRepo,
        settings: settings,
        ids: ids,
        clock: clock,
      );

      final m = sensitiveString(validMnemonic);
      final res = await customImport(
        credential: cred,
        name: 'Will Fail',
        input: MnemonicInput(mnemonic: m),
      );
      expect(res, isA<Err<ImportedItem>>());
      expect((res as Err).failure, isA<UnknownFailure>());

      // 验证保险库中该条目已经被补偿删除了
      await access.withSession(cred, (session) async {
        expect(await session.readItem('id-1'), isA<Err<VaultItemSecret>>());
        return const Ok(null);
      });

      m.wipe();
      cred.password.wipe();
    });

    test('linkToAccountId 生效且 vaultChangedAt 被更新', () async {
      final cred = PasswordCredential(sensitiveString(masterPasswordStr));

      // 创建一个钱包账户
      final acc = Account(
        id: 'acc-1',
        type: AccountType.wallet,
        name: 'My Wallet',
        colorIndex: 0,
        createdAt: clock.nowUtc(),
      );
      await accountRepo.upsert(acc);

      final m = sensitiveString(validMnemonic);
      final res = await importVaultItem(
        credential: cred,
        name: 'Linked Item',
        input: MnemonicInput(mnemonic: m),
        linkToAccountId: 'acc-1',
      );
      expect(res, isA<Ok<ImportedItem>>());
      final itemId = (res as Ok<ImportedItem>).value.id;

      final updatedAcc = await accountRepo.byId('acc-1');
      expect(updatedAcc!.vaultItemId, itemId);

      final s = await settings.watch().first;
      expect(s.vaultChangedAt, clock.nowUtc());

      m.wipe();
      cred.password.wipe();
    });
  });

  group('T6: RevealVaultItem', () {
    test('条目不存在返回 VaultItemNotFoundFailure', () async {
      final cred = PasswordCredential(sensitiveString(masterPasswordStr));
      final res = await revealVaultItem(
        itemId: 'non-existent',
        credential: cred,
      );
      expect(res, isA<Err<VaultItemSecret>>());
      expect((res as Err).failure, isA<VaultItemNotFoundFailure>());
      cred.password.wipe();
    });

    test('两次调用都各自走一次解锁（计数断言无缓存）', () async {
      final cred = PasswordCredential(sensitiveString(masterPasswordStr));
      final m = sensitiveString(validMnemonic);
      final impRes = await importVaultItem(
        credential: cred,
        name: 'Test Item',
        input: MnemonicInput(mnemonic: m),
      );
      final itemId = (impRes as Ok<ImportedItem>).value.id;
      m.wipe();

      crypto.argon2idCalls = 0;

      // 第一次 reveal
      final rev1 = await revealVaultItem(itemId: itemId, credential: cred);
      expect(rev1, isA<Ok<VaultItemSecret>>());
      (rev1 as Ok<VaultItemSecret>).value.wipe();
      expect(crypto.argon2idCalls, 1);

      // 第二次 reveal
      final rev2 = await revealVaultItem(itemId: itemId, credential: cred);
      expect(rev2, isA<Ok<VaultItemSecret>>());
      (rev2 as Ok<VaultItemSecret>).value.wipe();
      expect(crypto.argon2idCalls, 2);

      cred.password.wipe();
    });
  });
}

final class _FailingVaultMetaRepository implements VaultMetaRepository {
  @override
  Stream<List<VaultItemMeta>> watchAll() => const Stream.empty();

  @override
  Future<VaultItemMeta?> byFingerprint(String fingerprint) async => null;

  @override
  Future<void> upsert(VaultItemMeta meta) async {
    throw Exception('Simulated metadata write failure');
  }

  @override
  Future<void> delete(String id) async {}
}
