import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/backup_file_handler.dart';

export '../domain/backup_file_handler.dart';

/// 基于成熟插件 share_plus 与 file_picker 的系统备份文件处理器。
///
/// 选型理由：
/// 1. share_plus 13.3.1: Flutter Community 维护的事实标准跨平台分享插件，支持通过系统 Share Sheet /
///    UIDocumentInteractionController 安全导出加密二进制文件，无需全局存储读写权限。
/// 2. file_picker 13.4.0: 跨平台标准文件选择器，支持限定 .owbak 自定义后缀，通过原生
///    UIDocumentPickerViewController (iOS) 和 ACTION_OPEN_DOCUMENT (Android SAF) 选取，
///    确保只读访问用户选中的文件。
/// 3. 安全要求：只有加密后的 .owbak 密文字节落盘于应用私有临时目录供分享，分享结束后立即在 finally 中删除。
class DefaultBackupFileHandler implements BackupFileHandler {
  const DefaultBackupFileHandler();

  @override
  Future<bool> shareFile({
    required Uint8List bytes,
    required String filename,
  }) async {
    File? tempFile;
    try {
      final tempDir = await getTemporaryDirectory();
      tempFile = File('${tempDir.path}/$filename');
      await tempFile.writeAsBytes(bytes, flush: true);

      final xFile = XFile(
        tempFile.path,
        mimeType: 'application/octet-stream',
        name: filename,
      );
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          subject: filename,
          text: 'OneWallet 加密备份文件',
        ),
      );
      return result.status == ShareResultStatus.success;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    } finally {
      if (tempFile != null) {
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (_) {}
      }
    }
  }

  @override
  Future<SelectedBackupFile?> pickBackupFile() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['owbak'],
      );
      if (file == null) {
        return null;
      }
      final bytes = await file.readAsBytes();
      return SelectedBackupFile(bytes: bytes, name: file.name);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    } catch (_) {
      return null;
    }
  }
}

/// 备份文件处理器 Provider。
final backupFileHandlerProvider = Provider<BackupFileHandler>((ref) {
  return const DefaultBackupFileHandler();
});
