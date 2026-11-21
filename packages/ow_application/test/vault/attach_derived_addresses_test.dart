import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

import '../fakes/fake_repositories.dart';
import '../fakes/fake_services.dart';
import '../fakes/fake_vault.dart';

void main() {
  group('T9: AttachDerivedAddresses', () {
    late InMemoryAddressRepository addressRepo;
    late InMemoryAccountRepository accountRepo;
    late InMemoryVaultMetaRepository vaultMetaRepo;
    late SequentialIds ids;
    late FakeClock clock;
    late AttachDerivedAddresses attachDerivedAddresses;

    const testItemId = 'vault-item-1';

    setUp(() async {
      addressRepo = InMemoryAddressRepository();
      accountRepo = InMemoryAccountRepository(addresses: addressRepo);
      vaultMetaRepo = InMemoryVaultMetaRepository();
      ids = SequentialIds();
      clock = FakeClock();

      attachDerivedAddresses = AttachDerivedAddresses(
        vaultMetaRepo: vaultMetaRepo,
        accountRepo: accountRepo,
        addressRepo: addressRepo,
        ids: ids,
        clock: clock,
      );

      // 预置一个保险库条目元数据
      await vaultMetaRepo.upsert(
        VaultItemMeta(
          id: testItemId,
          name: 'My Mnemonic',
          kind: VaultItemKind.mnemonic,
          fingerprint: 'fp-1',
          hasPassphrase: false,
          createdAt: clock.nowUtc(),
        ),
      );
    });

    test('新建账户：单事务写入、vaultItemId 正确设置、EVM 启用 6 条链', () async {
      final derived = [
        const DerivedAddress(
          family: ChainFamily.evm,
          address: '0x9858EfFD232B4033E47d90003D41EC34EcaEda94',
          scheme: DerivationScheme.evmStandard,
          index: 0,
          alreadyWatched: false,
        ),
        const DerivedAddress(
          family: ChainFamily.bitcoin,
          address: 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq',
          scheme: DerivationScheme.btcNativeSegwit,
          index: 0,
          alreadyWatched: false,
        ),
      ];

      final res = await attachDerivedAddresses(
        itemId: testItemId,
        addresses: derived,
        newAccountName: 'Personal Wallet',
        walletSource: WalletSource.metamask,
      );

      expect(res, isA<Ok<Account>>());
      final account = (res as Ok<Account>).value;
      expect(account.name, 'Personal Wallet');
      expect(account.vaultItemId, testItemId);
      expect(account.type, AccountType.wallet);
      expect(account.walletSource, WalletSource.metamask);

      // 检查地址仓储
      final savedAddresses = await addressRepo.byAccount(account.id);
      expect(savedAddresses.length, 2);

      final evmAddr = savedAddresses.firstWhere(
        (a) => a.family == ChainFamily.evm,
      );
      expect(evmAddr.address, '0x9858EfFD232B4033E47d90003D41EC34EcaEda94');
      expect(evmAddr.scheme, DerivationScheme.evmStandard);
      expect(evmAddr.derivationIndex, 0);
      // EVM 应启用 6 条链 (ethereum, arbitrum, optimism, bsc, polygon, base)
      expect(evmAddr.enabledChainIds.length, 6);
      for (final chain in Chains.ofFamily(ChainFamily.evm)) {
        expect(evmAddr.enabledChainIds.contains(chain.id), isTrue);
      }

      final btcAddr = savedAddresses.firstWhere(
        (a) => a.family == ChainFamily.bitcoin,
      );
      expect(btcAddr.enabledChainIds, {'bitcoin'});
    });

    test('加入已有账户：更新已有账户 vaultItemId 并追加新地址', () async {
      // 预置一个已有账户（最初由 Tron 单地址构成）
      const existingAccId = 'acc-existing';
      final initialAccount = Account(
        id: existingAccId,
        type: AccountType.wallet,
        name: 'Existing Wallet',
        colorIndex: 1,
        createdAt: clock.nowUtc(),
        walletSource: WalletSource.trustWallet,
        vaultItemId: null,
        backup: const BackupStatus(),
      );
      await accountRepo.upsert(initialAccount);
      await addressRepo.upsert(
        WatchAddress(
          id: 'addr-existing',
          accountId: existingAccId,
          family: ChainFamily.tron,
          address: 'TJCnBgPa56CVBe1vjKehhG2xsoknkpWq89',
          enabledChainIds: {'tron'},
        ),
      );

      // 将一个 EVM 派生地址关联到该已有账户
      final derived = [
        const DerivedAddress(
          family: ChainFamily.evm,
          address: '0x9858EfFD232B4033E47d90003D41EC34EcaEda94',
          scheme: DerivationScheme.evmStandard,
          index: 0,
          alreadyWatched: false,
        ),
      ];

      final res = await attachDerivedAddresses(
        itemId: testItemId,
        addresses: derived,
        existingAccountId: existingAccId,
      );

      expect(res, isA<Ok<Account>>());
      final updated = (res as Ok<Account>).value;
      expect(updated.id, existingAccId);
      expect(updated.vaultItemId, testItemId);

      // 验证地址已追加
      final addresses = await addressRepo.byAccount(existingAccId);
      expect(addresses.length, 2);
      expect(addresses.any((a) => a.family == ChainFamily.evm), isTrue);
    });

    test('重复地址冲突返回 DuplicateAddressFailure', () async {
      // 在另一个账户已有相同地址
      const otherAccId = 'acc-other';
      await accountRepo.upsert(
        Account(
          id: otherAccId,
          type: AccountType.wallet,
          name: 'Other Wallet',
          colorIndex: 2,
          createdAt: clock.nowUtc(),
          walletSource: WalletSource.metamask,
          backup: const BackupStatus(),
        ),
      );
      await addressRepo.upsert(
        WatchAddress(
          id: 'addr-other',
          accountId: otherAccId,
          family: ChainFamily.evm,
          address: '0x9858EfFD232B4033E47d90003D41EC34EcaEda94',
          enabledChainIds: {'ethereum'},
        ),
      );

      final derived = [
        const DerivedAddress(
          family: ChainFamily.evm,
          address: '0x9858EfFD232B4033E47d90003D41EC34EcaEda94',
          scheme: DerivationScheme.evmStandard,
          index: 0,
          alreadyWatched: false,
        ),
      ];

      final res = await attachDerivedAddresses(
        itemId: testItemId,
        addresses: derived,
        newAccountName: 'Should Fail',
      );

      expect(res, isA<Err<Account>>());
      final failure = (res as Err<Account>).failure;
      expect(failure, isA<DuplicateAddressFailure>());
      final dup = failure as DuplicateAddressFailure;
      expect(dup.existingAccountName, 'Other Wallet');
      expect(dup.ownerMissing, isFalse);
    });

    test('全部已存在（alreadyWatched）返回 nothing_to_attach', () async {
      final derived = [
        const DerivedAddress(
          family: ChainFamily.evm,
          address: '0x9858EfFD232B4033E47d90003D41EC34EcaEda94',
          scheme: DerivationScheme.evmStandard,
          index: 0,
          alreadyWatched: true,
        ),
      ];

      final res = await attachDerivedAddresses(
        itemId: testItemId,
        addresses: derived,
        newAccountName: 'Should Fail',
      );

      expect(res, isA<Err<Account>>());
      final failure = (res as Err<Account>).failure;
      expect(failure, isA<ValidationFailure>());
      expect((failure as ValidationFailure).detail, 'nothing_to_attach');
    });

    test('参数互斥性与校验错误', () async {
      final derived = [
        const DerivedAddress(
          family: ChainFamily.evm,
          address: '0x9858EfFD232B4033E47d90003D41EC34EcaEda94',
          scheme: DerivationScheme.evmStandard,
          index: 0,
          alreadyWatched: false,
        ),
      ];

      // 两者都未提供
      final res1 = await attachDerivedAddresses(
        itemId: testItemId,
        addresses: derived,
      );
      expect(
        (res1 as Err<Account>).failure,
        const ValidationFailure('account_target_ambiguous'),
      );

      // 两者都提供
      final res2 = await attachDerivedAddresses(
        itemId: testItemId,
        addresses: derived,
        existingAccountId: 'acc1',
        newAccountName: 'acc2',
      );
      expect(
        (res2 as Err<Account>).failure,
        const ValidationFailure('account_target_ambiguous'),
      );

      // addresses 为空
      final res3 = await attachDerivedAddresses(
        itemId: testItemId,
        addresses: const [],
        newAccountName: 'acc',
      );
      expect(
        (res3 as Err<Account>).failure,
        const ValidationFailure('empty_addresses'),
      );

      // itemId 不存在
      final res4 = await attachDerivedAddresses(
        itemId: 'non-existent-id',
        addresses: derived,
        newAccountName: 'acc',
      );
      expect((res4 as Err<Account>).failure, const VaultItemNotFoundFailure());

      // 新账户名称为空或过长
      final res5 = await attachDerivedAddresses(
        itemId: testItemId,
        addresses: derived,
        newAccountName: '   ',
      );
      expect(
        (res5 as Err<Account>).failure,
        const ValidationFailure('name_invalid'),
      );

      // 已有账户不存在
      final res6 = await attachDerivedAddresses(
        itemId: testItemId,
        addresses: derived,
        existingAccountId: 'non-existent-acc',
      );
      expect(
        (res6 as Err<Account>).failure,
        const ValidationFailure('account_not_found'),
      );
    });
  });
}
