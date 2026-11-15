import 'dart:convert';

import 'package:ow_domain/ow_domain.dart';
import 'package:ow_vault/ow_vault.dart';

import '../vault/vault_access.dart';
import '../vault/vault_credential.dart';
import 'open_backup.dart';

/// 恢复模式（规格 5.4 节）。
enum RestoreMode {
  /// 首次引导：要求本地没有任何数据。
  fresh,

  /// 设置中的"导入备份"：与本地数据安全合并。
  merge,
}

/// 恢复报告。
final class RestoreReport {
  const RestoreReport({
    required this.accountsAdded,
    required this.accountsSkipped,
    required this.addressesAdded,
    required this.addressesSkipped,
    required this.itemsAdded,
    required this.itemsSkipped,
    required this.credentialsAdded,
    required this.unreadable,
  });

  final int accountsAdded;
  final int accountsSkipped;
  final int addressesAdded;
  final int addressesSkipped;
  final int itemsAdded;
  final int itemsSkipped;
  final int credentialsAdded;
  final List<BackupSkipped> unreadable;

  @override
  bool operator ==(Object other) =>
      other is RestoreReport &&
      other.accountsAdded == accountsAdded &&
      other.accountsSkipped == accountsSkipped &&
      other.addressesAdded == addressesAdded &&
      other.addressesSkipped == addressesSkipped &&
      other.itemsAdded == itemsAdded &&
      other.itemsSkipped == itemsSkipped &&
      other.credentialsAdded == credentialsAdded &&
      _listEquals(other.unreadable, unreadable);

  @override
  int get hashCode => Object.hash(
    accountsAdded,
    accountsSkipped,
    addressesAdded,
    addressesSkipped,
    itemsAdded,
    itemsSkipped,
    credentialsAdded,
    Object.hashAll(unreadable),
  );

  @override
  String toString() =>
      'RestoreReport(accounts: +$accountsAdded/-$accountsSkipped, addresses: +$addressesAdded/-$addressesSkipped, items: +$itemsAdded/-$itemsSkipped, credentials: +$credentialsAdded, unreadable: ${unreadable.length})';
}

