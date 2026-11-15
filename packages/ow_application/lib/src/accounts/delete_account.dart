import 'package:ow_domain/ow_domain.dart';

/// 删除账户（P03、P08、R6）。
///
/// 先清理可能存在的交易所 API 凭据（由 [CredentialRepository.delete] 保障），
/// 再级联删除其地址、持仓与同步记录（由 [AccountRepository.delete] 保障）。
/// 该顺序确保凭据删除失败时账户不会被先行删除，避免遗留无法清除的凭据。
/// 操作为幂等操作，账户不存在时仍返回成功。
final class DeleteAccount {
  const DeleteAccount({required this.accounts, required this.credentials});

  final AccountRepository accounts;
  final CredentialRepository credentials;

  /// 删除账户 [accountId]。
  Future<Result<void>> call(String accountId) async {
    await credentials.delete(accountId);
    await accounts.delete(accountId);
    return const Ok(null);
  }
}
