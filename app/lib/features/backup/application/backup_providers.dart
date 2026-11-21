import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../bootstrap/app_lock_providers.dart';
import '../domain/backup_file_handler.dart';

export '../domain/backup_file_handler.dart';

/// 基于成熟插件 share_plus 与 file_picker 的系统备份文件处理器。
///
/// 选型理由：
/// 1. share_plus 13.3.1: Flutter Community 维护的事实标准跨平台分享插件，支持通过系统 Share Sheet /
///    UIDocumentInteractionController 安全导出加密二进制文件，无需全局存储读写权限。
/// 2. file_picker 13.4.0: 跨平台标准文件选择器。Android 原生系统（SAF / MimeTypeMap）对非内置自定义后缀
///    （如 .owbak）的 MIME 解析可能为 null，导致过滤失效或文件置灰不可选。因此使用 [FileType.any]，
///    并在选取后于代码中校验 .owbak 扩展名与 OWBK 文件头魔数。
/// 3. 安全要求：只有加密后的 .owbak 密文字节落盘于应用私有临时目录的固定子目录 [backupExportSubdir]；
///    为避免 Android 接收端应用（如“文件”或网盘）异步读取未完成，分享完成后不在 finally 中立刻删除，
///    而在下次启动时或下次导出前统一清空该私有临时子目录。
class DefaultBackupFileHandler implements BackupFileHandler {
  const DefaultBackupFileHandler({this.runExternal});

  final Future<T> Function<T>(Future<T> Function() action)? runExternal;

  /// 备份导出文件存放的固定私有临时子目录名。
  static const String backupExportSubdir = 'ow_backup_export';

  /// 清空备份导出临时目录中的残留文件。在应用启动时及每次导出前调用。
  static Future<void> cleanTempExportDir() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final dir = Directory('${tempDir.path}/$backupExportSubdir');
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }

  @override
  Future<bool> shareFile({
    required Uint8List bytes,
    required String filename,
  }) async {
    final runner = runExternal ?? <T>(fn) => fn();
    return runner(() async {
      try {
        // 导出前先清空旧的导出子目录
        await cleanTempExportDir();

        final tempDir = await getTemporaryDirectory();
        final exportDir = Directory('${tempDir.path}/$backupExportSubdir');
        if (!await exportDir.exists()) {
          await exportDir.create(recursive: true);
        }
        final tempFile = File('${exportDir.path}/$filename');
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
      }
    });
  }

  @override
  Future<SelectedBackupFile?> pickBackupFile() async {
    final runner = runExternal ?? <T>(fn) => fn();
    return runner(() async {
      try {
        // Android 对自定义后缀可能无法匹配 MIME 类型，使用 FileType.any 允许用户选择任意文件，
        // 再在代码层检查 .owbak 扩展名和 OWBK 文件头魔数。
        final file = await FilePicker.pickFile(type: FileType.any);
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
    });
  }
}

/// 备份文件处理器 Provider。
final backupFileHandlerProvider = Provider<BackupFileHandler>((ref) {
  final appLockAsync = ref.watch(appLockStateMachineProvider);
  final runExternal = appLockAsync.asData?.value.runExternal;
  return DefaultBackupFileHandler(runExternal: runExternal);
});
