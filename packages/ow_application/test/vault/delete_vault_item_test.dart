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
  late DeleteVaultItem deleteVaultItem;

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
    deleteVaultItem = DeleteVaultItem(
      vaultAccess: access,
      vaultMetaRepo: vaultMetaRepo,
      accountRepo: accountRepo,
      settings: settings,
      clock: clock,
    );

    final pw = sensitiveString(masterPasswordStr);
    final createRes = await vault.create(pw);
    createRes.valueOrNull!.close();
    pw.wipe();
  });

  group('T7: DeleteVaultItem', () {
    test('删除后条目、元数据与账户关联被清理，且更新 vaultChangedAt', () async {
      final cred = PasswordCredential(sensitiveString(masterPasswordStr));

      // 导入条目并关联账户
      final acc = Account(
        id: 'acc-1',
        type: AccountType.wallet,
        name: 'Wallet 1',
        colorIndex: 0,
        createdAt: clock.nowUtc(),
      );
      await accountRepo.upsert(acc);

      final m = sensitiveString(validMnemonic);
      final impRes = await importVaultItem(
        credential: cred,
        name: 'Item to delete',
        input: MnemonicInput(mnemonic: m),
        linkToAccountId: 'acc-1',
      );
      final itemId = (impRes as Ok<ImportedItem>).value.id;
      m.wipe();

      expect((await accountRepo.byId('acc-1'))!.vaultItemId, itemId);
      expect(await vaultMetaRepo.watchAll().first, isNotEmpty);

      // 拨动时钟
      clock.advance(const Duration(minutes: 5));
      final deleteTime = clock.nowUtc();

      // 执行删除
      final delRes = await deleteVaultItem(itemId: itemId, credential: cred);
      expect(delRes, isA<Ok<void>>());

      // 元数据已清
      final metas = await vaultMetaRepo.watchAll().first;
      expect(metas.where((x) => x.id == itemId), isEmpty);

      // 账户关联已清空
      expect((await accountRepo.byId('acc-1'))!.vaultItemId, isNull);

      // 保险库条目已删
      await access.withSession(cred, (session) async {
        expect(await session.readItem(itemId), isA<Err<VaultItemSecret>>());
        return const Ok(null);
      });

      // vaultChangedAt 已更新
      final s = await settings.watch().first;
      expect(s.vaultChangedAt, deleteTime);

      cred.password.wipe();
    });

    test('保险库里已无条目而元数据还在时幂等成功', () async {
      final cred = PasswordCredential(sensitiveString(masterPasswordStr));

      // 手动往元数据写一条不存在于保险库的条目
      final meta = VaultItemMeta(
        id: 'phantom-item',
        name: 'Phantom',
        kind: VaultItemKind.mnemonic,
        hasPassphrase: false,
        fingerprint: 'dummy-fp',
        createdAt: clock.nowUtc(),
      );
      await vaultMetaRepo.upsert(meta);

      final acc = Account(
        id: 'acc-2',
        type: AccountType.wallet,
        name: 'Wallet 2',
        colorIndex: 1,
        createdAt: clock.nowUtc(),
        vaultItemId: 'phantom-item',
      );
      await accountRepo.upsert(acc);

      // 删除应该幂等成功并清理元数据和账户关联
      final res = await deleteVaultItem(
        itemId: 'phantom-item',
        credential: cred,
      );
      expect(res, isA<Ok<void>>());

      expect(await vaultMetaRepo.watchAll().first, isEmpty);
      expect((await accountRepo.byId('acc-2'))!.vaultItemId, isNull);

      cred.password.wipe();
    });
  });
}
