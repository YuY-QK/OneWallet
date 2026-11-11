import '../core/equality.dart';

/// 钱包账户的备份标记（PRD R34–R36）。由用户自行标记，app 不做核验。
final class BackupStatus {
  const BackupStatus({
    this.offlineBackedUp = false,
    this.offlineVerifiedAt,
    this.keyless = false,
  });

  /// 用户标记"我有纸质或其他离线备份"。
  final bool offlineBackedUp;

  /// 上次核对离线备份的时间（UTC），未核对过为 null（R36）。
  final DateTime? offlineVerifiedAt;

  /// 用户标记为无助记词钱包（MPC、社交登录型，无法导出）。
  final bool keyless;

  /// 返回替换了指定字段的副本。[offlineVerifiedAt] 显式传 null 可清除。
  BackupStatus copyWith({
    bool? offlineBackedUp,
    Object? offlineVerifiedAt = unset,
    bool? keyless,
  }) => BackupStatus(
    offlineBackedUp: offlineBackedUp ?? this.offlineBackedUp,
    offlineVerifiedAt: identical(offlineVerifiedAt, unset)
        ? this.offlineVerifiedAt
        : offlineVerifiedAt as DateTime?,
    keyless: keyless ?? this.keyless,
  );

  @override
  bool operator ==(Object other) =>
      other is BackupStatus &&
      other.offlineBackedUp == offlineBackedUp &&
      other.offlineVerifiedAt == offlineVerifiedAt &&
      other.keyless == keyless;

  @override
  int get hashCode => Object.hash(offlineBackedUp, offlineVerifiedAt, keyless);
}

/// 备份清单中钱包账户的状态（PRD R34、R35）。
enum BackupLevel {
  /// 已关联保险库中的密钥条目。
  inVault,

  /// 只有用户标记的离线备份。
  offlineOnly,

  /// 两者皆有（推荐状态，R35）。
  inVaultAndOffline,

  /// 无助记词钱包，无法备份。
  keyless,

  /// 以上皆非。
  none,
}
