import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../../bootstrap/app_lock_providers.dart';
import '../../../bootstrap/foundation_providers.dart';

class LockViewState {
  const LockViewState({
    this.enteredDigits = '',
    this.shake = false,
    this.errorMessage,
    this.lockedUntil,
    this.remainingSeconds = 0,
    this.canUseBiometric = false,
  });

  final String enteredDigits;
  final bool shake;
  final String? errorMessage;
  final DateTime? lockedUntil;
  final int remainingSeconds;
  final bool canUseBiometric;

  bool get isLockedOut => remainingSeconds > 0;

  LockViewState copyWith({
    String? enteredDigits,
    bool? shake,
    Object? errorMessage = _unset,
    Object? lockedUntil = _unset,
    int? remainingSeconds,
    bool? canUseBiometric,
  }) => LockViewState(
    enteredDigits: enteredDigits ?? this.enteredDigits,
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

  @override
  LockViewState build() {
    ref.onDispose(() {
      _countdownTimer?.cancel();
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
    if (state.isLockedOut || state.enteredDigits.length >= 6) return;

    final next = '${state.enteredDigits}$digit';
    state = state.copyWith(
      enteredDigits: next,
      errorMessage: null,
      shake: false,
    );

    if (next.length == 6) {
      _submitPin(next);
    }
  }

  void backspace() {
    if (state.enteredDigits.isEmpty || state.isLockedOut) return;
    state = state.copyWith(
      enteredDigits: state.enteredDigits.substring(
        0,
        state.enteredDigits.length - 1,
      ),
      errorMessage: null,
      shake: false,
    );
  }

  void resetShake() {
    state = state.copyWith(shake: false);
  }

  Future<void> _submitPin(String pinStr) async {
    final machine = await ref.read(appLockStateMachineProvider.future);
    final pin = Sensitive(Uint8List.fromList(utf8.encode(pinStr)));

    final res = await machine.unlockWithPin(pin);
    pin.wipe();

    if (res.isOk) {
      state = state.copyWith(
        enteredDigits: '',
        errorMessage: null,
        shake: false,
      );
      return;
    }

    if (res case Err(:final failure)) {
      if (failure is LockedOutFailure) {
        final clock = ref.read(clockProvider);
        final diff = failure.until.difference(clock.nowUtc()).inSeconds;
        state = state.copyWith(
          enteredDigits: '',
          shake: true,
          lockedUntil: failure.until,
          remainingSeconds: diff > 0 ? diff : 0,
          errorMessage: 'locked_out',
        );
        _startCountdown();
      } else {
        state = state.copyWith(
          enteredDigits: '',
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
