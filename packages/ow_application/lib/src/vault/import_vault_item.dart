import 'package:ow_domain/ow_domain.dart';
import 'package:ow_vault/ow_vault.dart';
import 'package:ow_vault/private_key_format.dart';

import 'mnemonic_input.dart';
import 'vault_access.dart';
import 'vault_credential.dart';

/// 导入密钥的输入数据。
sealed class VaultItemInput {
  const VaultItemInput();
}

/// 助记词输入。
final class MnemonicInput extends VaultItemInput {
  const MnemonicInput({required this.mnemonic, this.passphrase});

  /// 助记词原文（所有权归调用方）。
  final Sensitive mnemonic;

  /// 可选附加密码（所有权归调用方）。
  final Sensitive? passphrase;
}

/// 私钥输入。
final class PrivateKeyInput extends VaultItemInput {
  const PrivateKeyInput({required this.family, required this.key});

  final ChainFamily family;

  /// 私钥文本（所有权归调用方）。
  final Sensitive key;
}

/// 导入成功的结果（仅包含非敏感信息）。
final class ImportedItem {
  const ImportedItem({
    required this.id,
    required this.fingerprint,
    required this.kind,
  });

  final String id;
  final String fingerprint;
  final VaultItemKind kind;

  @override
  bool operator ==(Object other) =>
      other is ImportedItem &&
      other.id == id &&
      other.fingerprint == fingerprint &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(id, fingerprint, kind);

  @override
  String toString() => 'ImportedItem($id, ${kind.name})';
}

/// 导入密钥条目（规格 4.2 节）。
final class ImportVaultItem {
  ImportVaultItem({
    required this.vaultAccess,
    required this.vaultMetaRepo,
    required this.accountRepo,
    required this.settings,
    required this.ids,
    required this.clock,
  });

  final VaultAccess vaultAccess;
  final VaultMetaRepository vaultMetaRepo;
  final AccountRepository accountRepo;
  final SettingsRepository settings;
  final IdGenerator ids;
  final Clock clock;

  Future<Result<ImportedItem>> call({
    required VaultCredential credential,
    required String name,
    required VaultItemInput input,
    String? linkToAccountId,
  }) async {
    // 1. 校验名称与关联账户
    final trimmedName = name.trim();
    if (trimmedName.isEmpty || trimmedName.runes.length > 30) {
      return const Err(ValidationFailure('name_invalid'));
    }

    if (linkToAccountId != null) {
      final account = await accountRepo.byId(linkToAccountId);
      if (account == null || account.type != AccountType.wallet) {
        return const Err(ValidationFailure('invalid_account'));
      }
    }

    // 2. 打开会话之前进行格式校验与规范化
    final VaultItemSecret secret;
    final int? wordCount;
    final ChainFamily? itemFamily;
    final bool hasPassphrase;

    switch (input) {
      case MnemonicInput(:final mnemonic, :final passphrase):
        final normRes = normalizeMnemonic(mnemonic);
        if (normRes case Err(:final failure)) {
          return Err(failure);
        }
        final normMnemonic = normRes.valueOrNull!;
        secret = MnemonicSecret(mnemonic: normMnemonic, passphrase: passphrase);
        wordCount = normMnemonic.use(
          (b) => String.fromCharCodes(b).split(' ').length,
        );
        itemFamily = null;
        hasPassphrase = passphrase != null;
      case PrivateKeyInput(family: final fam, key: final key):
        final normRes = PrivateKeyFormat.normalize(fam, key);
        if (normRes case Err(:final failure)) {
          return Err(failure);
        }
        secret = PrivateKeySecret(family: fam, key: normRes.valueOrNull!);
        wordCount = null;
        itemFamily = fam;
        hasPassphrase = false;
    }

    try {
      // 3. 打开会话
      return await vaultAccess.withSession(credential, (session) async {
        // 4. 计算指纹并查重
        final fingerprint = session.fingerprintOf(secret);
        final existing = await vaultMetaRepo.byFingerprint(fingerprint);
        if (existing != null) {
          return Err(ValidationFailure(existing.id));
        }

        // 5. 新建 id 并写入保险库
        final id = ids.newId();
        final addRes = await session.addItem(id, secret);
        if (addRes case Err(:final failure)) {
          return Err(failure);
        }

        // 6. 写元数据，失败时补偿
        final now = clock.nowUtc();
        final meta = VaultItemMeta(
          id: id,
          name: trimmedName,
          kind: secret.kind,
          wordCount: wordCount,
          family: itemFamily,
          hasPassphrase: hasPassphrase,
          fingerprint: fingerprint,
          createdAt: now,
        );

        try {
          await vaultMetaRepo.upsert(meta);
        } catch (_) {
          // 补偿：删掉刚加的条目
          try {
            await session.deleteItem(id);
            return const Err(UnknownFailure('vault_meta_write_failed'));
          } catch (_) {
            return const Err(
              UnknownFailure('vault_meta_write_failed:compensation_failed'),
            );
          }
        }

        // 7. 关联账户
        if (linkToAccountId != null) {
          final acc = await accountRepo.byId(linkToAccountId);
          if (acc != null) {
            await accountRepo.upsert(acc.copyWith(vaultItemId: id));
          }
        }

        // 8. 设 vaultChangedAt
        await settings.update((s) => s.copyWith(vaultChangedAt: now));

        return Ok(
          ImportedItem(id: id, fingerprint: fingerprint, kind: secret.kind),
        );
      }, allowBiometric: true);
    } finally {
      // 本用例内部规范化产生的明文在 finally 中清零
      switch (secret) {
        case MnemonicSecret(:final mnemonic):
          mnemonic.wipe();
        case PrivateKeySecret(:final key):
          key.wipe();
      }
    }
  }
}
