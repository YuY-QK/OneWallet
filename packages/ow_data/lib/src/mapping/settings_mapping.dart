import 'package:ow_domain/ow_domain.dart';

// 设置以键值对存放。读取约定：键缺失或值无法识别时，该项回落到 AppSettings 的
// 默认值（不抛异常、不丢弃其他项）；因此首次读取得到的就是默认设置。

const _kQuote = 'quote';
const _kHideSmall = 'hide_small';
const _kHideAmounts = 'hide_amounts';
const _kTheme = 'theme';
const _kAutoLock = 'auto_lock';
const _kAppBiometrics = 'app_biometrics';
const _kVaultBiometrics = 'vault_biometrics';
const _kLastBackupExportedAt = 'last_backup_exported_at';
const _kVaultChangedAt = 'vault_changed_at';

/// 全部设置键。
const settingKeys = [
  _kQuote,
  _kHideSmall,
  _kHideAmounts,
  _kTheme,
  _kAutoLock,
  _kAppBiometrics,
  _kVaultBiometrics,
  _kLastBackupExportedAt,
  _kVaultChangedAt,
];

T _enumOr<T extends Enum>(List<T> values, String? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

bool _boolOr(String? text, {required bool fallback}) =>
    text == 'true' ? true : (text == 'false' ? false : fallback);

DateTime? _date(String? text) =>
    text == null ? null : DateTime.tryParse(text)?.toUtc();

/// 键值表 → 设置对象。
AppSettings settingsFromMap(Map<String, String> m) {
  const d = AppSettings();
  return AppSettings(
    quote: _enumOr(Quote.values, m[_kQuote], d.quote),
    hideSmall: _boolOr(m[_kHideSmall], fallback: d.hideSmall),
    hideAmounts: _boolOr(m[_kHideAmounts], fallback: d.hideAmounts),
    theme: _enumOr(ThemePreference.values, m[_kTheme], d.theme),
    autoLock: _enumOr(AutoLock.values, m[_kAutoLock], d.autoLock),
    appBiometrics: _boolOr(m[_kAppBiometrics], fallback: d.appBiometrics),
    vaultBiometrics: _boolOr(m[_kVaultBiometrics], fallback: d.vaultBiometrics),
    lastBackupExportedAt: _date(m[_kLastBackupExportedAt]),
    vaultChangedAt: _date(m[_kVaultChangedAt]),
  );
}

/// 设置对象 → 键值表；值为 null 的键表示应删除该行。
Map<String, String?> settingsToMap(AppSettings s) => {
  _kQuote: s.quote.name,
  _kHideSmall: '${s.hideSmall}',
  _kHideAmounts: '${s.hideAmounts}',
  _kTheme: s.theme.name,
  _kAutoLock: s.autoLock.name,
  _kAppBiometrics: '${s.appBiometrics}',
  _kVaultBiometrics: '${s.vaultBiometrics}',
  _kLastBackupExportedAt: s.lastBackupExportedAt?.toUtc().toIso8601String(),
  _kVaultChangedAt: s.vaultChangedAt?.toUtc().toIso8601String(),
};
