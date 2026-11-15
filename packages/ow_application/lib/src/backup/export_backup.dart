import 'dart:convert';
import 'dart:typed_data';

import 'package:ow_domain/ow_domain.dart';
import 'package:ow_vault/ow_vault.dart';

import '../vault/vault_access.dart';
import '../vault/vault_credential.dart';

/// 导出的备份摘要（不含任何密钥明文）。
final class BackupSummary {
  const BackupSummary({
    required this.accountsCount,
    required this.addressesCount,
    required this.vaultItemsCount,
    required this.hasCredentials,
  });

  final int accountsCount;
  final int addressesCount;
  final int vaultItemsCount;
  final bool hasCredentials;

  @override
  bool operator ==(Object other) =>
      other is BackupSummary &&
      other.accountsCount == accountsCount &&
      other.addressesCount == addressesCount &&
      other.vaultItemsCount == vaultItemsCount &&
      other.hasCredentials == hasCredentials;

  @override
  int get hashCode => Object.hash(
    accountsCount,
    addressesCount,
    vaultItemsCount,
    hasCredentials,
  );

  @override
  String toString() =>
      'BackupSummary(acc: $accountsCount, addr: $addressesCount, items: $vaultItemsCount, cred: $hasCredentials)';
}

/// 导出的备份结果封装。
final class ExportedBackup {
  const ExportedBackup({
    required this.bytes,
    required this.suggestedFileName,
    required this.summary,
  });

  final Uint8List bytes;
  final String suggestedFileName;
  final BackupSummary summary;
}

/// 导出加密备份（规格 5.1 节）。
final class ExportBackup {
  ExportBackup({
    required this.vaultAccess,
    required this.vaultMetaRepo,
    required this.accountRepo,
    required this.addressRepo,
    required this.credentialRepo,
    required this.settings,
    required this.crypto,
    required this.clock,
    required this.appVersion,
  });

  final VaultAccess vaultAccess;
  final VaultMetaRepository vaultMetaRepo;
  final AccountRepository accountRepo;
  final AddressRepository addressRepo;
  final CredentialRepository credentialRepo;
  final SettingsRepository settings;
  final VaultCrypto crypto;
  final Clock clock;
  final String appVersion;

  Future<Result<ExportedBackup>> call({
    required PasswordCredential masterCredential,
    required Sensitive backupPassword,
    required bool includeExchangeCredentials,
    KdfParams? kdfParams,
  }) async {
    // 校验备份密码长度（Unicode 码点 >= 10）
    final pw = backupPassword.use((bytes) {
      try {
        return utf8.decode(bytes).trim();
      } catch (_) {
        return '';
      }
    });
    if (pw.runes.length < 10) {
      return const Err(ValidationFailure('backup_password_too_short'));
    }

    return vaultAccess.withSession(masterCredential, (session) async {
      final metas = await vaultMetaRepo.watchAll().first;
      final backupVaultItems = <BackupVaultItem>[];
      List<BackupExchangeCredential>? exchangeCredentials;

      try {
        // 逐条读取保险库条目
        for (final m in metas) {
          final readRes = await session.readItem(m.id);
          if (readRes case Err(:final failure)) {
            // 元数据里有、保险库里读不到的条目：整次导出失败
            if (failure is VaultItemNotFoundFailure) {
              return Err(VaultItemNotFoundFailure(m.id));
            }
            return Err(failure);
          }
          backupVaultItems.add(
            BackupVaultItem(
              id: m.id,
              name: m.name,
              createdAt: m.createdAt,
              secret: readRes.valueOrNull!,
            ),
          );
        }

        final accounts = await accountRepo.watchAll().first;
        final addresses = await addressRepo.watchAll().first;
        final appSettings = await settings.watch().first;

        if (includeExchangeCredentials) {
          exchangeCredentials = [];
          for (final a in accounts) {
            if (a.type == AccountType.exchange) {
              final creds = await credentialRepo.load(a.id);
              if (creds != null) {
                exchangeCredentials.add(
                  BackupExchangeCredential(accountId: a.id, credentials: creds),
                );
              }
            }
          }
        }

        final now = clock.nowUtc();
        final payload = BackupPayload(
          exportedAt: now,
          accounts: accounts,
          addresses: addresses,
          vaultItems: backupVaultItems,
          settings: BackupSettings.of(appSettings),
          exchangeCredentials: exchangeCredentials,
        );

        final bytes = await BackupCodec.encode(
          payload: payload,
          password: backupPassword,
          crypto: crypto,
          params: kdfParams ?? KdfParams.backupDefault,
          createdAt: now,
          appVersion: appVersion,
        );

        final local = now.toLocal();
        final ymd = '${local.year}${_two(local.month)}${_two(local.day)}';
        final hm = '${_two(local.hour)}${_two(local.minute)}';
        final fileName = 'OneWallet-备份-$ymd-$hm.owbak';

        final summary = BackupSummary(
          accountsCount: accounts.length,
          addressesCount: addresses.length,
          vaultItemsCount: backupVaultItems.length,
          hasCredentials:
              exchangeCredentials != null && exchangeCredentials.isNotEmpty,
        );

        return Ok(
          ExportedBackup(
            bytes: bytes,
            suggestedFileName: fileName,
            summary: summary,
          ),
        );
      } finally {
        for (final item in backupVaultItems) {
          item.wipe();
        }
        if (exchangeCredentials != null) {
          for (final c in exchangeCredentials) {
            c.wipe();
          }
        }
      }
    }, allowBiometric: false);
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
}
