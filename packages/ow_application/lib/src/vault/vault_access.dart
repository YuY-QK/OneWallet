import 'dart:convert';
import 'dart:typed_data';

import 'package:ow_domain/ow_domain.dart';
import 'package:ow_vault/ow_vault.dart';

import '../security/attempt_limiter.dart';
import 'vault_constants.dart';
import 'vault_credential.dart';

/// 会话访问控制器（规格 3.2 节）。
///
/// 打开保险库会话的唯一入口，管理主密码与生物识别解锁、错误次数限制、
/// 硬件包裹保存与生物识别自动恢复（PRD R30）。
final class VaultAccess {
  VaultAccess({
    required this.vault,
    required this.hardwareKeyStore,
    required this.secretStore,
    required this.capabilities,
    required this.settings,
    required this.passwordLimiter,
  });

  final Vault vault;
  final HardwareKeyStore hardwareKeyStore;
  final SecretStore secretStore;
  final PlatformCapabilities capabilities;
  final SettingsRepository settings;
  final AttemptLimiter passwordLimiter;

  static const String _keyAlias = vaultMasterKeyHardwareAlias;
  static const String _secretKeyHwWrapped = 'ow.vault.hw_wrapped';

  /// 保险库文件是否存在。
  Future<bool> exists() => vault.exists();

  /// 打开会话，执行 [body]，无论成败都在 finally 中关闭会话。
  ///
  /// [allowBiometric] 为 false 时，传入 BiometricCredential 直接返回
  /// `ValidationFailure('password_required')`。
  Future<Result<T>> withSession<T>(
    VaultCredential credential,
    Future<Result<T>> Function(VaultSession session) body, {
    bool allowBiometric = true,
  }) async {
    return switch (credential) {
      PasswordCredential(:final password) => _withPassword(password, body),
      BiometricCredential(:final reason) => _withBiometric(
        reason,
        body,
        allowBiometric: allowBiometric,
      ),
    };
  }

  Future<Result<T>> _withPassword<T>(
    Sensitive password,
    Future<Result<T>> Function(VaultSession session) body,
  ) async {
    // 1. 密码为空 -> WrongPasswordFailure，结束（不计次数）
    if (password.use((b) => b.isEmpty)) {
      return const Err(WrongPasswordFailure());
    }

    // 2. 检查锁定状态
    final lockState = await passwordLimiter.check();
    if (lockState is Locked) {
      return Err(LockedOutFailure(lockState.until));
    }

    // 3. 执行解锁
    final unlockRes = await vault.unlockWithPassword(password);
    switch (unlockRes) {
      case Err(:final failure):
        if (failure is WrongPasswordFailure) {
          // 4. 记录失败
          final rec = await passwordLimiter.recordFailure();
          return Err((rec as Err<void>).failure);
        }
        // 5. 其他失败原样返回，不计次数
        return Err(failure);
      case Ok(value: final session):
        // 6. 成功 -> 清零失败次数
        await passwordLimiter.recordSuccess();

        // 7. 生物识别恢复 (PRD R30)
        try {
          final s = await settings.watch().first;
          final wrapped = await secretStore.read(_secretKeyHwWrapped);
          if (s.vaultBiometrics &&
              capabilities.hardwareKeystore &&
              wrapped == null) {
            await enableHardwareWrap(session);
          }
        } catch (_) {
          // 恢复失败不影响本次操作
        }

        // 8. 执行 body，并在 finally 中关闭 session
        try {
          return await body(session);
        } finally {
          session.close();
        }
    }
  }

  Future<Result<T>> _withBiometric<T>(
    String reason,
    Future<Result<T>> Function(VaultSession session) body, {
    required bool allowBiometric,
  }) async {
    // 1. 不允许生物识别
    if (!allowBiometric) {
      return const Err(ValidationFailure('password_required'));
    }

    // 2. 硬件或设置不可用
    final s = await settings.watch().first;
    final wrappedB64 = await secretStore.read(_secretKeyHwWrapped);
    if (!capabilities.hardwareKeystore ||
        !s.vaultBiometrics ||
        wrappedB64 == null) {
      return const Err(BiometricUnavailableFailure());
    }

    final Uint8List wrappedBytes;
    try {
      wrappedBytes = base64Decode(wrappedB64);
    } catch (_) {
      await _deleteWrapArtifacts();
      return const Err(BiometricUnavailableFailure());
    }

    // 3. 硬件解包
    final unwrapRes = await hardwareKeyStore.unwrap(
      _keyAlias,
      wrappedBytes,
      reason: reason,
    );
    if (unwrapRes case Err()) {
      await _deleteWrapArtifacts();
      return const Err(BiometricUnavailableFailure());
    }

    final rawMasterKey = unwrapRes.valueOrNull!;
    final masterKey = Sensitive(rawMasterKey);
    try {
      // 4. 用主密钥解锁
      final unlockRes = await vault.unlockWithMasterKey(masterKey);
      if (unlockRes case Err(:final failure)) {
        if (failure is WrongPasswordFailure) {
          // 包裹过期（如保险库重建过）
          await _deleteWrapArtifacts();
          return const Err(BiometricUnavailableFailure());
        }
        return Err(failure);
      }
      final session = unlockRes.valueOrNull!;
      try {
        return await body(session);
      } finally {
        session.close();
      }
    } finally {
      masterKey.wipe();
    }
  }

  /// 用会话的主密钥生成硬件包裹并保存；会话由调用方提供，本方法不关闭它。
  Future<Result<void>> enableHardwareWrap(VaultSession session) async {
    final masterKey = session.exportMasterKey();
    try {
      final wrappedResult = await masterKey.use(
        (bytes) => hardwareKeyStore.wrap(_keyAlias, bytes),
      );
      if (wrappedResult case Ok(:final value)) {
        await secretStore.write(_secretKeyHwWrapped, base64Encode(value));
        return const Ok(null);
      }
      return Err((wrappedResult as Err<Uint8List>).failure);
    } finally {
      masterKey.wipe();
    }
  }

  /// 删除硬件包裹（别名与保存的包裹字节）。幂等。
  Future<void> disableHardwareWrap() async {
    await _deleteWrapArtifacts();
  }

  Future<void> _deleteWrapArtifacts() async {
    await hardwareKeyStore.delete(_keyAlias);
    await secretStore.delete(_secretKeyHwWrapped);
  }
}
