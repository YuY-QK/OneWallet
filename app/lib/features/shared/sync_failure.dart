import 'package:ow_domain/ow_domain.dart';

/// `SyncRecord.failureType` 中网络失败的类型名（与 `failureTypeName` 一致）。
const String networkFailureTypeName = 'NetworkFailure';

/// 由同步记录里的类型名还原一个 [Failure]，用于显示文案。
///
/// 记录里只存类型名（不含详情）；`UnsupportedFailure` 的名称带原因（见 `failureTypeName`）。无法识别的名称按 [UnknownFailure] 处理。
Failure failureFromTypeName(String? name) => switch (name) {
  'NetworkFailure' => const NetworkFailure(),
  'RateLimitedFailure' => const RateLimitedFailure(),
  'UnauthorizedFailure' => const UnauthorizedFailure(),
  'KeyExpiredFailure' => const KeyExpiredFailure(),
  'ClockSkewFailure' => const ClockSkewFailure(),
  'ServiceDownFailure' => const ServiceDownFailure(),
  'ValidationFailure' => const ValidationFailure(),
  'UnsupportedFailure' => const UnsupportedFailure(),
  'UnsupportedFailure.notIntegrated' =>
    const UnsupportedFailure.notIntegrated(),
  'WrongPasswordFailure' => const WrongPasswordFailure(),
  _ => const UnknownFailure(),
};
