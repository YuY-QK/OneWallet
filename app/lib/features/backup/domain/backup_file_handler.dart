import 'dart:typed_data';

/// 选取的文件信息。
final class SelectedBackupFile {
  const SelectedBackupFile({required this.bytes, required this.name});

  final Uint8List bytes;
  final String name;
}

/// 备份文件分享与选取抽象接口（M5-03、M5-04）。
///
/// 遵循无外部依赖原则：在界面与系统文件选择器/分享面板之间解耦，
/// 允许单元测试注入 Mock，同时方便后续接入原生平台通道或平台插件。
abstract interface class BackupFileHandler {
  /// 调起系统分享面板或保存文件。
  ///
  /// 返回保存或分享是否成功。
  Future<bool> shareFile({required Uint8List bytes, required String filename});

  /// 调起系统文件选择器，选取 .owbak 备份文件。
  Future<SelectedBackupFile?> pickBackupFile();
}
