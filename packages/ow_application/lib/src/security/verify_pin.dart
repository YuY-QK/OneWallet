import 'dart:convert';
import 'dart:typed_data';

import 'package:ow_domain/ow_domain.dart';
import 'package:ow_vault/ow_vault.dart';

import 'attempt_limiter.dart';
import 'set_up_pin.dart';

/// 验证应用锁 PIN 码（PRD R20）。
final class VerifyPin {
  VerifyPin({required this.store, required this.crypto, required this.limiter});

  final SecretStore store;
  final VaultCrypto crypto;
  final AttemptLimiter limiter;

  /// 验证候选 PIN。
  ///
  /// 若处于锁定状态，直接返回 [LockedOutFailure]；
  /// 若 PIN 格式不匹配或哈希不匹配，记录失败并返回 [WrongPasswordFailure] 或 [LockedOutFailure]。
  Future<Result<void>> call(Sensitive pin) async {
    // 1. 检查限制器状态
    final lockState = await limiter.check();
    if (lockState is Locked) {
      return Err(LockedOutFailure(lockState.until));
    }

    // 2. 读取存储的校验数据
    final stored = await store.read(appPinStoreKey);
    if (stored == null) {
      return const Err(ValidationFailure('pin_not_set'));
    }

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(stored) as Map<String, dynamic>;
    } catch (_) {
      // 存储损坏时保守锁定
      return await limiter.recordFailure();
    }

    final saltHex = data['salt'] as String?;
    final hashHex = data['hash'] as String?;
    final memKib = data['memKib'] as int?;
    final iterations = data['iterations'] as int?;

    if (saltHex == null ||
        hashHex == null ||
        memKib == null ||
        iterations == null) {
      return await limiter.recordFailure();
    }

    final salt = _fromHex(saltHex);
    final expectedHash = _fromHex(hashHex);
    final params = KdfParams(memKib: memKib, iterations: iterations);

    // 3. 校验 PIN 格式
    final isCandidateValid = pin.use((bytes) {
      if (bytes.length != 6) return false;
      for (final b in bytes) {
        if (b < 0x30 || b > 0x39) return false;
      }
      return true;
    });
    if (!isCandidateValid) {
      return await limiter.recordFailure();
    }

    // 4. 计算哈希并常数时间比对
    final candidateHash = await crypto.argon2id(pin, salt, params);

    if (_constantTimeEquals(candidateHash, expectedHash)) {
      await limiter.recordSuccess();
      return const Ok(null);
    } else {
      return await limiter.recordFailure();
    }
  }

  /// 当前是否已设置 PIN。
  Future<bool> isPinSet() async {
    final stored = await store.read(appPinStoreKey);
    return stored != null && stored.isNotEmpty;
  }
}

Uint8List _fromHex(String hex) {
  final clean = hex.trim();
  final len = clean.length ~/ 2;
  final result = Uint8List(len);
  for (var i = 0; i < len; i++) {
    result[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return result;
}

bool _constantTimeEquals(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
