import 'package:ow_domain/ow_domain.dart';

import '../../l10n/app_localizations.dart';
import '../../widgets/failure_text.dart';

/// `SyncRecord.failureType` 中网络失败的类型名（与 `failureTypeName` 一致）。
const String networkFailureTypeName = 'NetworkFailure';

/// 由同步记录里的类型名还原一个 [Failure]，用于显示文案。
///
/// 记录里只存类型名（不含详情）。无法识别的名称按 [UnknownFailure] 处理。
Failure failureFromTypeName(String? name) => switch (name) {
  'NetworkFailure' => const NetworkFailure(),
  'RateLimitedFailure' => const RateLimitedFailure(),
  'UnauthorizedFailure' => const UnauthorizedFailure(),
  'KeyExpiredFailure' => const KeyExpiredFailure(),
  'ClockSkewFailure' => const ClockSkewFailure(),
  'ServiceDownFailure' => const ServiceDownFailure(),
  'ValidationFailure' => const ValidationFailure(),
  'UnsupportedFailure' => const UnsupportedFailure(),
  'WrongPasswordFailure' => const WrongPasswordFailure(),
  _ => const UnknownFailure(),
};

/// 同步失败的用户文案。不支持的链家族单独说明"暂不支持"，其余走 [failureText]。
String syncFailureText(AppLocalizations l, Failure failure) =>
    failure is UnsupportedFailure
    ? l.syncFailureUnsupported
    : failureText(l, failure);
