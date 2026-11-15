import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:ow_platform/ow_platform.dart';
import 'package:ow_vault/ow_vault.dart';

import 'foundation_providers.dart';

// 保险库与备份相关的 provider。清单见 docs/M4-00_VAULT_USECASES_SPEC.md 第 6 节。

/// 应用版本号。M6-05 会接入 package_info_plus 读取真实版本。
final appVersionProvider = Provider<String>((ref) => '1.0.0');

/// 占位实现：在 M0-11 接入真实原生 KeyStore/Keychain 前返回不支持。
final class UnsupportedHardwareKeyStore implements HardwareKeyStore {
  const UnsupportedHardwareKeyStore();

  @override
  Future<Result<Uint8List>> wrap(String keyAlias, Uint8List plaintext) async =>
      const Err(UnsupportedFailure('硬件密钥不可用'));

  @override
  Future<Result<Uint8List>> unwrap(
    String keyAlias,
    Uint8List wrapped, {
    required String reason,
  }) async => const Err(UnsupportedFailure('硬件密钥不可用'));

  @override
  Future<void> delete(String keyAlias) async {}
}

/// 基于 [SecretStore] 的交易所凭据存储。
final class SecretStoreCredentialRepository implements CredentialRepository {
  SecretStoreCredentialRepository(this._secretStore);

  final SecretStore _secretStore;
  static const _prefix = 'ow.cred.';

  @override
  Future<void> save(String accountId, ExchangeCredentials c) async {
    final map = {
      'apiKey': c.apiKey.use((b) => utf8.decode(b)),
      'apiSecret': c.apiSecret.use((b) => utf8.decode(b)),
      if (c.passphrase != null)
        'passphrase': c.passphrase!.use((b) => utf8.decode(b)),
    };
    await _secretStore.write('$_prefix$accountId', jsonEncode(map));
  }

