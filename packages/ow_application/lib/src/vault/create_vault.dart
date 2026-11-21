import 'dart:convert';

import 'package:ow_domain/ow_domain.dart';
import 'package:ow_vault/ow_vault.dart';

import 'vault_access.dart';

/// 创建保险库的结果。
final class CreateVaultOutcome {
  const CreateVaultOutcome({required this.biometricsEnabled});

  /// 是否成功开启了生物识别。
  final bool biometricsEnabled;

  @override
  bool operator ==(Object other) =>
      other is CreateVaultOutcome &&
      other.biometricsEnabled == biometricsEnabled;

  @override
  int get hashCode => biometricsEnabled.hashCode;

  @override
  String toString() =>
      'CreateVaultOutcome(biometricsEnabled: $biometricsEnabled)';
}

/// 创建保险库（规格 4.1 节）。
final class CreateVault {
  CreateVault({
    required this.vault,
    required this.vaultAccess,
    required this.capabilities,
    required this.settings,
    required this.clock,
  });

  final Vault vault;
  final VaultAccess vaultAccess;
  final PlatformCapabilities capabilities;
  final SettingsRepository settings;
  final Clock clock;

  /// 创建新的保险库。
  ///
  /// 主密码去除首尾空白后长度不少于 10 个字符（Unicode 码点），
  /// 否则返回 [ValidationFailure('master_password_too_short')]。
  Future<Result<CreateVaultOutcome>> call({
    required Sensitive masterPassword,
    required bool enableBiometrics,
  }) async {
    // 1. 校验主密码
    final pw = masterPassword.use((bytes) {
      try {
        return utf8.decode(bytes).trim();
      } catch (_) {
        return '';
      }
    });
    if (pw.runes.length < 10) {
      return const Err(ValidationFailure('master_password_too_short'));
    }

    // 2. 检查是否已存在
    if (await vaultAccess.exists()) {
      return const Err(VaultAlreadyExistsFailure());
    }

    // 3. 创建保险库
    final createRes = await vault.create(masterPassword);
    if (createRes case Err(:final failure)) {
      return Err(failure);
    }
    final session = createRes.valueOrNull!;

    var biometricsEnabled = false;
    try {
      // 4 & 5. 尝试开启生物识别
      if (enableBiometrics && capabilities.hardwareKeystore) {
        final wrapRes = await vaultAccess.enableHardwareWrap(session);
        if (wrapRes.isOk) {
          await settings.update((s) => s.copyWith(vaultBiometrics: true));
          biometricsEnabled = true;
        } else {
          await settings.update((s) => s.copyWith(vaultBiometrics: false));
        }
      } else {
        await settings.update((s) => s.copyWith(vaultBiometrics: false));
      }
    } finally {
      // 6. 关闭会话
      session.close();
    }

    // 7. 设 vaultChangedAt
    await settings.update((s) => s.copyWith(vaultChangedAt: clock.nowUtc()));

    return Ok(CreateVaultOutcome(biometricsEnabled: biometricsEnabled));
  }
}
