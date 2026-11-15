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

  setUpAll(() async {
    crypto = await SodiumVaultCrypto.load();
  });

  group('T12: ExportBackup -> OpenBackup -> RestoreBackup(fresh)', () {
    late MemoryVaultStorage storage;
    late Vault vault;
    late MemorySecretStore secretStore;
    late FakePlatformCapabilities capabilities;
    late FakeHardwareKeyStore hardwareStore;
    late InMemorySettingsRepository settingsRepo;
    late AttemptLimiter limiter;
    late VaultAccess vaultAccess;
    late InMemoryVaultMetaRepository vaultMetaRepo;
    late InMemoryAddressRepository addressRepo;
    late InMemoryAccountRepository accountRepo;
    late InMemoryCredentialRepository credentialRepo;
    late SequentialIds ids;
    late FakeClock clock;

    late ExportBackup exportBackup;
    late ConfirmBackupSaved confirmBackupSaved;
    late OpenBackup openBackup;
    late RestoreBackup restoreBackup;

    const masterPasswordStr = 'MasterPassword123';
    const backupPasswordStr = 'BackupPassword456';
    const mnemonicStr =
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

    setUp(() async {
      storage = MemoryVaultStorage();
      vault = Vault(
        crypto: crypto,
        storage: storage,
        defaultParams: testKdfParams,
      );
      secretStore = MemorySecretStore();
      capabilities = FakePlatformCapabilities();
      hardwareStore = FakeHardwareKeyStore();
      settingsRepo = InMemorySettingsRepository(
        const AppSettings(
          quote: Quote.cny,
          theme: ThemePreference.dark,
          hideSmall: false,
        ),
      );
      clock = FakeClock();
      limiter = AttemptLimiter(
        keyPrefix: 'ow.vault.unlock',
        store: secretStore,
        clock: clock,
      );
      vaultAccess = VaultAccess(
        vault: vault,
        hardwareKeyStore: hardwareStore,
        secretStore: secretStore,
        capabilities: capabilities,
        settings: settingsRepo,
        passwordLimiter: limiter,
      );
      vaultMetaRepo = InMemoryVaultMetaRepository();
      addressRepo = InMemoryAddressRepository();
      accountRepo = InMemoryAccountRepository(addresses: addressRepo);
      credentialRepo = InMemoryCredentialRepository();
      ids = SequentialIds();

      exportBackup = ExportBackup(
        vaultAccess: vaultAccess,
        vaultMetaRepo: vaultMetaRepo,
        accountRepo: accountRepo,
        addressRepo: addressRepo,
        credentialRepo: credentialRepo,
        settings: settingsRepo,
        crypto: crypto,
        clock: clock,
        appVersion: '1.0.0',
      );
      confirmBackupSaved = ConfirmBackupSaved(
        settings: settingsRepo,
        clock: clock,
      );
      openBackup = OpenBackup(crypto: crypto);
      restoreBackup = RestoreBackup(
        vault: vault,
        vaultAccess: vaultAccess,
        vaultMetaRepo: vaultMetaRepo,
        accountRepo: accountRepo,
        addressRepo: addressRepo,
        credentialRepo: credentialRepo,
        settings: settingsRepo,
        ids: ids,
        clock: clock,
      );

      // 创建保险库并导入助记词
      final pw = sensitiveString(masterPasswordStr);
      final cRes = await vault.create(pw);
      cRes.valueOrNull!.close();

      final mSens = sensitiveString(mnemonicStr);
      await vaultAccess.withSession(PasswordCredential(pw), (session) async {
        await session.addItem('item-1', MnemonicSecret(mnemonic: mSens));
        return const Ok(null);
      });
      mSens.wipe();
      pw.wipe();

      await vaultMetaRepo.upsert(
        VaultItemMeta(
          id: 'item-1',
          name: 'Main Mnemonic',
          kind: VaultItemKind.mnemonic,
          fingerprint: 'fp-mnemonic-1',
          hasPassphrase: false,
          createdAt: clock.nowUtc(),
        ),
      );

      // 创建一个钱包账户和一个交易所账户
      final acc1 = Account(
        id: 'acc-1',
        type: AccountType.wallet,
        name: 'My Wallet',
        colorIndex: 0,
        createdAt: clock.nowUtc(),
        vaultItemId: 'item-1',
        backup: const BackupStatus(),
      );
      final wa1 = WatchAddress(
        id: 'addr-1',
        accountId: 'acc-1',
        family: ChainFamily.evm,
        address: '0x9858EfFD232B4033E47d90003D41EC34EcaEda94',
        enabledChainIds: {'ethereum'},
        scheme: DerivationScheme.evmStandard,
        derivationIndex: 0,
      );
      await accountRepo.insertWithAddresses(acc1, [wa1]);

      final acc2 = Account(
        id: 'acc-2',
        type: AccountType.exchange,
        name: 'My Binance',
        colorIndex: 1,
        createdAt: clock.nowUtc(),
        exchange: ExchangeId.binance,
        backup: const BackupStatus(),
      );
      await accountRepo.upsert(acc2);

      final creds = ExchangeCredentials(
        apiKey: sensitiveString('test-api-key'),
        apiSecret: sensitiveString('test-api-secret'),
      );
      await credentialRepo.save('acc-2', creds);
    });

    test('全程往返（含凭据）：恢复后账户、地址、条目明文、设置与原来一致', () async {
      final masterCred = PasswordCredential(sensitiveString(masterPasswordStr));
      final backupPw = sensitiveString(backupPasswordStr);

      // 1. 导出备份
      final exportRes = await exportBackup(
        masterCredential: masterCred,
        backupPassword: backupPw,
        includeExchangeCredentials: true,
        kdfParams: testKdfParams,
      );
      masterCred.password.wipe();
      expect(exportRes, isA<Ok<ExportedBackup>>());
      final exported = (exportRes as Ok<ExportedBackup>).value;
      expect(exported.summary.accountsCount, 2);
      expect(exported.summary.addressesCount, 1);
      expect(exported.summary.vaultItemsCount, 1);
      expect(exported.summary.hasCredentials, isTrue);

      // 导出后 lastBackupExportedAt 不变
      var currentSettings = await settingsRepo.watch().first;
      expect(currentSettings.lastBackupExportedAt, isNull);

      // ConfirmBackupSaved 后才变
      await confirmBackupSaved();
      currentSettings = await settingsRepo.watch().first;
      expect(currentSettings.lastBackupExportedAt, clock.nowUtc());

      // 2. OpenBackup
      final openRes = await openBackup(
        file: exported.bytes,
        backupPassword: backupPw,
      );
      expect(openRes, isA<Ok<PendingRestore>>());
      final pending = (openRes as Ok<PendingRestore>).value;
      expect(pending.preview.accountsCount, 2);
      expect(pending.preview.hasCredentials, isTrue);

      // 3. 在全新的环境执行 RestoreBackup(fresh)
      final freshStorage = MemoryVaultStorage();
      final freshVault = Vault(
        crypto: crypto,
        storage: freshStorage,
        defaultParams: testKdfParams,
      );
      final freshSecretStore = MemorySecretStore();
      final freshLimiter = AttemptLimiter(
        keyPrefix: 'ow.vault.unlock',
        store: freshSecretStore,
        clock: clock,
      );
      final freshSettings = InMemorySettingsRepository(const AppSettings());
      final freshVaultAccess = VaultAccess(
        vault: freshVault,
        hardwareKeyStore: hardwareStore,
        secretStore: freshSecretStore,
        capabilities: capabilities,
        settings: freshSettings,
        passwordLimiter: freshLimiter,
      );
      final freshVaultMetaRepo = InMemoryVaultMetaRepository();
      final freshAddressRepo = InMemoryAddressRepository();
      final freshAccountRepo = InMemoryAccountRepository(
        addresses: freshAddressRepo,
      );
      final freshCredentialRepo = InMemoryCredentialRepository();
      final freshIds = SequentialIds();

      final freshRestore = RestoreBackup(
        vault: freshVault,
        vaultAccess: freshVaultAccess,
        vaultMetaRepo: freshVaultMetaRepo,
        accountRepo: freshAccountRepo,
        addressRepo: freshAddressRepo,
        credentialRepo: freshCredentialRepo,
        settings: freshSettings,
        ids: freshIds,
        clock: clock,
      );

      final newMasterPw = sensitiveString('NewMasterPassword999');
      final restoreRes = await freshRestore(
        pending: pending,
        mode: RestoreMode.fresh,
        newMasterPassword: newMasterPw,
      );
      expect(restoreRes, isA<Ok<RestoreReport>>());
      final report = (restoreRes as Ok<RestoreReport>).value;
      expect(report.accountsAdded, 2);
      expect(report.addressesAdded, 1);
      expect(report.itemsAdded, 1);
      expect(report.credentialsAdded, 1);

      // 验证恢复后的数据
      // a. 设置已迁移
      final restoredSettings = await freshSettings.watch().first;
      expect(restoredSettings.quote, Quote.cny);
      expect(restoredSettings.theme, ThemePreference.dark);
      expect(restoredSettings.hideSmall, isFalse);

      // b. 账户与地址
      final restoredAccounts = await freshAccountRepo.watchAll().first;
      expect(restoredAccounts.length, 2);
      final restoredWallet = restoredAccounts.firstWhere(
        (a) => a.type == AccountType.wallet,
      );
      expect(restoredWallet.name, 'My Wallet');
      expect(restoredWallet.vaultItemId, isNotNull);

      final restoredAddresses = await freshAddressRepo.watchAll().first;
      expect(restoredAddresses.length, 1);
      expect(
        restoredAddresses.single.address,
        '0x9858EfFD232B4033E47d90003D41EC34EcaEda94',
      );

      // c. 交易所凭据
      final restoredCred = await freshCredentialRepo.load('acc-2');
      expect(restoredCred, isNotNull);
      final loadedApiKey = restoredCred!.apiKey.use(utf8.decode);
      expect(loadedApiKey, 'test-api-key');

      // d. 保险库条目明文与新主密码生效
      final verifyPw = PasswordCredential(newMasterPw);
      final readRes = await freshVaultAccess.withSession(verifyPw, (
        session,
      ) async {
        return session.readItem(restoredWallet.vaultItemId!);
      });
      expect(readRes, isA<Ok<VaultItemSecret>>());
      final secret = (readRes as Ok<VaultItemSecret>).value;
      expect(secret, isA<MnemonicSecret>());
      final readMnemonic = (secret as MnemonicSecret).mnemonic.use(utf8.decode);
      expect(readMnemonic, mnemonicStr);

      newMasterPw.wipe();
      backupPw.wipe();
      pending.dispose();
    });

    test('不含凭据模式：导出的备份不包含交易所凭据', () async {
      final masterCred = PasswordCredential(sensitiveString(masterPasswordStr));
      final backupPw = sensitiveString(backupPasswordStr);

      final exportRes = await exportBackup(
        masterCredential: masterCred,
        backupPassword: backupPw,
        includeExchangeCredentials: false,
        kdfParams: testKdfParams,
      );
      masterCred.password.wipe();
      expect(exportRes, isA<Ok<ExportedBackup>>());
      final exported = (exportRes as Ok<ExportedBackup>).value;
      expect(exported.summary.hasCredentials, isFalse);

      final openRes = await openBackup(
        file: exported.bytes,
        backupPassword: backupPw,
      );
      final pending = (openRes as Ok<PendingRestore>).value;
      expect(pending.preview.hasCredentials, isFalse);

      backupPw.wipe();
      pending.dispose();
    });

    test('元数据有而保险库缺条目时导出失败', () async {
      // 在元数据添加一个保险库中不存在的虚假条目
      await vaultMetaRepo.upsert(
        VaultItemMeta(
          id: 'ghost-item',
          name: 'Ghost',
          kind: VaultItemKind.mnemonic,
          fingerprint: 'fp-ghost',
          hasPassphrase: false,
          createdAt: clock.nowUtc(),
        ),
      );

      final masterCred = PasswordCredential(sensitiveString(masterPasswordStr));
      final backupPw = sensitiveString(backupPasswordStr);

      final exportRes = await exportBackup(
        masterCredential: masterCred,
        backupPassword: backupPw,
        includeExchangeCredentials: false,
        kdfParams: testKdfParams,
      );

      masterCred.password.wipe();
      backupPw.wipe();

      expect(exportRes, isA<Err<ExportedBackup>>());
      final failure = (exportRes as Err<ExportedBackup>).failure;
      expect(failure, isA<VaultItemNotFoundFailure>());
      expect((failure as VaultItemNotFoundFailure).detail, 'ghost-item');
    });

    test('RestoreBackup(fresh) 在非空目标上被拒绝', () async {
      // 当前环境不是空的（有保险库也有账户）
      final pending = PendingRestore(
        BackupPayload(
          exportedAt: clock.nowUtc(),
          accounts: const [],
          addresses: const [],
          vaultItems: const [],
          settings: BackupSettings.of(const AppSettings()),
        ),
        BackupHeader(
          containerVersion: 1,
          createdAt: clock.nowUtc(),
          appVersion: '1.0.0',
          kdfParams: testKdfParams,
        ),
      );

      final newMasterPw = sensitiveString('MasterPassword123');
      final res = await restoreBackup(
        pending: pending,
        mode: RestoreMode.fresh,
        newMasterPassword: newMasterPw,
      );
      newMasterPw.wipe();
      pending.dispose();

      expect(res, isA<Err<RestoreReport>>());
      expect(
        (res as Err<RestoreReport>).failure,
        const ValidationFailure('restore_target_not_empty'),
      );
    });
  });

  group('T13: RestoreBackup(merge)', () {
    late MemoryVaultStorage storage;
    late Vault vault;
    late MemorySecretStore secretStore;
    late FakePlatformCapabilities capabilities;
    late FakeHardwareKeyStore hardwareStore;
    late InMemorySettingsRepository settingsRepo;
    late AttemptLimiter limiter;
    late VaultAccess vaultAccess;
    late InMemoryVaultMetaRepository vaultMetaRepo;
    late InMemoryAddressRepository addressRepo;
    late InMemoryAccountRepository accountRepo;
    late InMemoryCredentialRepository credentialRepo;
    late SequentialIds ids;
    late FakeClock clock;
    late RestoreBackup restoreBackup;

    const masterPasswordStr = 'MasterPassword123';
    const existingMnemonic =
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
    const newMnemonic =
        'legal winner thank year wave sausage worth useful legal winner thank yellow';

    setUp(() async {
      storage = MemoryVaultStorage();
      vault = Vault(
        crypto: crypto,
        storage: storage,
        defaultParams: testKdfParams,
      );
      secretStore = MemorySecretStore();
      capabilities = FakePlatformCapabilities();
      hardwareStore = FakeHardwareKeyStore();
      settingsRepo = InMemorySettingsRepository(
        const AppSettings(quote: Quote.usd),
      );
      clock = FakeClock();
      limiter = AttemptLimiter(
        keyPrefix: 'ow.vault.unlock',
        store: secretStore,
        clock: clock,
      );
      vaultAccess = VaultAccess(
        vault: vault,
        hardwareKeyStore: hardwareStore,
        secretStore: secretStore,
        capabilities: capabilities,
        settings: settingsRepo,
        passwordLimiter: limiter,
      );
      vaultMetaRepo = InMemoryVaultMetaRepository();
      addressRepo = InMemoryAddressRepository();
      accountRepo = InMemoryAccountRepository(addresses: addressRepo);
      credentialRepo = InMemoryCredentialRepository();
      ids = SequentialIds();

      restoreBackup = RestoreBackup(
        vault: vault,
        vaultAccess: vaultAccess,
        vaultMetaRepo: vaultMetaRepo,
        accountRepo: accountRepo,
        addressRepo: addressRepo,
        credentialRepo: credentialRepo,
        settings: settingsRepo,
        ids: ids,
        clock: clock,
      );

      // 创建保险库
      final pw = sensitiveString(masterPasswordStr);
      final cRes = await vault.create(pw);
      cRes.valueOrNull!.close();

      // 本地导入条目 1
      final mSens = sensitiveString(existingMnemonic);
      String existingFp = '';
      await vaultAccess.withSession(PasswordCredential(pw), (session) async {
        final sec = MnemonicSecret(mnemonic: mSens);
        existingFp = session.fingerprintOf(sec);
        await session.addItem('local-item-1', sec);
        return const Ok(null);
      });
      mSens.wipe();
      pw.wipe();

      await vaultMetaRepo.upsert(
        VaultItemMeta(
          id: 'local-item-1',
          name: 'Local Existing Item',
          kind: VaultItemKind.mnemonic,
          fingerprint: existingFp,
          hasPassphrase: false,
          createdAt: clock.nowUtc(),
        ),
      );

      // 本地账户 1（具有重名冲突与地址冲突）
      final localAcc1 = Account(
        id: 'acc-existing-1',
        type: AccountType.wallet,
        name: 'Shared Wallet',
        colorIndex: 0,
        createdAt: clock.nowUtc(),
        vaultItemId: 'local-item-1',
        backup: const BackupStatus(),
      );
      final localAddr1 = WatchAddress(
        id: 'addr-existing-1',
        accountId: 'acc-existing-1',
        family: ChainFamily.evm,
        address: '0x1111111111111111111111111111111111111111',
        enabledChainIds: {'ethereum'},
      );
      await accountRepo.insertWithAddresses(localAcc1, [localAddr1]);
    });

    test('合并规则：条目查重、账户跳过/改名、地址跳过、设置保留', () async {
      final existingSec = MnemonicSecret(
        mnemonic: sensitiveString(existingMnemonic),
      );
      final newSec = MnemonicSecret(mnemonic: sensitiveString(newMnemonic));

      // 备份载荷构造：
      // 1. 条目包含：与本地相同指纹的条目（backup-item-1）+ 全新条目（backup-item-2）
      // 2. 账户包含：
      //    a. 相同 id 账户（acc-existing-1）-> 应被跳过
      //    b. 全部地址与本地冲突的账户（acc-dup-addr）-> 地址全被跳过，账户被跳过
      //    c. 重名账户（Shared Wallet）但包含新地址 -> 改名为 Shared Wallet (2)，vaultItemId 指向 local-item-1
      //    d. 全新账户（New Wallet）包含全新条目引用
      final payload = BackupPayload(
        exportedAt: clock.nowUtc(),
        accounts: [
          Account(
            id: 'acc-existing-1',
            type: AccountType.wallet,
            name: 'Shared Wallet',
            colorIndex: 0,
            createdAt: clock.nowUtc(),
            backup: const BackupStatus(),
          ),
          Account(
            id: 'acc-dup-addr',
            type: AccountType.wallet,
            name: 'Dup Addr Wallet',
            colorIndex: 1,
            createdAt: clock.nowUtc(),
            backup: const BackupStatus(),
          ),
          Account(
            id: 'acc-rename',
            type: AccountType.wallet,
            name: 'Shared Wallet', // 重名
            colorIndex: 2,
            createdAt: clock.nowUtc(),
            vaultItemId: 'backup-item-1', // 指向已存在条目
            backup: const BackupStatus(),
          ),
          Account(
            id: 'acc-new',
            type: AccountType.wallet,
            name: 'New Wallet',
            colorIndex: 3,
            createdAt: clock.nowUtc(),
            vaultItemId: 'backup-item-2', // 指向全新条目
            backup: const BackupStatus(),
          ),
        ],
        addresses: [
          // 关联到 acc-existing-1
          WatchAddress(
            id: 'wa-1',
            accountId: 'acc-existing-1',
            family: ChainFamily.evm,
            address: '0x9999999999999999999999999999999999999999',
            enabledChainIds: {'ethereum'},
          ),
          // 关联到 acc-dup-addr（与本地地址 0x1111... 冲突）
          WatchAddress(
            id: 'wa-2',
            accountId: 'acc-dup-addr',
            family: ChainFamily.evm,
            address: '0x1111111111111111111111111111111111111111',
            enabledChainIds: {'ethereum'},
          ),
          // 关联到 acc-rename（新地址）
          WatchAddress(
            id: 'wa-3',
            accountId: 'acc-rename',
            family: ChainFamily.evm,
            address: '0x2222222222222222222222222222222222222222',
            enabledChainIds: {'ethereum'},
          ),
          // 关联到 acc-new（新地址）
          WatchAddress(
            id: 'wa-4',
            accountId: 'acc-new',
            family: ChainFamily.bitcoin,
            address: 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq',
            enabledChainIds: {'bitcoin'},
          ),
        ],
        vaultItems: [
          BackupVaultItem(
            id: 'backup-item-1',
            name: 'Duplicate Item',
            createdAt: clock.nowUtc(),
            secret: existingSec,
          ),
          BackupVaultItem(
            id: 'backup-item-2',
            name: 'Fresh Item',
            createdAt: clock.nowUtc(),
            secret: newSec,
          ),
        ],
        settings: BackupSettings.of(
          const AppSettings(quote: Quote.cny), // 备份设置是 CNY
        ),
      );

      final pending = PendingRestore(
        payload,
        BackupHeader(
          containerVersion: 1,
          createdAt: clock.nowUtc(),
          appVersion: '1.0.0',
          kdfParams: testKdfParams,
        ),
      );

      final existingVaultCred = PasswordCredential(
        sensitiveString(masterPasswordStr),
      );

      final res = await restoreBackup(
        pending: pending,
        mode: RestoreMode.merge,
        existingVault: existingVaultCred,
      );

      existingVaultCred.password.wipe();
      pending.dispose();

      expect(res, isA<Ok<RestoreReport>>());
      final report = (res as Ok<RestoreReport>).value;
      expect(report.itemsAdded, 1); // 只有 backup-item-2 加入
      expect(report.itemsSkipped, 1); // backup-item-1 跳过
      expect(report.accountsAdded, 2); // acc-rename, acc-new 加入
      expect(report.accountsSkipped, 2); // acc-existing-1, acc-dup-addr 跳过
      expect(report.addressesAdded, 2); // wa-3, wa-4 加入

      // 验证本地设置保留不变（仍为 USD，不是 EUR）
      final localSettings = await settingsRepo.watch().first;
      expect(localSettings.quote, Quote.usd);

      // 验证重名账户改名为 Shared Wallet (2)
      final renamedAcc = await accountRepo.byId('acc-rename');
      expect(renamedAcc, isNotNull);
      expect(renamedAcc!.name, 'Shared Wallet (2)');
      // vaultItemId 映射到本地已有条目 local-item-1
      expect(renamedAcc.vaultItemId, 'local-item-1');

      // 验证新账户的 vaultItemId 映射到新生成的条目 id
      final newAcc = await accountRepo.byId('acc-new');
      expect(newAcc, isNotNull);
      expect(newAcc!.name, 'New Wallet');
      expect(newAcc.vaultItemId, isNot('backup-item-2'));
      expect(newAcc.vaultItemId, isNotNull);
    });
  });

  group('T14: 备份/恢复幂等性与错误重试', () {
    test('中断失败后再用同一个 PendingRestore 重试，结果与一次成功完全相同', () async {
      final clock = FakeClock();
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
      final addressRepo = InMemoryAddressRepository();
      final accountRepo = InMemoryAccountRepository(addresses: addressRepo);
      final credentialRepo = InMemoryCredentialRepository();
      final ids = SequentialIds();

      // 先创建保险库
      final pw = sensitiveString('MasterPassword123');
      final cRes = await vault.create(pw);
      cRes.valueOrNull!.close();
      pw.wipe();

      final restoreBackup = RestoreBackup(
        vault: vault,
        vaultAccess: vaultAccess,
        vaultMetaRepo: vaultMetaRepo,
        accountRepo: accountRepo,
        addressRepo: addressRepo,
        credentialRepo: credentialRepo,
        settings: settingsRepo,
        ids: ids,
        clock: clock,
      );

      final payload = BackupPayload(
        exportedAt: clock.nowUtc(),
        accounts: [
          Account(
            id: 'acc-1',
            type: AccountType.wallet,
            name: 'Wallet 1',
            colorIndex: 0,
            createdAt: clock.nowUtc(),
            vaultItemId: 'item-1',
            backup: const BackupStatus(),
          ),
          Account(
            id: 'acc-2',
            type: AccountType.wallet,
            name: 'Wallet 2',
            colorIndex: 1,
            createdAt: clock.nowUtc(),
            vaultItemId: 'item-2',
            backup: const BackupStatus(),
          ),
        ],
        addresses: [
          WatchAddress(
            id: 'wa-1',
            accountId: 'acc-1',
            family: ChainFamily.evm,
            address: '0x1111111111111111111111111111111111111111',
            enabledChainIds: {'ethereum'},
          ),
          WatchAddress(
            id: 'wa-2',
            accountId: 'acc-2',
            family: ChainFamily.evm,
            address: '0x2222222222222222222222222222222222222222',
            enabledChainIds: {'ethereum'},
          ),
        ],
        vaultItems: [
          BackupVaultItem(
            id: 'item-1',
            name: 'Item 1',
            createdAt: clock.nowUtc(),
            secret: MnemonicSecret(
              mnemonic: sensitiveString(
                'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
              ),
            ),
          ),
          BackupVaultItem(
            id: 'item-2',
            name: 'Item 2',
            createdAt: clock.nowUtc(),
            secret: MnemonicSecret(
              mnemonic: sensitiveString(
                'legal winner thank year wave sausage worth useful legal winner thank yellow',
              ),
            ),
          ),
        ],
        settings: BackupSettings.of(const AppSettings()),
      );

      final pending = PendingRestore(
        payload,
        BackupHeader(
          containerVersion: 1,
          createdAt: clock.nowUtc(),
          appVersion: '1.0.0',
          kdfParams: testKdfParams,
        ),
      );

      // 第一次恢复：注入错误（令 storage 在第二次写入时失败）
      storage.failBeforeStore = true;
      final cred = PasswordCredential(sensitiveString('MasterPassword123'));
      final failRes = await restoreBackup(
        pending: pending,
        mode: RestoreMode.merge,
        existingVault: cred,
      );
      expect(failRes, isA<Err<RestoreReport>>());

      // 恢复正常，重试第二次恢复
      storage.failBeforeStore = false;
      final retryRes = await restoreBackup(
        pending: pending,
        mode: RestoreMode.merge,
        existingVault: cred,
      );
      cred.password.wipe();
      pending.dispose();

      expect(retryRes, isA<Ok<RestoreReport>>());

      // 验证最终状态正确，没有重复账户或条目
      final finalAccounts = await accountRepo.watchAll().first;
      expect(finalAccounts.length, 2);
      final finalAddresses = await addressRepo.watchAll().first;
      expect(finalAddresses.length, 2);
      final finalMetas = await vaultMetaRepo.watchAll().first;
      expect(finalMetas.length, 2);
    });
  });

  group('T15: PendingRestore.dispose 与 toString', () {
    test('dispose 之后再访问抛出 StateError，toString 为 PendingRestore(***)', () {
      final payload = BackupPayload(
        exportedAt: DateTime.utc(2026, 1, 1),
        accounts: const [],
        addresses: const [],
        vaultItems: const [],
        settings: BackupSettings.of(const AppSettings()),
      );
      final pending = PendingRestore(
        payload,
        BackupHeader(
          containerVersion: 1,
          createdAt: DateTime.utc(2026, 1, 1),
          appVersion: '1.0.0',
          kdfParams: testKdfParams,
        ),
      );

      // toString 不包含任何内容
      expect(pending.toString(), 'PendingRestore(***)');

      // 正常访问 preview 和 payload
      expect(pending.preview.accountsCount, 0);
      expect(pending.payload, isNotNull);

      // 释放
      pending.dispose();

      // 释放后再访问抛出 StateError
      expect(() => pending.preview, throwsStateError);
      expect(() => pending.payload, throwsStateError);

      // 再次 dispose 不崩溃
      pending.dispose();
    });
  });
}
