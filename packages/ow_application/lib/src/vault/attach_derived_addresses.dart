import 'package:ow_domain/ow_domain.dart';

import 'derive_addresses.dart';

/// 关联派生地址到账户（规格 4.6 节）。
final class AttachDerivedAddresses {
  AttachDerivedAddresses({
    required this.vaultMetaRepo,
    required this.accountRepo,
    required this.addressRepo,
    required this.ids,
    required this.clock,
  });

  final VaultMetaRepository vaultMetaRepo;
  final AccountRepository accountRepo;
  final AddressRepository addressRepo;
  final IdGenerator ids;
  final Clock clock;

  static const int _maxAccountNameLength = 30;
  static const int _accountColorCount = 8;

  Future<Result<Account>> call({
    required String itemId,
    required List<DerivedAddress> addresses,
    String? existingAccountId,
    String? newAccountName,
    WalletSource? walletSource,
  }) async {
    // 校验参数互斥性
    if ((existingAccountId == null) == (newAccountName == null)) {
      return const Err(ValidationFailure('account_target_ambiguous'));
    }

    if (addresses.isEmpty) {
      return const Err(ValidationFailure('empty_addresses'));
    }

    // 1. itemId 必须存在于元数据中
    final allMeta = await vaultMetaRepo.watchAll().first;
    final meta = allMeta.where((m) => m.id == itemId).firstOrNull;
    if (meta == null) {
      return const Err(VaultItemNotFoundFailure());
    }

    // 2. 过滤已观察地址
    final toAttach = addresses.where((a) => !a.alreadyWatched).toList();
    if (toAttach.isEmpty) {
      return const Err(ValidationFailure('nothing_to_attach'));
    }

    // 查重：若有地址已被添加，返回 DuplicateAddressFailure
    for (final da in toAttach) {
      final existing = await addressRepo.find(da.family, da.address);
      if (existing != null) {
        final owner = await accountRepo.byId(existing.accountId);
        return Err(
          DuplicateAddressFailure(
            shortAddress: AddressCodec.shorten(da.address),
            existingAccountName: owner?.name,
            ownerMissing: owner == null,
          ),
        );
      }
    }

    final now = clock.nowUtc();

    // 3. 新建账户分支
    if (newAccountName != null) {
      final trimmed = newAccountName.trim();
      final len = trimmed.runes.length;
      if (len == 0 || len > _maxAccountNameLength) {
        return const Err(ValidationFailure('name_invalid'));
      }

      final existingAccounts = await accountRepo.watchAll().first;
      final colorIndex = existingAccounts.length % _accountColorCount;
      final accountId = ids.newId();

      final account = Account(
        id: accountId,
        type: AccountType.wallet,
        name: trimmed,
        colorIndex: colorIndex,
        createdAt: now,
        walletSource: walletSource,
        vaultItemId: itemId,
        backup: const BackupStatus(),
      );

      final watchAddresses = [
        for (final da in toAttach)
          WatchAddress(
            id: ids.newId(),
            accountId: accountId,
            family: da.family,
            address: da.address,
            enabledChainIds: {for (final c in Chains.ofFamily(da.family)) c.id},
            scheme: da.scheme,
            derivationIndex: da.index,
          ),
      ];

      await accountRepo.insertWithAddresses(account, watchAddresses);
      return Ok(account);
    }

    // 4. 已有账户分支
    final account = await accountRepo.byId(existingAccountId!);
    if (account == null) {
      return const Err(ValidationFailure('account_not_found'));
    }
    if (account.type != AccountType.wallet) {
      return const Err(ValidationFailure('not_a_wallet_account'));
    }

    for (final da in toAttach) {
      final wa = WatchAddress(
        id: ids.newId(),
        accountId: account.id,
        family: da.family,
        address: da.address,
        enabledChainIds: {for (final c in Chains.ofFamily(da.family)) c.id},
        scheme: da.scheme,
        derivationIndex: da.index,
      );
      await addressRepo.upsert(wa);
    }

    final updatedAccount = account.copyWith(vaultItemId: itemId);
    await accountRepo.upsert(updatedAccount);
    return Ok(updatedAccount);
  }
}
