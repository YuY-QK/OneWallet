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

/// [DuplicateAddressFailure] 的三种情形。
enum DuplicateAddressKind {
  /// 地址已属于某个账户（[DuplicateAddressFailure.existingAccountName] 非 null）。
  existing,

  /// 在同一次输入中出现了不止一次。
  withinInput,

  /// 地址已在库中，但所属账户不存在（数据异常）；没有账户名可显示。
  ownerMissing,
}

/// 添加的地址与已有地址重复（PRD R2），或在同一次输入中重复。
///
/// 界面据此提示"该地址已属于某某账户"、"本次输入中重复"或（数据异常时）
/// "该地址已存在于本应用中"。字段只含缩略地址与账户名，不含任何密钥类数据。
final class DuplicateAddressFailure extends Failure {
  /// [existingAccountName] 非 null：地址已属于该账户。为 null 时，[ownerMissing] 为
  /// true 表示地址在库中但所属账户不存在，否则表示本次输入内部的重复。
  const DuplicateAddressFailure({
    required this.shortAddress,
    this.existingAccountName,
    this.ownerMissing = false,
    String? detail,
  }) : assert(
         existingAccountName == null || !ownerMissing,
         '有账户名时不能同时标记所属账户缺失',
       ),
       super(detail);

  /// 重复地址的缩略形式（见 `AddressCodec.shorten`）。
  final String shortAddress;

  /// 该地址已属于的账户名；为 null 表示没有可显示的账户名
  /// （本次输入内部的重复，或所属账户缺失）。
  final String? existingAccountName;

  /// 地址已在库中但所属账户不存在（数据异常）。
  final bool ownerMissing;

  /// 属于哪一种情形。
  DuplicateAddressKind get kind => existingAccountName != null
      ? DuplicateAddressKind.existing
      : ownerMissing
      ? DuplicateAddressKind.ownerMissing
      : DuplicateAddressKind.withinInput;

  /// 是否为本次输入内部的重复。
  bool get isWithinInput => kind == DuplicateAddressKind.withinInput;
}

/// 密码或 PIN 错误。
final class WrongPasswordFailure extends Failure {
  const WrongPasswordFailure([super.detail]);
}

/// 保险库文件（或其中某条密文）损坏、被篡改，或不是保险库文件。
///
/// 认证加密校验失败、文件结构不合法、格式标识不对时返回。[detail] 只写固定的
/// 原因标记（如 `aead_auth_failed`），不含任何文件内容。
final class VaultCorruptedFailure extends Failure {
  const VaultCorruptedFailure([super.detail]);
}

/// [UnsupportedFailure] 的原因。
enum UnsupportedReason {
  /// 当前设备或平台不支持该能力。
  platform,

  /// 该链或交易所（或其某项能力）尚未接入。
  notIntegrated,
}

/// 不支持：当前设备不支持该能力，或该链、交易所尚未接入。
final class UnsupportedFailure extends Failure {
  /// 当前设备或平台不支持（[UnsupportedReason.platform]）。
  const UnsupportedFailure([super.detail])
    : reason = UnsupportedReason.platform;

  /// 该链或交易所尚未接入（[UnsupportedReason.notIntegrated]）。
  const UnsupportedFailure.notIntegrated([super.detail])
    : reason = UnsupportedReason.notIntegrated;

  /// 不支持的原因；默认 [UnsupportedReason.platform]。
  final UnsupportedReason reason;
}

/// 无法归类的失败。
final class UnknownFailure extends Failure {
  const UnknownFailure([super.detail]);
}
