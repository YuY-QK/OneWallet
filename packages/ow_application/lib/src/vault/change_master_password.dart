import 'dart:convert';

import 'package:ow_domain/ow_domain.dart';

import 'vault_access.dart';
import 'vault_credential.dart';

/// 修改保险库主密码（规格 4.7 节）。
final class ChangeMasterPassword {
  ChangeMasterPassword({
    required this.vaultAccess,
    required this.settings,
    required this.clock,
  });

  final VaultAccess vaultAccess;
  final SettingsRepository settings;
  final Clock clock;

  Future<Result<void>> call({
    required Sensitive currentPassword,
    required Sensitive newPassword,
  }) async {
    // 在打开会话前校验新密码长度
    final pw = newPassword.use((bytes) {
      try {
        return utf8.decode(bytes).trim();
      } catch (_) {
        return '';
      }
    });
    if (pw.runes.length < 10) {
      return const Err(ValidationFailure('master_password_too_short'));
    }

    return vaultAccess.withSession(PasswordCredential(currentPassword), (
      session,
    ) async {
      final changeRes = await session.changePassword(newPassword);
      if (changeRes case Err(:final failure)) {
        return Err(failure);
      }
      await settings.update((s) => s.copyWith(vaultChangedAt: clock.nowUtc()));
      return const Ok(null);
    }, allowBiometric: false);
  }
}
