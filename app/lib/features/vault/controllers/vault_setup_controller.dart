import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../../bootstrap/foundation_providers.dart';
import '../../../bootstrap/vault_providers.dart';

/// P13 创建保险库页面状态。
///
/// 安全约束：主密码明文绝不进入此状态对象。
final class VaultSetupState {
  const VaultSetupState({
    this.isAgreed = false,
    this.isBiometricsEnabled = true,
    this.isSubmitting = false,
    this.errorMessage,
  });

  /// 是否勾选"我明白主密码丢失后无法恢复"。
  final bool isAgreed;

  /// 是否启用生物识别解锁。
  final bool isBiometricsEnabled;

  /// 是否正在派生密钥并创建。
  final bool isSubmitting;

  /// 错误信息。
  final String? errorMessage;

  VaultSetupState copyWith({
    bool? isAgreed,
    bool? isBiometricsEnabled,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return VaultSetupState(
      isAgreed: isAgreed ?? this.isAgreed,
      isBiometricsEnabled: isBiometricsEnabled ?? this.isBiometricsEnabled,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final vaultSetupControllerProvider =
    NotifierProvider.autoDispose<VaultSetupController, VaultSetupState>(
      VaultSetupController.new,
    );

final class VaultSetupController extends Notifier<VaultSetupState> {
  @override
  VaultSetupState build() {
    final caps = ref.watch(platformCapabilitiesProvider);
    return VaultSetupState(isBiometricsEnabled: caps.hardwareKeystore);
  }

  void toggleAgreed(bool? value) {
    state = state.copyWith(isAgreed: value ?? false, clearError: true);
  }

  void toggleBiometrics(bool value) {
    state = state.copyWith(isBiometricsEnabled: value);
  }

  Future<Result<CreateVaultOutcome>> createVault({
    required Sensitive password,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final createVault = await ref.read(createVaultProvider.future);
      final res = await createVault(
        masterPassword: password,
        enableBiometrics: state.isBiometricsEnabled,
      );
      if (res case Err(:final failure)) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: failure.toString(),
        );
      } else {
        state = state.copyWith(isSubmitting: false);
        ref.invalidate(isVaultInitializedProvider);
      }
      return res;
    } catch (e) {
      final failure = UnknownFailure(e.toString());
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: failure.toString(),
      );
      return Err(failure);
    }
  }
}
