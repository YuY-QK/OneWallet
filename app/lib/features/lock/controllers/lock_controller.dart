import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../../bootstrap/app_lock_providers.dart';
import '../../../bootstrap/foundation_providers.dart';

class LockViewState {
  const LockViewState({
    this.enteredCount = 0,
    this.shake = false,
    this.errorMessage,
    this.lockedUntil,
    this.remainingSeconds = 0,
    this.canUseBiometric = false,
  });

  /// 已输入的 PIN 位数（状态对象中不保留明文数字）。
  final int enteredCount;
  final bool shake;
  final String? errorMessage;
  final DateTime? lockedUntil;
  final int remainingSeconds;
  final bool canUseBiometric;

  bool get isLockedOut => remainingSeconds > 0;

  LockViewState copyWith({
    int? enteredCount,
    bool? shake,
    Object? errorMessage = _unset,
    Object? lockedUntil = _unset,
    int? remainingSeconds,
    bool? canUseBiometric,
  }) => LockViewState(
    enteredCount: enteredCount ?? this.enteredCount,
    shake: shake ?? this.shake,
    errorMessage: identical(errorMessage, _unset)
        ? this.errorMessage
        : errorMessage as String?,
    lockedUntil: identical(lockedUntil, _unset)
        ? this.lockedUntil
        : lockedUntil as DateTime?,
    remainingSeconds: remainingSeconds ?? this.remainingSeconds,
    canUseBiometric: canUseBiometric ?? this.canUseBiometric,
  );
}

const _unset = Object();

final lockControllerProvider =
    NotifierProvider.autoDispose<LockController, LockViewState>(
      LockController.new,
    );

class LockController extends Notifier<LockViewState> {
  Timer? _countdownTimer;
  final List<int> _digits = [];

  @override
  LockViewState build() {
    ref.onDispose(() {
      _countdownTimer?.cancel();
      _digits.clear();
    });

    _checkInitialStatus();
    return const LockViewState();
  }

  Future<void> _checkInitialStatus() async {
    final limiter = ref.read(appLockLimiterProvider);
    final lockState = await limiter.check();
    final clock = ref.read(clockProvider);

    DateTime? until;
    int remaining = 0;
    if (lockState is Locked) {
      until = lockState.until;
      final diff = until.difference(clock.nowUtc()).inSeconds;
      remaining = diff > 0 ? diff : 0;
    }

    final biometrics = ref.read(biometricAuthProvider);
    final settings = await ref.read(settingsRepositoryProvider).watch().first;
    final canBio = settings.appBiometrics && await biometrics.isAvailable();
    if (!ref.mounted) return;

    state = state.copyWith(
      lockedUntil: until,
      remainingSeconds: remaining,
      canUseBiometric: canBio,
    );

    if (remaining > 0) {
      _startCountdown();
    } else if (canBio) {
      unawaited(authenticateWithBiometric());
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final clock = ref.read(clockProvider);
      final until = state.lockedUntil;
      if (until == null) {
        _countdownTimer?.cancel();
        return;
      }
      final diff = until.difference(clock.nowUtc()).inSeconds;
      if (diff <= 0) {
        _countdownTimer?.cancel();
        state = state.copyWith(
          remainingSeconds: 0,
          lockedUntil: null,
          errorMessage: null,
        );
      } else {
        state = state.copyWith(remainingSeconds: diff);
      }
    });
  }

  void addDigit(int digit) {
    if (state.isLockedOut || _digits.length >= 6) return;

    _digits.add(digit);
    state = state.copyWith(
      enteredCount: _digits.length,
      errorMessage: null,
      shake: false,
    );

    if (_digits.length == 6) {
      _submitPin();
    }
  }

  void backspace() {
    if (_digits.isEmpty || state.isLockedOut) return;
    _digits.removeLast();
    state = state.copyWith(
      enteredCount: _digits.length,
      errorMessage: null,
      shake: false,
    );
  }

  void resetShake() {
    state = state.copyWith(shake: false);
  }

  Future<void> _submitPin() async {
    final pinBytes = Uint8List.fromList(_digits.map((d) => d + 48).toList());
    _digits.clear();
    final pin = Sensitive(pinBytes);

    final machine = await ref.read(appLockStateMachineProvider.future);
    final res = await machine.unlockWithPin(pin);
    pin.wipe();

    if (res.isOk) {
      state = state.copyWith(enteredCount: 0, errorMessage: null, shake: false);
      return;
    }

    if (res case Err(:final failure)) {
      if (failure is LockedOutFailure) {
        final clock = ref.read(clockProvider);
        final diff = failure.until.difference(clock.nowUtc()).inSeconds;
        state = state.copyWith(
          enteredCount: 0,
          shake: true,
          lockedUntil: failure.until,
          remainingSeconds: diff > 0 ? diff : 0,
          errorMessage: 'locked_out',
        );
        _startCountdown();
      } else {
        state = state.copyWith(
          enteredCount: 0,
          shake: true,
          errorMessage: 'wrong_pin',
        );
      }
    }
  }

  Future<void> authenticateWithBiometric() async {
    if (state.isLockedOut) return;

    final biometrics = ref.read(biometricAuthProvider);
    final res = await biometrics.authenticate(reason: '解锁 OneWallet');
    if (res.isOk) {
      final machine = await ref.read(appLockStateMachineProvider.future);
      await machine.unlockWithBiometric();
    }
  }
}
