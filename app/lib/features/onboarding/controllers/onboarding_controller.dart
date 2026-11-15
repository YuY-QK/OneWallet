import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../../bootstrap/app_lock_providers.dart';
import '../../../bootstrap/foundation_providers.dart';

enum OnboardingStep { welcome, enterPin, confirmPin, biometric }

class OnboardingViewState {
  const OnboardingViewState({
    this.step = OnboardingStep.welcome,
    this.enteredPin = '',
    this.confirmedPin = '',
    this.shake = false,
    this.errorMessage,
    this.deviceSupportsBiometric = false,
  });

  final OnboardingStep step;
  final String enteredPin;
  final String confirmedPin;
  final bool shake;
  final String? errorMessage;
  final bool deviceSupportsBiometric;

  String get currentDigits =>
      step == OnboardingStep.confirmPin ? confirmedPin : enteredPin;

  OnboardingViewState copyWith({
    OnboardingStep? step,
    String? enteredPin,
    String? confirmedPin,
    bool? shake,
    Object? errorMessage = _unset,
    bool? deviceSupportsBiometric,
  }) => OnboardingViewState(
    step: step ?? this.step,
    enteredPin: enteredPin ?? this.enteredPin,
    confirmedPin: confirmedPin ?? this.confirmedPin,
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
  @override
  OnboardingViewState build() {
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
    state = state.copyWith(
      step: OnboardingStep.enterPin,
      enteredPin: '',
      confirmedPin: '',
      errorMessage: null,
      shake: false,
    );
  }

  void addDigit(int digit) {
    if (state.step == OnboardingStep.enterPin) {
      if (state.enteredPin.length >= 6) return;
      final next = '${state.enteredPin}$digit';
      state = state.copyWith(
        enteredPin: next,
        errorMessage: null,
        shake: false,
      );
      if (next.length == 6) {
        state = state.copyWith(
          step: OnboardingStep.confirmPin,
          confirmedPin: '',
        );
      }
    } else if (state.step == OnboardingStep.confirmPin) {
      if (state.confirmedPin.length >= 6) return;
      final next = '${state.confirmedPin}$digit';
      state = state.copyWith(
        confirmedPin: next,
        errorMessage: null,
        shake: false,
      );
      if (next.length == 6) {
        _validateAndSave(next);
      }
    }
  }

  void backspace() {
    if (state.step == OnboardingStep.enterPin && state.enteredPin.isNotEmpty) {
      state = state.copyWith(
        enteredPin: state.enteredPin.substring(0, state.enteredPin.length - 1),
        errorMessage: null,
        shake: false,
      );
    } else if (state.step == OnboardingStep.confirmPin) {
      if (state.confirmedPin.isNotEmpty) {
        state = state.copyWith(
          confirmedPin: state.confirmedPin.substring(
            0,
            state.confirmedPin.length - 1,
          ),
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

  Future<void> _validateAndSave(String confirm) async {
    if (confirm != state.enteredPin) {
      state = state.copyWith(
        step: OnboardingStep.enterPin,
        enteredPin: '',
        confirmedPin: '',
        shake: true,
        errorMessage: 'pin_mismatch',
      );
      return;
    }

    // 保存 PIN
    final setUp = await ref.read(setUpPinProvider.future);
    final pin = Sensitive(Uint8List.fromList(utf8.encode(confirm)));
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
        enteredPin: '',
        confirmedPin: '',
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
