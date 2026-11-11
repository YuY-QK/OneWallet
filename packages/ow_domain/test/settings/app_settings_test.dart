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
}
