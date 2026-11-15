import 'package:ow_domain/ow_domain.dart';

import 'vault_access.dart';
import 'vault_credential.dart';

/// 删除保险库条目（规格 4.4 节）。
final class DeleteVaultItem {
  DeleteVaultItem({
    required this.vaultAccess,
    required this.vaultMetaRepo,
    required this.accountRepo,
    required this.settings,
    required this.clock,
  });

  final VaultAccess vaultAccess;
  final VaultMetaRepository vaultMetaRepo;
  final AccountRepository accountRepo;
  final SettingsRepository settings;
  final Clock clock;

  /// 删除条目 [itemId]。
  ///
  /// 只接受主密码 [credential]（PRD R32）。
  /// 幂等：若保险库中已不存在该条目但元数据仍在，视为成功并继续清理元数据和关联。
  Future<Result<void>> call({
    required String itemId,
    required PasswordCredential credential,
  }) async {
    return vaultAccess.withSession(credential, (session) async {
      // 1. 删除保险库文件中的条目
      final delRes = await session.deleteItem(itemId);
      if (delRes case Err(:final failure)) {
        // 保险库已无此条目但元数据还在时视为成功（幂等）
        if (failure is! VaultItemNotFoundFailure) {
          return Err(failure);
        }
      }

      // 2. 删除元数据
      await vaultMetaRepo.delete(itemId);

      // 3. 所有关联此条目的账户将 vaultItemId 置为 null
      final accounts = await accountRepo.watchAll().first;
      for (final a in accounts) {
        if (a.vaultItemId == itemId) {
          await accountRepo.upsert(a.copyWith(vaultItemId: null));
        }
      }

      // 4. 更新 vaultChangedAt
      await settings.update((s) => s.copyWith(vaultChangedAt: clock.nowUtc()));

      return const Ok(null);
    }, allowBiometric: false);
  }
}
