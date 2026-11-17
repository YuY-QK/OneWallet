import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../../bootstrap/app_lock_providers.dart';
import '../../../bootstrap/foundation_providers.dart';

enum OnboardingStep { welcome, enterPin, confirmPin, biometric }

class OnboardingViewState {
  const OnboardingViewState({
    this.step = OnboardingStep.welcome,
    this.enteredLength = 0,
    this.confirmedLength = 0,
    this.shake = false,
    this.errorMessage,
    this.deviceSupportsBiometric = false,
  });

  final OnboardingStep step;

  /// 已输入的 PIN 位数（状态对象中不保留明文数字）。
  final int enteredLength;
  final int confirmedLength;
  final bool shake;
  final String? errorMessage;
  final bool deviceSupportsBiometric;

  int get currentLength =>
      step == OnboardingStep.confirmPin ? confirmedLength : enteredLength;

  OnboardingViewState copyWith({
    OnboardingStep? step,
    int? enteredLength,
    int? confirmedLength,
    bool? shake,
    Object? errorMessage = _unset,
    bool? deviceSupportsBiometric,
  }) => OnboardingViewState(
    step: step ?? this.step,
    enteredLength: enteredLength ?? this.enteredLength,
    confirmedLength: confirmedLength ?? this.confirmedLength,
    shake: shake ?? this.shake,
    errorMessage: identical(errorMessage, _unset)
        ? this.errorMessage
        : errorMessage as String?,
    deviceSupportsBiometric:
        deviceSupportsBiometric ?? this.deviceSupportsBiometric,
  );
}

const _unset = Object();

final onboardingControllerProvider =
    NotifierProvider.autoDispose<OnboardingController, OnboardingViewState>(
      OnboardingController.new,
    );

class OnboardingController extends Notifier<OnboardingViewState> {
  final List<int> _enteredDigits = [];
  final List<int> _confirmedDigits = [];

  @override
  OnboardingViewState build() {
    ref.onDispose(() {
      _enteredDigits.clear();
      _confirmedDigits.clear();
    });
    _checkBiometricSupport();
    return const OnboardingViewState();
  }

  Future<void> _checkBiometricSupport() async {
    final bio = ref.read(biometricAuthProvider);
    final available = await bio.isAvailable();
    if (!ref.mounted) return;
    state = state.copyWith(deviceSupportsBiometric: available);
  }

  void startPinSetup() {
    _enteredDigits.clear();
    _confirmedDigits.clear();
    state = state.copyWith(
      step: OnboardingStep.enterPin,
      enteredLength: 0,
      confirmedLength: 0,
      errorMessage: null,
      shake: false,
    );
  }

  void addDigit(int digit) {
    if (state.step == OnboardingStep.enterPin) {
      if (_enteredDigits.length >= 6) return;
      _enteredDigits.add(digit);
      state = state.copyWith(
        enteredLength: _enteredDigits.length,
        errorMessage: null,
        shake: false,
      );
      if (_enteredDigits.length == 6) {
        state = state.copyWith(
          step: OnboardingStep.confirmPin,
          confirmedLength: 0,
        );
      }
    } else if (state.step == OnboardingStep.confirmPin) {
      if (_confirmedDigits.length >= 6) return;
      _confirmedDigits.add(digit);
      state = state.copyWith(
        confirmedLength: _confirmedDigits.length,
        errorMessage: null,
        shake: false,
      );
      if (_confirmedDigits.length == 6) {
        _validateAndSave();
      }
    }
  }

  void backspace() {
    if (state.step == OnboardingStep.enterPin && _enteredDigits.isNotEmpty) {
      _enteredDigits.removeLast();
      state = state.copyWith(
        enteredLength: _enteredDigits.length,
        errorMessage: null,
        shake: false,
      );
    } else if (state.step == OnboardingStep.confirmPin) {
      if (_confirmedDigits.isNotEmpty) {
        _confirmedDigits.removeLast();
        state = state.copyWith(
          confirmedLength: _confirmedDigits.length,
          errorMessage: null,
          shake: false,
        );
      } else {
        // 退回到第一遍输入
        state = state.copyWith(
          step: OnboardingStep.enterPin,
          errorMessage: null,
          shake: false,
        );
      }
    }
  }

  void resetShake() {
    state = state.copyWith(shake: false);
  }

  Future<void> _validateAndSave() async {
    final bool match =
        _enteredDigits.length == 6 &&
        _confirmedDigits.length == 6 &&
        _enteredDigits.join() == _confirmedDigits.join();

    if (!match) {
      _enteredDigits.clear();
      _confirmedDigits.clear();
      state = state.copyWith(
        step: OnboardingStep.enterPin,
        enteredLength: 0,
        confirmedLength: 0,
        shake: true,
        errorMessage: 'pin_mismatch',
      );
      return;
    }

    final pinBytes = Uint8List.fromList(
      _confirmedDigits.map((d) => d + 48).toList(),
    );
    _enteredDigits.clear();
    _confirmedDigits.clear();
    final pin = Sensitive(pinBytes);

    // 保存 PIN
    final setUp = await ref.read(setUpPinProvider.future);
    final res = await setUp(pin);
    pin.wipe();

    if (res.isOk) {
      if (state.deviceSupportsBiometric) {
        state = state.copyWith(step: OnboardingStep.biometric);
      } else {
        await _completeOnboarding();
      }
    } else {
      state = state.copyWith(
        step: OnboardingStep.enterPin,
        enteredLength: 0,
        confirmedLength: 0,
        shake: true,
        errorMessage: 'pin_save_failed',
      );
    }
  }

  Future<void> enableBiometricAndComplete() async {
    final settingsRepo = ref.read(settingsRepositoryProvider);
    await settingsRepo.update((s) => s.copyWith(appBiometrics: true));
    await _completeOnboarding();
  }

  Future<void> skipBiometricAndComplete() async {
    final settingsRepo = ref.read(settingsRepositoryProvider);
    await settingsRepo.update((s) => s.copyWith(appBiometrics: false));
    await _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    final machine = await ref.read(appLockStateMachineProvider.future);
    await machine.unlockWithBiometric(); // 设置为已解锁
  }
}
