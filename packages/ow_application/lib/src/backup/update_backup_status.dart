import 'package:ow_domain/ow_domain.dart';

/// 更新钱包账户的备份状态用例（PRD R34–R36）。
final class UpdateBackupStatus {
  const UpdateBackupStatus({required this.accounts});

  final AccountRepository accounts;

  /// 更新指定钱包账户的 [BackupStatus]。
  ///
  /// 若账户不存在或不是钱包账户，返回 [ValidationFailure]。
  Future<Result<Account>> call({
    required String accountId,
    required BackupStatus backup,
  }) async {
    final account = await accounts.byId(accountId);
    if (account == null) {
      return const Err(ValidationFailure('Account not found'));
    }
    if (account.type != AccountType.wallet) {
      return const Err(ValidationFailure('Account is not a wallet'));
    }

    final updated = account.copyWith(backup: backup);
    await accounts.upsert(updated);
    return Ok(updated);
  }
}
