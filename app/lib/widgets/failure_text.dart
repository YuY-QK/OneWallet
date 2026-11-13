import 'package:ow_domain/ow_domain.dart';

import '../l10n/app_localizations.dart';

/// 把 [Failure] 映射为面向用户的文案（"发生了什么、能做什么"）。
///
/// 页面不得自己拼错误信息，也不显示 [Failure.detail]（它只用于调试日志）。
/// 这里用穷尽的 `switch`：`Failure` 是封闭类型集合，新增一种而不在此处和 ARB
/// 中补文案时，编译器会报错。
String failureText(AppLocalizations l10n, Failure failure) {
  return switch (failure) {
    NetworkFailure() => l10n.failureNetwork,
    RateLimitedFailure() => l10n.failureRateLimited,
    UnauthorizedFailure() => l10n.failureUnauthorized,
    KeyExpiredFailure() => l10n.failureKeyExpired,
    ClockSkewFailure() => l10n.failureClockSkew,
    ServiceDownFailure() => l10n.failureServiceDown,
    ValidationFailure() => l10n.failureValidation,
    DuplicateAddressFailure(
      :final kind,
      :final shortAddress,
      :final existingAccountName,
    ) =>
      l10n.failureDuplicateAddress(
        kind.name,
        shortAddress,
        existingAccountName ?? '',
      ),
    WrongPasswordFailure() => l10n.failureWrongPassword,
    VaultCorruptedFailure() => l10n.failureVaultCorrupted,
    VaultVersionUnsupportedFailure() => l10n.failureVaultVersionUnsupported,
    VaultNotFoundFailure() => l10n.failureVaultNotFound,
    VaultAlreadyExistsFailure() => l10n.failureVaultAlreadyExists,
    VaultItemNotFoundFailure() => l10n.failureVaultItemNotFound,
    UnsupportedFailure(:final reason) => switch (reason) {
      UnsupportedReason.platform => l10n.failureUnsupported,
      UnsupportedReason.notIntegrated => l10n.failureUnsupportedNotIntegrated,
    },
    UnknownFailure() => l10n.failureUnknown,
  };
}
