import '../asset/price.dart';
import '../core/equality.dart';

/// 主题偏好。
enum ThemePreference { system, light, dark }

/// 应用进入后台多久后需要重新解锁（PRD R19）。
enum AutoLock { immediately, after1Min, after5Min }

/// 应用设置。构造函数各参数的默认值即首次安装时的设置。
final class AppSettings {
  const AppSettings({
    this.quote = Quote.usd,
    this.hideSmall = true,
    this.hideAmounts = false,
    this.theme = ThemePreference.system,
    this.autoLock = AutoLock.immediately,
    this.appBiometrics = false,
    this.vaultBiometrics = false,
    this.lastBackupExportedAt,
    this.vaultChangedAt,
  });

  /// 计价货币，默认 USD。
  final Quote quote;

  /// 隐藏估值低于 1 USD 的币种（R11），默认开。
  final bool hideSmall;

  /// 全 app 金额显示为 `****`，默认关。
  final bool hideAmounts;

  /// 默认跟随系统。
  final ThemePreference theme;

  /// 默认立即（R19）。
  final AutoLock autoLock;

  /// 应用锁是否启用生物识别，默认关（首次引导中由用户选择开启，R18）。
  final bool appBiometrics;

  /// 保险库是否启用生物识别，默认关（设置主密码时由用户选择开启）。
  final bool vaultBiometrics;

  /// 上次导出加密备份的时间（UTC），从未导出为 null（R38）。
  final DateTime? lastBackupExportedAt;

  /// 保险库内容上次变化的时间（UTC），用于判断"有未备份的更改"（R38）。
  final DateTime? vaultChangedAt;

  /// 返回替换了指定字段的副本。两个时间字段显式传 null 可清除。
  AppSettings copyWith({
    Quote? quote,
    bool? hideSmall,
    bool? hideAmounts,
    ThemePreference? theme,
    AutoLock? autoLock,
    bool? appBiometrics,
    bool? vaultBiometrics,
    Object? lastBackupExportedAt = unset,
    Object? vaultChangedAt = unset,
  }) => AppSettings(
    quote: quote ?? this.quote,
    hideSmall: hideSmall ?? this.hideSmall,
    hideAmounts: hideAmounts ?? this.hideAmounts,
    theme: theme ?? this.theme,
    autoLock: autoLock ?? this.autoLock,
    appBiometrics: appBiometrics ?? this.appBiometrics,
    vaultBiometrics: vaultBiometrics ?? this.vaultBiometrics,
    lastBackupExportedAt: identical(lastBackupExportedAt, unset)
        ? this.lastBackupExportedAt
        : lastBackupExportedAt as DateTime?,
    vaultChangedAt: identical(vaultChangedAt, unset)
        ? this.vaultChangedAt
        : vaultChangedAt as DateTime?,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.quote == quote &&
      other.hideSmall == hideSmall &&
      other.hideAmounts == hideAmounts &&
      other.theme == theme &&
      other.autoLock == autoLock &&
      other.appBiometrics == appBiometrics &&
      other.vaultBiometrics == vaultBiometrics &&
      other.lastBackupExportedAt == lastBackupExportedAt &&
      other.vaultChangedAt == vaultChangedAt;

  @override
  int get hashCode => Object.hash(
    quote,
    hideSmall,
    hideAmounts,
    theme,
    autoLock,
    appBiometrics,
    vaultBiometrics,
    lastBackupExportedAt,
    vaultChangedAt,
  );
}
