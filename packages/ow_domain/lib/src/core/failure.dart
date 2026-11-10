/// 可预期的失败。每一种对应一条用户可读的文案（由界面层负责翻译）。
///
/// [detail] 只用于调试日志，不得包含任何密钥类数据。
sealed class Failure {
  const Failure([this.detail]);
  final String? detail;

  @override
  String toString() => '$runtimeType${detail == null ? '' : '($detail)'}';
}

/// 网络不可用或请求超时。
final class NetworkFailure extends Failure {
  const NetworkFailure([super.detail]);
}

/// 被服务商限频。
final class RateLimitedFailure extends Failure {
  const RateLimitedFailure([super.detail]);
}

/// 凭据无效（API Key 或 Secret 错误）。
final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.detail]);
}

/// 凭据曾经有效，现已过期或被删除。
final class KeyExpiredFailure extends Failure {
  const KeyExpiredFailure([super.detail]);
}

/// 设备时间与服务器偏差过大，签名被拒绝。
final class ClockSkewFailure extends Failure {
  const ClockSkewFailure([super.detail]);
}

/// 服务商故障。
final class ServiceDownFailure extends Failure {
  const ServiceDownFailure([super.detail]);
}

/// 输入未通过校验（地址格式、助记词校验和等）。
final class ValidationFailure extends Failure {
  const ValidationFailure([super.detail]);
}

/// 密码或 PIN 错误。
final class WrongPasswordFailure extends Failure {
  const WrongPasswordFailure([super.detail]);
}

/// 当前平台不支持该能力。
final class UnsupportedFailure extends Failure {
  const UnsupportedFailure([super.detail]);
}

/// 无法归类的失败。
final class UnknownFailure extends Failure {
  const UnknownFailure([super.detail]);
}
