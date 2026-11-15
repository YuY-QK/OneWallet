import 'package:ow_domain/ow_domain.dart';
import 'package:ow_vault/ow_vault.dart';

import 'vault_access.dart';
import 'vault_credential.dart';

/// 查看保险库条目明文（规格 4.3 节）。
///
/// **警告**：返回的明文 [VaultItemSecret] 所有权转给调用方，
/// **调用方用完必须调用其 `wipe()` 清零**！
final class RevealVaultItem {
  RevealVaultItem({required this.vaultAccess});

  final VaultAccess vaultAccess;

  /// 解密并读取条目 [itemId] 的明文内容。
  ///
  /// 允许生物识别。本用例不缓存任何内容，每次调用均重新走 [VaultAccess.withSession]。
  /// 成功返回的 [VaultItemSecret] 归调用方所有，用完必须 wipe()。
  Future<Result<VaultItemSecret>> call({
    required String itemId,
    required VaultCredential credential,
  }) async {
    return vaultAccess.withSession(
      credential,
      (session) => session.readItem(itemId),
      allowBiometric: true,
    );
  }
}
