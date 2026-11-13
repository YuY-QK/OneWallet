import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ow_platform/ow_platform.dart';
import 'package:path/path.dart' as p;

/// 用系统临时目录验证保险库文件的原子写入、`.bak` 与中断后的恢复规则。
/// 内容都是假的字节，不是真正的保险库文件（存储层不感知格式）。
void main() {
  late Directory dir;
  late FileVaultStorage storage;

  Uint8List bytes(String s) => Uint8List.fromList(utf8.encode(s));
  File file(String name) => File(p.join(dir.path, name));
  String? contentOf(String name) =>
      file(name).existsSync() ? file(name).readAsStringSync() : null;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('ow_vault_storage_test_');
    storage = FileVaultStorage(directoryProvider: () async => dir);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('文件名_与SECURITY_DESIGN一致', () {
    expect(vaultFileName, 'vault.owv');
    expect(vaultBackupFileName, 'vault.owv.bak');
  });

  test('read_什么都没有_返回null', () async {
    expect(await storage.read(), isNull);
  });

  test('writeAtomic_首次写入_只有正式文件且没有备份与临时文件', () async {
    await storage.writeAtomic(bytes('v1'));
    expect(utf8.decode((await storage.read())!), 'v1');
    expect(contentOf(vaultFileName), 'v1');
    expect(contentOf(vaultBackupFileName), isNull);
    expect(contentOf(vaultTempFileName), isNull);
  });

  test('writeAtomic_目录不存在_自动创建', () async {
    final nested = Directory(p.join(dir.path, 'a', 'b'));
    final s = FileVaultStorage(directoryProvider: () async => nested);
    await s.writeAtomic(bytes('v1'));
    expect(utf8.decode((await s.read())!), 'v1');
  });

  test('writeAtomic_覆盖写入_备份是上一版', () async {
    await storage.writeAtomic(bytes('v1'));
    await storage.writeAtomic(bytes('v2'));
    expect(contentOf(vaultFileName), 'v2');
    expect(contentOf(vaultBackupFileName), 'v1');
    await storage.writeAtomic(bytes('v3'));
    expect(contentOf(vaultFileName), 'v3');
    expect(contentOf(vaultBackupFileName), 'v2');
    expect(contentOf(vaultTempFileName), isNull);
  });

  test('残局_临时文件已写好但改名前中断_读到原文件', () async {
    await storage.writeAtomic(bytes('old'));
    file(vaultTempFileName).writeAsStringSync('new');
    expect(utf8.decode((await storage.read())!), 'old');
    // 下一次写入覆盖残留的临时文件，正常完成。
    await storage.writeAtomic(bytes('newer'));
    expect(contentOf(vaultFileName), 'newer');
    expect(contentOf(vaultBackupFileName), 'old');
    expect(contentOf(vaultTempFileName), isNull);
  });

  test('残局_正式文件已改名为备份但新文件未就位_读到备份', () async {
    file(vaultBackupFileName).writeAsStringSync('old');
    file(vaultTempFileName).writeAsStringSync('new');
    expect(utf8.decode((await storage.read())!), 'old');
    // 下一次写入让正式文件重新就位，备份仍是更早的那一版。
    await storage.writeAtomic(bytes('newer'));
    expect(utf8.decode((await storage.read())!), 'newer');
    expect(contentOf(vaultBackupFileName), 'old');
    expect(contentOf(vaultTempFileName), isNull);
  });

  test('writeAtomic_写临时文件失败_原文件完好且抛出异常', () async {
    await storage.writeAtomic(bytes('old'));
    // 让临时文件的路径被一个目录占住，写入必然失败。
    Directory(p.join(dir.path, vaultTempFileName)).createSync();
    await expectLater(
      storage.writeAtomic(bytes('new')),
      throwsA(isA<FileSystemException>()),
    );
    expect(utf8.decode((await storage.read())!), 'old');
    expect(contentOf(vaultBackupFileName), isNull);
  });

  test('delete_清除正式文件备份与残留的临时文件', () async {
    await storage.writeAtomic(bytes('v1'));
    await storage.writeAtomic(bytes('v2'));
    file(vaultTempFileName).writeAsStringSync('partial');
    await storage.delete();
    expect(await storage.read(), isNull);
    expect(dir.listSync(), isEmpty);
    // 文件不存在时再删一次也不报错。
    await storage.delete();
  });

  test('delete_只剩备份时_也被删除不会复活', () async {
    file(vaultBackupFileName).writeAsStringSync('old');
    await storage.delete();
    expect(await storage.read(), isNull);
  });

  test('并发写入_串行执行互不破坏_最后调用的内容生效', () async {
    final payloads = [
      for (var i = 0; i < 8; i++) bytes('payload-$i-${'x' * 4096}'),
    ];
    final reads = <Future<Uint8List?>>[];
    final writes = <Future<void>>[];
    for (final payload in payloads) {
      writes.add(storage.writeAtomic(payload));
      reads.add(storage.read());
    }
    await Future.wait(writes);
    final seen = await Future.wait(reads);
    // 每次读取都得到某一次完整写入的内容，从不出现半截或交错的内容。
    for (final (i, r) in seen.indexed) {
      expect(r, payloads[i]);
    }
    expect(await storage.read(), payloads.last);
    expect(file(vaultBackupFileName).readAsBytesSync(), payloads[6]);
    expect(contentOf(vaultTempFileName), isNull);
  });

  test('writeAtomic_不修改传入的字节', () async {
    final data = bytes('immutable');
    final copy = Uint8List.fromList(data);
    await storage.writeAtomic(data);
    expect(data, copy);
  });
}
