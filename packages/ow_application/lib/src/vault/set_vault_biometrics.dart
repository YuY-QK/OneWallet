import 'package:ow_domain/ow_domain.dart';

import 'vault_access.dart';
import 'vault_credential.dart';

/// 设置保险库生物识别开关（规格 4.8 节）。
final class SetVaultBiometrics {
  SetVaultBiometrics({
    required this.vaultAccess,
    required this.capabilities,
    required this.settings,
  });

  final VaultAccess vaultAccess;
  final PlatformCapabilities capabilities;
  final SettingsRepository settings;

  Future<Result<void>> call({
    required bool enable,
    PasswordCredential? credential,
  }) async {
    if (enable) {
      if (credential == null) {
        return const Err(ValidationFailure('credential_required'));
      }
      if (!capabilities.hardwareKeystore) {
        return const Err(UnsupportedFailure());
      }
      return vaultAccess.withSession(credential, (session) async {
        final wrapRes = await vaultAccess.enableHardwareWrap(session);
        if (wrapRes case Err(:final failure)) {
          return Err(failure);
        }
        await settings.update((s) => s.copyWith(vaultBiometrics: true));
        return const Ok(null);
      }, allowBiometric: false);
    } else {
      await vaultAccess.disableHardwareWrap();
      await settings.update((s) => s.copyWith(vaultBiometrics: false));
      return const Ok(null);
    }
  }
}