  @override
  Future<ExchangeCredentials?> load(String accountId) async {
    final raw = await _secretStore.read('$_prefix$accountId');
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final apiKey = map['apiKey'] as String?;
      final apiSecret = map['apiSecret'] as String?;
      final passphrase = map['passphrase'] as String?;
      if (apiKey == null || apiSecret == null) return null;
      return ExchangeCredentials(
        apiKey: Sensitive(Uint8List.fromList(utf8.encode(apiKey))),
        apiSecret: Sensitive(Uint8List.fromList(utf8.encode(apiSecret))),
        passphrase: passphrase != null
            ? Sensitive(Uint8List.fromList(utf8.encode(passphrase)))
            : null,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> delete(String accountId) async {
    await _secretStore.delete('$_prefix$accountId');
  }
}

final vaultCryptoProvider = FutureProvider<VaultCrypto>((ref) async {
  return SodiumVaultCrypto.load();
});

final vaultStorageProvider = Provider<VaultStorage>((ref) {
  return FileVaultStorage();
});

final hardwareKeyStoreProvider = Provider<HardwareKeyStore>((ref) {
  return DeviceHardwareKeyStore();
});

final vaultProvider = FutureProvider<Vault>((ref) async {
  final crypto = await ref.watch(vaultCryptoProvider.future);
  final storage = ref.watch(vaultStorageProvider);
  return Vault(
    crypto: crypto,
    storage: storage,
    defaultParams: KdfParams.vaultDefault,
  );
});

final vaultPasswordLimiterProvider = Provider<AttemptLimiter>((ref) {
  return AttemptLimiter(
    store: ref.watch(secretStoreProvider),
    clock: ref.watch(clockProvider),
    keyPrefix: 'ow.vault.unlock',
  );
});

final vaultAccessProvider = FutureProvider<VaultAccess>((ref) async {
  final vault = await ref.watch(vaultProvider.future);
  return VaultAccess(
    vault: vault,
    hardwareKeyStore: ref.watch(hardwareKeyStoreProvider),
    secretStore: ref.watch(secretStoreProvider),
    capabilities: ref.watch(platformCapabilitiesProvider),
    settings: ref.watch(settingsRepositoryProvider),
    passwordLimiter: ref.watch(vaultPasswordLimiterProvider),
  );
});

final createVaultProvider = FutureProvider<CreateVault>((ref) async {
  final vault = await ref.watch(vaultProvider.future);
  final access = await ref.watch(vaultAccessProvider.future);
  return CreateVault(
    vault: vault,
    vaultAccess: access,
    capabilities: ref.watch(platformCapabilitiesProvider),
    settings: ref.watch(settingsRepositoryProvider),
    clock: ref.watch(clockProvider),
  );
});

final importVaultItemProvider = FutureProvider<ImportVaultItem>((ref) async {
  final access = await ref.watch(vaultAccessProvider.future);
  return ImportVaultItem(
    vaultAccess: access,
    vaultMetaRepo: ref.watch(vaultMetaRepositoryProvider),
    accountRepo: ref.watch(accountRepositoryProvider),
    settings: ref.watch(settingsRepositoryProvider),
    ids: ref.watch(idGeneratorProvider),
    clock: ref.watch(clockProvider),
  );
});

final revealVaultItemProvider = FutureProvider<RevealVaultItem>((ref) async {
  final access = await ref.watch(vaultAccessProvider.future);
  return RevealVaultItem(vaultAccess: access);
});

final deleteVaultItemProvider = FutureProvider<DeleteVaultItem>((ref) async {
  final access = await ref.watch(vaultAccessProvider.future);
  return DeleteVaultItem(
    vaultAccess: access,
    vaultMetaRepo: ref.watch(vaultMetaRepositoryProvider),
    accountRepo: ref.watch(accountRepositoryProvider),
    settings: ref.watch(settingsRepositoryProvider),
    clock: ref.watch(clockProvider),
  );
});

final deriveAddressesProvider = FutureProvider<DeriveAddresses>((ref) async {
  final access = await ref.watch(vaultAccessProvider.future);
  return DeriveAddresses(
    vaultAccess: access,
    addressRepo: ref.watch(addressRepositoryProvider),
  );
});

final attachDerivedAddressesProvider = Provider<AttachDerivedAddresses>((ref) {
  return AttachDerivedAddresses(
    vaultMetaRepo: ref.watch(vaultMetaRepositoryProvider),
    accountRepo: ref.watch(accountRepositoryProvider),
    addressRepo: ref.watch(addressRepositoryProvider),
    ids: ref.watch(idGeneratorProvider),
    clock: ref.watch(clockProvider),
  );
});

final changeMasterPasswordProvider = FutureProvider<ChangeMasterPassword>((
  ref,
) async {
  final access = await ref.watch(vaultAccessProvider.future);
  return ChangeMasterPassword(
    vaultAccess: access,
    settings: ref.watch(settingsRepositoryProvider),
    clock: ref.watch(clockProvider),
  );
});

final setVaultBiometricsProvider = FutureProvider<SetVaultBiometrics>((
  ref,
) async {
  final access = await ref.watch(vaultAccessProvider.future);
  return SetVaultBiometrics(
    vaultAccess: access,
    capabilities: ref.watch(platformCapabilitiesProvider),
    settings: ref.watch(settingsRepositoryProvider),
  );
});

final exportBackupProvider = FutureProvider<ExportBackup>((ref) async {
  final access = await ref.watch(vaultAccessProvider.future);
  final crypto = await ref.watch(vaultCryptoProvider.future);
  return ExportBackup(
    vaultAccess: access,
    vaultMetaRepo: ref.watch(vaultMetaRepositoryProvider),
    accountRepo: ref.watch(accountRepositoryProvider),
    addressRepo: ref.watch(addressRepositoryProvider),
    credentialRepo: ref.watch(credentialRepositoryProvider),
    settings: ref.watch(settingsRepositoryProvider),
    crypto: crypto,
    clock: ref.watch(clockProvider),
    appVersion: ref.watch(appVersionProvider),
  );
});

final confirmBackupSavedProvider = Provider<ConfirmBackupSaved>((ref) {
  return ConfirmBackupSaved(
    settings: ref.watch(settingsRepositoryProvider),
    clock: ref.watch(clockProvider),
  );
});

final openBackupProvider = FutureProvider<OpenBackup>((ref) async {
  final crypto = await ref.watch(vaultCryptoProvider.future);
  return OpenBackup(crypto: crypto);
});

final restoreBackupProvider = FutureProvider<RestoreBackup>((ref) async {
  final vault = await ref.watch(vaultProvider.future);
  final access = await ref.watch(vaultAccessProvider.future);
  return RestoreBackup(
    vault: vault,
    vaultAccess: access,
    vaultMetaRepo: ref.watch(vaultMetaRepositoryProvider),
    accountRepo: ref.watch(accountRepositoryProvider),
    addressRepo: ref.watch(addressRepositoryProvider),
    credentialRepo: ref.watch(credentialRepositoryProvider),
    settings: ref.watch(settingsRepositoryProvider),
    ids: ref.watch(idGeneratorProvider),
    clock: ref.watch(clockProvider),
  );
});

final watchVaultItemsProvider = Provider<WatchVaultItems>((ref) {
  return WatchVaultItems(
    vaultMetaRepo: ref.watch(vaultMetaRepositoryProvider),
    accountRepo: ref.watch(accountRepositoryProvider),
  );
});

final vaultItemsProvider = StreamProvider<List<VaultItemSummary>>((ref) {
  return ref.watch(watchVaultItemsProvider)();
});
