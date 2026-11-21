import 'dart:math';

import 'package:ow_domain/ow_domain.dart';

/// 错误次数限制状态。
sealed class LockState {
  const LockState();
}

/// 未锁定状态，包含当前累计失败次数 [failures]。
final class Unlocked extends LockState {
  const Unlocked(this.failures);
  final int failures;

  @override
  bool operator ==(Object other) =>
      other is Unlocked && other.failures == failures;

  @override
  int get hashCode => failures.hashCode;

  @override
  String toString() => 'Unlocked(failures: $failures)';
}

/// 锁定状态，锁定至 [until]（UTC）。
final class Locked extends LockState {
  const Locked(this.until);
  final DateTime until;

  @override
  bool operator ==(Object other) => other is Locked && other.until == until;

  @override
  int get hashCode => until.hashCode;

  @override
  String toString() => 'Locked(until: $until)';
}

/// 错误输入次数限制器（规格 3.3 节）。
///
/// 用于保险库解锁密码限制和应用锁 PIN 码错误限制。
final class AttemptLimiter {
  AttemptLimiter({
    required this.store,
    required this.clock,
    required String keyPrefix,
  }) : _keyFailures = '$keyPrefix.failures',
       _keyLockUntil = '$keyPrefix.lock_until',
       _keyRecordedAt = '$keyPrefix.recorded_at';

  final SecretStore store;
  final Clock clock;
  final String _keyFailures;
  final String _keyLockUntil;
  final String _keyRecordedAt;

  static const int _threshold = 5;
  static const int _maxLockMinutes = 60;

  /// 只读检查当前锁定状态。
  Future<LockState> check() async {
    final now = clock.nowUtc();
    final failuresStr = await store.read(_keyFailures);
    final lockUntilStr = await store.read(_keyLockUntil);
    final recordedAtStr = await store.read(_keyRecordedAt);

    if (failuresStr == null && lockUntilStr == null && recordedAtStr == null) {
      return const Unlocked(0);
    }

    int failures = 0;
    if (failuresStr != null) {
      final parsed = int.tryParse(failuresStr);
      if (parsed == null || parsed < 0) {
        return Locked(now.add(const Duration(minutes: _maxLockMinutes)));
      }
      failures = parsed;
    }

    if (lockUntilStr != null) {
      final lockUntilMs = int.tryParse(lockUntilStr);
      final recordedAtMs = recordedAtStr != null
          ? int.tryParse(recordedAtStr)
          : null;

      if (lockUntilMs == null) {
        return Locked(now.add(const Duration(minutes: _maxLockMinutes)));
      }

      var until = DateTime.fromMillisecondsSinceEpoch(lockUntilMs, isUtc: true);

      // 防时钟调回检测
      if (recordedAtMs != null) {
        final recordedAt = DateTime.fromMillisecondsSinceEpoch(
          recordedAtMs,
          isUtc: true,
        );
        if (now.isBefore(recordedAt)) {
          final remainingMs = max(0, lockUntilMs - recordedAtMs);
          until = now.add(Duration(milliseconds: remainingMs));
          // 写回校正后的截止时间与当前记录时间
          await store.write(
            _keyLockUntil,
            until.millisecondsSinceEpoch.toString(),
          );
          await store.write(
            _keyRecordedAt,
            now.millisecondsSinceEpoch.toString(),
          );
        }
      }

      if (now.isBefore(until)) {
        return Locked(until);
      }
    }

    return Unlocked(failures);
  }

  /// 记录一次验证失败。
  ///
  /// 返回 `Err(WrongPasswordFailure)` 或 `Err(LockedOutFailure)`。
  Future<Result<void>> recordFailure() async {
    final now = clock.nowUtc();
    final current = await check();

    if (current is Locked) {
      return Err(LockedOutFailure(current.until));
    }

    final newFailures = (current as Unlocked).failures + 1;
    await store.write(_keyFailures, newFailures.toString());
    await store.write(_keyRecordedAt, now.millisecondsSinceEpoch.toString());

    if (newFailures >= _threshold) {
      final exponent = newFailures - _threshold;
      final minutes = min(1 << exponent, _maxLockMinutes);
      final until = now.add(Duration(minutes: minutes));
      await store.write(_keyLockUntil, until.millisecondsSinceEpoch.toString());
      return Err(LockedOutFailure(until));
    }

    return const Err(WrongPasswordFailure());
  }

  /// 验证成功，清空所有计数与锁定状态。
  Future<void> recordSuccess() async {
    await store.delete(_keyFailures);
    await store.delete(_keyLockUntil);
    await store.delete(_keyRecordedAt);
  }
}
