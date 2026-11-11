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
    WrongPasswordFailure() => l10n.failureWrongPassword,
    UnsupportedFailure() => l10n.failureUnsupported,
    UnknownFailure() => l10n.failureUnknown,
  };
}
