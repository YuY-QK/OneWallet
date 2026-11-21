import 'dart:convert';
import 'dart:typed_data';

import 'package:ow_domain/ow_domain.dart';
import 'package:ow_vault/ow_vault.dart';

import 'attempt_limiter.dart';

/// 系统安全存储中 PIN 哈希的键名。
const appPinStoreKey = 'ow.app.pin.hash';

/// 设置应用锁 PIN 码（PRD R18）。
final class SetUpPin {
  SetUpPin({
    required this.store,
    required this.crypto,
    required this.limiter,
    KdfParams? kdfParams,
  }) : _kdfParams = kdfParams ?? KdfParams.vaultDefault;

  final SecretStore store;
  final VaultCrypto crypto;
  final AttemptLimiter limiter;
  final KdfParams _kdfParams;

  /// 设置新的 6 位数字 PIN。
  ///
  /// 若 PIN 格式不合法返回 [ValidationFailure('pin_must_be_6_digits')]。
  /// 若已设置 PIN 且 [overwrite] 为 false，返回 [ValidationFailure('pin_already_set')]。
  Future<Result<void>> call(Sensitive pin, {bool overwrite = false}) async {
    // 1. 校验 PIN 格式：必须恰好 6 位 ASCII 数字
    final isValid = pin.use((bytes) {
      if (bytes.length != 6) return false;
      for (final b in bytes) {
        if (b < 0x30 || b > 0x39) return false;
      }
      return true;
    });
    if (!isValid) {
      return const Err(ValidationFailure('pin_must_be_6_digits'));
    }

    // 2. 检查是否已有 PIN
    if (!overwrite) {
      final existing = await store.read(appPinStoreKey);
      if (existing != null) {
        return const Err(ValidationFailure('pin_already_set'));
      }
    }

    // 3. 生成 16 字节随机盐并计算 Argon2id 哈希
    final salt = crypto.randomBytes(16);
    final hash = await crypto.argon2id(pin, salt, _kdfParams);

    // 4. 存入安全存储
    final data = {
      'salt': _toHex(salt),
      'hash': _toHex(hash),
      'memKib': _kdfParams.memKib,
      'iterations': _kdfParams.iterations,
    };
    await store.write(appPinStoreKey, jsonEncode(data));

    // 5. 清理 limiter 历史记录
    await limiter.recordSuccess();

    return const Ok(null);
  }
}

String _toHex(Uint8List bytes) {
  final buffer = StringBuffer();
  for (final b in bytes) {
    buffer.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}