bool _listEquals<E>(List<E> a, List<E> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// 恢复备份（规格 5.4 节）。
final class RestoreBackup {
  RestoreBackup({
    required this.vault,
    required this.vaultAccess,
    required this.vaultMetaRepo,
    required this.accountRepo,
    required this.addressRepo,
    required this.credentialRepo,
    required this.settings,
    required this.ids,
    required this.clock,
  });

  final Vault vault;
  final VaultAccess vaultAccess;
  final VaultMetaRepository vaultMetaRepo;
  final AccountRepository accountRepo;
  final AddressRepository addressRepo;
  final CredentialRepository credentialRepo;
  final SettingsRepository settings;
  final IdGenerator ids;
  final Clock clock;

  Future<Result<RestoreReport>> call({
    required PendingRestore pending,
    required RestoreMode mode,
    Sensitive? newMasterPassword,
    PasswordCredential? existingVault,
  }) async {
    final payload = pending.payload;
    final vaultExists = await vaultAccess.exists();
    final localAccounts = await accountRepo.watchAll().first;

    // 前置条件检查
    switch (mode) {
      case RestoreMode.fresh:
        if (localAccounts.isNotEmpty || vaultExists) {
          return const Err(ValidationFailure('restore_target_not_empty'));
        }
        if (newMasterPassword == null) {
          return const Err(ValidationFailure('master_password_required'));
        }
        final pw = newMasterPassword.use((b) => utf8.decode(b).trim());
        if (pw.runes.length < 10) {
          return const Err(ValidationFailure('master_password_too_short'));
        }
      case RestoreMode.merge:
        if (vaultExists && existingVault == null) {
          return const Err(
            ValidationFailure('existing_vault_credential_required'),
          );
        }
        if (!vaultExists && payload.vaultItems.isNotEmpty) {
          if (newMasterPassword == null) {
            return const Err(ValidationFailure('master_password_required'));
          }
          final pw = newMasterPassword.use((b) => utf8.decode(b).trim());
          if (pw.runes.length < 10) {
            return const Err(ValidationFailure('master_password_too_short'));
          }
        }
    }

    var itemsAdded = 0;
    var itemsSkipped = 0;
    final itemMapping = <String, String>{};

    // 1. 恢复保险库条目
    if (payload.vaultItems.isNotEmpty || !vaultExists) {
      if (!vaultExists) {
        final createRes = await vault.create(newMasterPassword!);
        if (createRes case Err(:final failure)) {
          return Err(failure);
        }
        createRes.valueOrNull!.close();
      }

      final cred = existingVault ?? PasswordCredential(newMasterPassword!);
      final sessionRes = await vaultAccess.withSession<void>(cred, (
        session,
      ) async {
        for (final item in payload.vaultItems) {
          final fingerprint = session.fingerprintOf(item.secret);
          final existing = await vaultMetaRepo.byFingerprint(fingerprint);
          if (existing != null) {
            itemsSkipped++;
            itemMapping[item.id] = existing.id;
          } else {
            final newId = ids.newId();
            final addRes = await session.addItem(newId, item.secret);
            if (addRes case Err(:final failure)) {
              return Err<void>(failure);
            }

            final int? wordCount;
            final ChainFamily? itemFamily;
            final bool hasPassphrase;
            switch (item.secret) {
              case MnemonicSecret(:final mnemonic, :final passphrase):
                wordCount = mnemonic.use(
                  (b) => String.fromCharCodes(b).split(' ').length,
                );
                itemFamily = null;
                hasPassphrase = passphrase != null;
              case PrivateKeySecret(family: final fam):
                wordCount = null;
                itemFamily = fam;
                hasPassphrase = false;
            }

            final meta = VaultItemMeta(
              id: newId,
              name: item.name,
              kind: item.kind,
              wordCount: wordCount,
              family: itemFamily,
              hasPassphrase: hasPassphrase,
              fingerprint: fingerprint,
              createdAt: item.createdAt,
            );

            try {
              await vaultMetaRepo.upsert(meta);
            } catch (_) {
              // 补偿删除
              await session.deleteItem(newId);
              rethrow;
            }

            itemMapping[item.id] = newId;
            itemsAdded++;
          }
        }
        return const Ok(null);
      }, allowBiometric: false);

      if (sessionRes case Err(:final failure)) {
        return Err(failure);
      }
    }

    // 2. 恢复账户与地址
    var accountsAdded = 0;
    var accountsSkipped = 0;
    var addressesAdded = 0;
    var addressesSkipped = 0;
    final newAccountIds = <String>{};

    for (final acc in payload.accounts) {
      final accAddresses = [
        for (final wa in payload.addresses)
          if (wa.accountId == acc.id) wa,
      ];

      final existingAccount = await accountRepo.byId(acc.id);
      if (existingAccount != null) {
        // 本地已有相同 id：跳过整个账户及地址
        accountsSkipped++;
        addressesSkipped += accAddresses.length;
        continue;
      }

      // 检查其每个地址
      final remainingAddresses = <WatchAddress>[];
      for (final wa in accAddresses) {
        final existingAddr = await addressRepo.find(wa.family, wa.address);
        if (existingAddr != null) {
          addressesSkipped++;
        } else {
          remainingAddresses.add(wa);
        }
      }

      if (acc.type == AccountType.wallet && remainingAddresses.isEmpty) {
        // 钱包账户剩下的地址为空 -> 跳过整个账户
        accountsSkipped++;
        continue;
      }

      // 名称防重名加后缀 (2), (3)...
      final currentAccounts = await accountRepo.watchAll().first;
      final existingNames = currentAccounts.map((a) => a.name).toSet();
      var name = acc.name;
      var counter = 2;
      while (existingNames.contains(name)) {
        name = '${acc.name} ($counter)';
        counter++;
      }

      final mappedVaultId = acc.vaultItemId != null
          ? itemMapping[acc.vaultItemId]
          : null;

      final newAcc = Account(
        id: acc.id,
        type: acc.type,
        name: name,
        colorIndex: acc.colorIndex,
        createdAt: acc.createdAt,
        note: acc.note,
        walletSource: acc.walletSource,
        exchange: acc.exchange,
        vaultItemId: mappedVaultId,
        backup: acc.backup,
      );

      await accountRepo.insertWithAddresses(newAcc, remainingAddresses);
      accountsAdded++;
      addressesAdded += remainingAddresses.length;
      newAccountIds.add(acc.id);
    }

    // 3. 交易所凭据：只为新加入的交易所账户写入
    var credentialsAdded = 0;
    if (payload.exchangeCredentials != null) {
      for (final c in payload.exchangeCredentials!) {
        if (newAccountIds.contains(c.accountId)) {
          await credentialRepo.save(c.accountId, c.credentials);
          credentialsAdded++;
        }
      }
    }

    // 4. 设置迁移：只在 fresh 模式下覆盖
    if (mode == RestoreMode.fresh) {
      await settings.update((s) => payload.settings.applyTo(s));
    }

    // 5. 设 vaultChangedAt
    final now = clock.nowUtc();
    if (itemsAdded > 0) {
      await settings.update((s) => s.copyWith(vaultChangedAt: now));
    }

    return Ok(
      RestoreReport(
        accountsAdded: accountsAdded,
        accountsSkipped: accountsSkipped,
        addressesAdded: addressesAdded,
        addressesSkipped: addressesSkipped,
        itemsAdded: itemsAdded,
        itemsSkipped: itemsSkipped,
        credentialsAdded: credentialsAdded,
        unreadable: payload.skipped,
      ),
    );
  }
}
