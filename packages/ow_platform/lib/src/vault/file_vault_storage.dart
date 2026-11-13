import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:ow_domain/ow_domain.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 保险库文件名，位于应用支持目录（SECURITY_DESIGN 5.1）。
const vaultFileName = 'vault.owv';

/// 上一版本的备份文件名。
const vaultBackupFileName = 'vault.owv.bak';

/// 写入过程中的临时文件名（与正式文件同目录，保证改名是同一文件系统内的原子操作）。
const vaultTempFileName = 'vault.owv.tmp';

/// [VaultStorage] 的文件实现。
///
/// **写入**（[writeAtomic]）依次：
/// 1. 把新内容完整写入同目录的 `vault.owv.tmp`，并 `flush` 落盘；
/// 2. 若正式文件存在，把它改名为 `vault.owv.bak`（覆盖更早的备份）；
/// 3. 把临时文件改名为 `vault.owv`。
///
/// **读取的恢复规则**（[read]）：
/// - `vault.owv` 存在 → 读它（第 1 步后中断时，残留的临时文件被忽略，下次写入覆盖）；
/// - `vault.owv` 不存在而 `vault.owv.bak` 存在 → 读 `.bak`。这正是写入在第 2、3 步
///   之间中断的残局：正式文件已改名为备份、新文件尚未就位。此时那次写入没有返回
///   成功，读到上一版是正确的语义；下一次写入会让正式文件重新就位；
/// - 都不存在 → null。
///
/// [delete] 依次删除临时文件、备份、正式文件——正式文件最后删，删到一半中断时
/// 不会因为只剩 `.bak` 而让已删除的保险库"复活"。
///
/// 同一实例上的读、写、删串行执行。只应有一个实例管理同一目录。
///
/// 已知局限：Dart 无法对目录执行 fsync，改名在断电时能否持久依赖文件系统
/// （iOS 的 APFS、Android 的 ext4/f2fs 默认的日志行为下改名是原子的）。
/// 已记入真机测试清单第 8 节。
final class FileVaultStorage implements VaultStorage {
  /// [directoryProvider] 默认是应用支持目录；测试可传入临时目录。
  FileVaultStorage({Future<Directory> Function()? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directoryProvider;
  Future<void> _tail = Future<void>.value();

  /// 按调用顺序串行执行。
  Future<T> _serial<T>(Future<T> Function() action) {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    return previous.then((_) => action()).whenComplete(done.complete);
  }

  Future<({File main, File backup, File temp})> _files() async {
    final dir = await _directoryProvider();
    return (
      main: File(p.join(dir.path, vaultFileName)),
      backup: File(p.join(dir.path, vaultBackupFileName)),
      temp: File(p.join(dir.path, vaultTempFileName)),
    );
  }

  @override
  Future<Uint8List?> read() => _serial(() async {
    final files = await _files();
    if (await files.main.exists()) return files.main.readAsBytes();
    if (await files.backup.exists()) return files.backup.readAsBytes();
    return null;
  });

  @override
  Future<void> writeAtomic(Uint8List bytes) => _serial(() async {
    final files = await _files();
    await files.main.parent.create(recursive: true);
    final handle = await files.temp.open(mode: FileMode.write);
    try {
      await handle.writeFrom(bytes);
      await handle.flush();
    } finally {
      await handle.close();
    }
    if (await files.main.exists()) {
      await files.main.rename(files.backup.path);
    }
    await files.temp.rename(files.main.path);
  });

  @override
  Future<void> delete() => _serial(() async {
    final files = await _files();
    for (final file in [files.temp, files.backup, files.main]) {
      if (await file.exists()) await file.delete();
    }
  });
}
