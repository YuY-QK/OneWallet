import 'package:ow_domain/ow_domain.dart';

/// 确认备份已保存（规格 5.2 节）。
///
/// 设 `settings.lastBackupExportedAt = now`。
final class ConfirmBackupSaved {
  ConfirmBackupSaved({required this.settings, required this.clock});

  final SettingsRepository settings;
  final Clock clock;

  Future<void> call() =>
      settings.update((s) => s.copyWith(lastBackupExportedAt: clock.nowUtc()));
}
