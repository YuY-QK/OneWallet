import 'dart:convert';
import 'dart:io';
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
  late InMemoryAddressRepository addressRepo;
  late SequentialIds ids;
  late ImportVaultItem importVaultItem;
  late DeriveAddresses deriveAddresses;

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
    addressRepo = InMemoryAddressRepository();
    ids = SequentialIds();

    importVaultItem = ImportVaultItem(
      vaultAccess: access,
      vaultMetaRepo: vaultMetaRepo,
      accountRepo: accountRepo,
      settings: settings,
      ids: ids,
      clock: clock,
    );
    deriveAddresses = DeriveAddresses(
      vaultAccess: access,
      addressRepo: addressRepo,
    );

    final pw = sensitiveString(masterPasswordStr);
    final createRes = await vault.create(pw);
    createRes.valueOrNull!.close();
    pw.wipe();
  });

  group('T8: DeriveAddresses', () {
    test('助记词条目的 9 种派生方案各取前 3 个地址，与 derivation_vectors.json 一致', () async {
      final cred = PasswordCredential(sensitiveString(masterPasswordStr));

      // 导入助记词条目
      final m = sensitiveString(validMnemonic);
      final impRes = await importVaultItem(
        credential: cred,
        name: 'Mnemonic Item',
        input: MnemonicInput(mnemonic: m),
      );
      final itemId = (impRes as Ok<ImportedItem>).value.id;
      m.wipe();

      // 读取测试向量
      final vectorFile = File(
        '../ow_vault/test/fixtures/derivation_vectors.json',
      );
      final jsonStr = await vectorFile.readAsString();
      final fixture = jsonDecode(jsonStr) as Map<String, dynamic>;
      final cases = fixture['cases'] as List<dynamic>;
      final abandonCase = cases.firstWhere(
        (c) => (c as Map<String, dynamic>)['name'] == 'abandon',
      ) as Map<String, dynamic>;
      final expectedAddresses =
          abandonCase['addresses'] as Map<String, dynamic>;

      const schemeMap = {
        'evmStandard': DerivationScheme.evmStandard,
        'evmLedgerLive': DerivationScheme.evmLedgerLive,
        'btcNativeSegwit': DerivationScheme.btcNativeSegwit,
        'btcTaproot': DerivationScheme.btcTaproot,
        'btcNestedSegwit': DerivationScheme.btcNestedSegwit,
        'btcLegacy': DerivationScheme.btcLegacy,
        'solanaStandard': DerivationScheme.solanaStandard,
        'solanaLegacy': DerivationScheme.solanaLegacy,
        'tronStandard': DerivationScheme.tronStandard,
      };

      for (final entry in schemeMap.entries) {
        final schemeName = entry.key;
        final scheme = entry.value;
        final expectedList = (expectedAddresses[schemeName] as List<dynamic>)
            .cast<String>();

        final deriveRes = await deriveAddresses(
          itemId: itemId,
          credential: cred,
          scheme: scheme,
          startIndex: 0,
          count: 3,
        );

        expect(
          deriveRes,
          isA<Ok<List<DerivedAddress>>>(),
          reason: '方案 $schemeName 派生应该成功',
        );

        final derived = (deriveRes as Ok<List<DerivedAddress>>).value;
        expect(derived.length, 3);

        for (var i = 0; i < 3; i++) {
          final expectedAddr = expectedList[i];
          final normalizedExpected = AddressCodec.normalize(
            expectedAddr,
            scheme.family,
          );
          expect(
            derived[i].address,
            normalizedExpected,
            reason: '方案 $schemeName 第 $i 个地址不匹配',
          );
          expect(derived[i].family, scheme.family);
          expect(derived[i].scheme, scheme);
          expect(derived[i].index, i);
          expect(derived[i].alreadyWatched, isFalse);
        }
      }

      cred.password.wipe();
    });

    test('私钥条目返回 1 个地址', () async {
      final cred = PasswordCredential(sensitiveString(masterPasswordStr));

      // 导入 EVM 私钥
      final evmRaw = sensitiveString(
        '0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      );
      final impRes = await importVaultItem(
        credential: cred,
        name: 'EVM Key',
        input: PrivateKeyInput(family: ChainFamily.evm, key: evmRaw),
      );
      final itemId = (impRes as Ok<ImportedItem>).value.id;
      evmRaw.wipe();

      final res = await deriveAddresses(
        itemId: itemId,
        credential: cred,
        scheme: DerivationScheme.evmStandard,
        startIndex: 0,
        count: 1,
      );

      expect(res, isA<Ok<List<DerivedAddress>>>());
      final list = (res as Ok<List<DerivedAddress>>).value;
      expect(list.length, 1);
      expect(list[0].family, ChainFamily.evm);
      expect(list[0].index, isNull);
      expect(list[0].scheme, isNull);

      cred.password.wipe();
    });

    test('alreadyWatched 正确标记已在仓储中的地址', () async {
      final cred = PasswordCredential(sensitiveString(masterPasswordStr));

      // 预先在地址仓储添加一个地址
      const watchedAddr = '0x9858EfFD232B4033E47d90003D41EC34EcaEda94';
      await addressRepo.upsert(
        WatchAddress(
          id: 'addr-1',
          accountId: 'acc-1',
          family: ChainFamily.evm,
          address: AddressCodec.normalize(watchedAddr, ChainFamily.evm),
          enabledChainIds: {'ethereum'},
        ),
      );

      final m = sensitiveString(validMnemonic);
      final impRes = await importVaultItem(
        credential: cred,
        name: 'Mnemonic Item',
        input: MnemonicInput(mnemonic: m),
      );
      final itemId = (impRes as Ok<ImportedItem>).value.id;
      m.wipe();

      final res = await deriveAddresses(
        itemId: itemId,
        credential: cred,
        scheme: DerivationScheme.evmStandard,
        startIndex: 0,
        count: 3,
      );

      expect(res, isA<Ok<List<DerivedAddress>>>());
      final list = (res as Ok<List<DerivedAddress>>).value;
      expect(list[0].alreadyWatched, isTrue);
      expect(list[1].alreadyWatched, isFalse);
      expect(list[2].alreadyWatched, isFalse);

      cred.password.wipe();
    });

    test('count 越界（< 1 或 > 20）被拒绝', () async {
      final cred = PasswordCredential(sensitiveString(masterPasswordStr));

      final res1 = await deriveAddresses(
        itemId: 'dummy',
        credential: cred,
        scheme: DerivationScheme.evmStandard,
        startIndex: 0,
        count: 0,
      );
      expect(res1, isA<Err<List<DerivedAddress>>>());
      expect((res1 as Err).failure, isA<ValidationFailure>());

      final res2 = await deriveAddresses(
        itemId: 'dummy',
        credential: cred,
        scheme: DerivationScheme.evmStandard,
        startIndex: 0,
        count: 21,
      );
      expect(res2, isA<Err<List<DerivedAddress>>>());
      expect((res2 as Err).failure, isA<ValidationFailure>());

      final res3 = await deriveAddresses(
        itemId: 'dummy',
        credential: cred,
        scheme: DerivationScheme.evmStandard,
        startIndex: -1,
        count: 5,
      );
      expect(res3, isA<Err<List<DerivedAddress>>>());
      expect((res3 as Err).failure, isA<ValidationFailure>());

      cred.password.wipe();
    });
  });
}
