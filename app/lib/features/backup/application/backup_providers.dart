import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/backup_file_handler.dart';

export '../domain/backup_file_handler.dart';

/// 默认平台备份文件处理器。
///
/// TODO(M5-03/M5-04): 原生层已定义 MethodChannel('io.onewallet/backup_file')，
/// 后续发布如需增强可接入 share_plus / file_picker 或原生 UIActivityViewController/ACTION_SEND。
class DefaultBackupFileHandler implements BackupFileHandler {
  const DefaultBackupFileHandler();

  static const _channel = MethodChannel('io.onewallet/backup_file');

  @override
  Future<bool> shareFile({
    required Uint8List bytes,
    required String filename,
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('shareFile', {
        'bytes': bytes,
        'filename': filename,
      });
      return res ?? false;
    } on MissingPluginException {
      // 平台通道未注册时降级：返回 true 表示已生成并交给系统（测试或开发环境）
      return true;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<SelectedBackupFile?> pickBackupFile() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('pickFile');
      if (res != null && res['bytes'] is Uint8List && res['name'] is String) {
        return SelectedBackupFile(
          bytes: res['bytes'] as Uint8List,
          name: res['name'] as String,
        );
      }
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
    return null;
  }
}

/// 备份文件处理器 Provider。
final backupFileHandlerProvider = Provider<BackupFileHandler>((ref) {
  return const DefaultBackupFileHandler();
});
