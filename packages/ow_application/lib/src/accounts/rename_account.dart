import 'package:ow_domain/ow_domain.dart';

import 'add_wallet_account.dart';

/// 重命名账户（P03、R5）。
final class RenameAccount {
  const RenameAccount({required this.accounts});

  final AccountRepository accounts;

  /// 为账户 [accountId] 设置新名称 [newName]。
  ///
  /// [newName] 去除首尾空白后须为 1–30 字（以 Unicode runes 计）。
  /// 账户不存在或名称不合法时返回 [ValidationFailure]；成功时更新仓储并返回新账户。
  Future<Result<Account>> call({
    required String accountId,
    required String newName,
  }) async {
    final account = await accounts.byId(accountId);
    if (account == null) {
      return const Err(ValidationFailure('账户不存在'));
    }

    final trimmed = newName.trim();
    final length = trimmed.runes.length;
    if (length == 0 || length > maxAccountNameLength) {
      return const Err(ValidationFailure('名称须为 1–30 字'));
    }

    final updated = account.copyWith(name: trimmed);
    await accounts.upsert(updated);
    return Ok(updated);
  }
}
