import 'dart:async';

import 'package:ow_domain/ow_domain.dart';

import 'attempt_limiter.dart';
import 'verify_pin.dart';

/// 应用锁状态。
sealed class AppLockState {
  const AppLockState();
}

/// 首次启动或尚未设置 PIN 码（引导阶段）。
final class AppLockUninitialized extends AppLockState {
  const AppLockUninitialized();

  @override
  bool operator ==(Object other) => other is AppLockUninitialized;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'AppLockUninitialized()';
}

/// 应用已锁定。若处于错误锁定惩罚期间，[lockedUntil] 为截止时间（UTC）。
final class AppLockLocked extends AppLockState {
  const AppLockLocked({this.lockedUntil});

  final DateTime? lockedUntil;

  @override
  bool operator ==(Object other) =>
      other is AppLockLocked && other.lockedUntil == lockedUntil;

  @override
  int get hashCode => lockedUntil.hashCode;

  @override
  String toString() => 'AppLockLocked(lockedUntil: $lockedUntil)';
}

/// 应用已解锁，正常使用中。
final class AppLockUnlocked extends AppLockState {
  const AppLockUnlocked();

  @override
  bool operator ==(Object other) => other is AppLockUnlocked;

  @override
  int get hashCode => 1;

  @override
  String toString() => 'AppLockUnlocked()';
}

/// 应用锁状态机（PRD R18–R21，SECURITY_DESIGN 第 7 节）。
///
/// 管理应用锁的初始化、PIN 与生物识别解锁、手动锁定、后台超时自动重锁、
/// 以及进入锁定状态时触发清理回调（[onLock]）。
final class AppLockStateMachine {
  AppLockStateMachine({
    required this.store,
    required this.limiter,
    required this.verifyPin,
    required this.clock,
    this.onLock,
    this.onUnlock,
  });

  final SecretStore store;
  final AttemptLimiter limiter;
  final VerifyPin verifyPin;
  final Clock clock;

  /// 进入锁定状态时执行的回调（关闭数据库连接、清空内存数据）。
  final FutureOr<void> Function()? onLock;

  /// 解锁成功时执行的回调。
  final FutureOr<void> Function()? onUnlock;

  final _controller = StreamController<AppLockState>.broadcast();
  Stream<AppLockState> get stream => _controller.stream;

  AppLockState _current = const AppLockUninitialized();
  AppLockState get current => _current;

  DateTime? _pausedAt;
  int _externalOperationCount = 0;

  /// 是否有外部界面（如系统弹窗、分享面板、文件选择器）正在进行中。
  bool get isExternalOperationInProgress => _externalOperationCount > 0;

  /// 在外部系统界面进行期间执行 [action]，外部界面期间切到后台不计超时自动锁定。
  Future<T> runExternal<T>(Future<T> Function() action) async {
    _externalOperationCount++;
    try {
      return await action();
    } finally {
      _externalOperationCount--;
    }
  }

  /// 初始化应用锁状态。
  Future<AppLockState> initialize() async {
    final hasPin = await verifyPin.isPinSet();
    if (!hasPin) {
      _current = const AppLockUninitialized();
      _controller.add(_current);
      return _current;
    }

    final limiterState = await limiter.check();
    if (limiterState is Locked) {
      _current = AppLockLocked(lockedUntil: limiterState.until);
    } else {
      _current = const AppLockLocked();
    }
    _controller.add(_current);
    return _current;
  }

  /// 锁定应用。触发 [onLock] 回调。
  Future<void> lock() async {
    if (_current is AppLockLocked || _current is AppLockUninitialized) {
      return;
    }
    final limiterState = await limiter.check();
    final lockedUntil = limiterState is Locked ? limiterState.until : null;
    _current = AppLockLocked(lockedUntil: lockedUntil);
    _controller.add(_current);
    await onLock?.call();
  }

  /// 使用 PIN 解锁。
  Future<Result<void>> unlockWithPin(Sensitive pin) async {
    final res = await verifyPin(pin);
    if (res.isOk) {
      _current = const AppLockUnlocked();
      _controller.add(_current);
      await onUnlock?.call();
      return const Ok(null);
    }

    if (res case Err(:final failure)) {
      if (failure is LockedOutFailure) {
        _current = AppLockLocked(lockedUntil: failure.until);
        _controller.add(_current);
      }
      return Err(failure);
    }
    return res;
  }

  /// 使用系统生物识别验证通过后解锁。
  Future<void> unlockWithBiometric() async {
    _current = const AppLockUnlocked();
    _controller.add(_current);
    await onUnlock?.call();
  }

  /// 应用切到后台时记录暂停时间戳。外部界面进行中时不计时间。
  void handleAppPaused() {
    if (_externalOperationCount > 0) {
      return;
    }
    _pausedAt = clock.nowUtc();
  }

  /// 应用回到前台时，根据后台持续时间与 [autoLock] 设置决定是否锁定。
  /// 处理完成后无论是否锁定都清空 [_pausedAt]。
  Future<void> handleAppResumed(AutoLock autoLock) async {
    final pausedAt = _pausedAt;
    _pausedAt = null;
    if (_current is! AppLockUnlocked || pausedAt == null) {
      return;
    }
    if (_externalOperationCount > 0) {
      return;
    }
    final now = clock.nowUtc();
    final elapsed = now.difference(pausedAt);
    final shouldLock = switch (autoLock) {
      AutoLock.immediately => true,
      AutoLock.after1Min => elapsed >= const Duration(minutes: 1),
      AutoLock.after5Min => elapsed >= const Duration(minutes: 5),
    };
    if (shouldLock) {
      await lock();
    }
  }

  void dispose() {
    _controller.close();
  }
}
