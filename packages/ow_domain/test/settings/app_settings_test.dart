import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

void main() {
  test('AppSettings_默认值_与规格一致', () {
    const s = AppSettings();
    expect(s.quote, Quote.usd);
    expect(s.hideSmall, isTrue);
    expect(s.hideAmounts, isFalse);
    expect(s.theme, ThemePreference.system);
    expect(s.autoLock, AutoLock.immediately);
    expect(s.appBiometrics, isFalse);
    expect(s.vaultBiometrics, isFalse);
    expect(s.lastBackupExportedAt, isNull);
    expect(s.vaultChangedAt, isNull);
  });

  test('AppSettings_copyWith_替换指定字段并可清除时间', () {
    final exported = DateTime.utc(2026, 3, 1);
    final s = const AppSettings().copyWith(
      quote: Quote.cny,
      lastBackupExportedAt: exported,
    );
    expect(s.quote, Quote.cny);
    expect(s.hideSmall, isTrue);
    expect(s.lastBackupExportedAt, exported);
    expect(s.copyWith(), s);
    expect(s.copyWith(lastBackupExportedAt: null).lastBackupExportedAt, isNull);
  });

  test('AppSettings_copyWith_替换其余字段并可清除变更时间', () {
    final changed = DateTime.utc(2026, 4, 2);
    const base = AppSettings();
    final s = base.copyWith(
      hideSmall: false,
      hideAmounts: true,
      theme: ThemePreference.dark,
      autoLock: AutoLock.after5Min,
      appBiometrics: true,
      vaultBiometrics: true,
      vaultChangedAt: changed,
    );
    expect(s.hideSmall, isFalse);
    expect(s.hideAmounts, isTrue);
    expect(s.theme, ThemePreference.dark);
    expect(s.autoLock, AutoLock.after5Min);
    expect(s.appBiometrics, isTrue);
    expect(s.vaultBiometrics, isTrue);
    expect(s.vaultChangedAt, changed);
    expect(s.quote, Quote.usd);
    expect(s.copyWith(vaultChangedAt: null).vaultChangedAt, isNull);
    expect(s.copyWith().vaultChangedAt, changed);
  });

  test('AppSettings_值相等_字段相同则相等且哈希相同', () {
    final t = DateTime.utc(2026, 4, 2);
    final a = AppSettings(quote: Quote.cny, lastBackupExportedAt: t);
    final b = AppSettings(quote: Quote.cny, lastBackupExportedAt: t);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(const AppSettings()));
    expect(a, isNot(AppSettings(quote: Quote.cny, vaultChangedAt: t)));
    expect(
      const AppSettings(theme: ThemePreference.light),
      isNot(const AppSettings(theme: ThemePreference.dark)),
    );
    expect(
      const AppSettings(hideAmounts: true),
      isNot(const AppSettings(hideAmounts: false)),
    );
    expect(
      const AppSettings(autoLock: AutoLock.after1Min),
      isNot(const AppSettings(autoLock: AutoLock.immediately)),
    );
    expect(const AppSettings(appBiometrics: true), isNot(const AppSettings()));
    expect(
      const AppSettings(vaultBiometrics: true),
      isNot(const AppSettings()),
    );
    expect(const AppSettings(hideSmall: false), isNot(const AppSettings()));
  });
}
