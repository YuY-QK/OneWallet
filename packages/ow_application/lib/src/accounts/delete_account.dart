import 'package:ow_domain/ow_domain.dart';

/// 删除账户（P03、P08、R6）。
///
/// 级联删除其地址、持仓与同步记录（由 [AccountRepository.delete] 保障），
/// 并清理可能存在的交易所 API 凭据（由 [CredentialRepository.delete] 保障）。
/// 操作为幂等操作，账户不存在时仍返回成功。
final class DeleteAccount {
  const DeleteAccount({required this.accounts, required this.credentials});

  final AccountRepository accounts;
  final CredentialRepository credentials;

  /// 删除账户 [accountId]。
  Future<Result<void>> call(String accountId) async {
    await accounts.delete(accountId);
    await credentials.delete(accountId);
    return const Ok(null);
  }
}
