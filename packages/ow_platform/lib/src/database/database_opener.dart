import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// 打开主数据库 `onewallet.db`（SQLCipher 加密）。
///
/// 抽成接口是为了让启动流程在测试中换成内存数据库。
abstract interface class DatabaseOpener {
  /// 数据库文件是否已经存在。首次启动判断（清理钥匙串残留）用。
  Future<bool> exists();

  /// 用 [keyHex]（64 位十六进制，即 32 字节原始密钥）打开数据库。
  ///
  /// 数据库在首次执行语句时才真正打开；密钥错误、不是 SQLCipher 构建等
  /// 失败会在那时以异常出现，由调用方（启动流程）捕获并显示错误页，
  /// 不得自动删除或重建数据库。异常信息不含密钥。
  Future<QueryExecutor> open({required String keyHex});
}

/// 数据库文件名，位于应用支持目录。
const databaseFileName = 'onewallet.db';

/// 基于 `sqlite3` 的 SQLCipher 构建与 drift `NativeDatabase` 的实现。
///
/// SQLCipher 通过根 `pubspec.yaml` 的 `hooks.user_defines.sqlite3.source:
/// sqlcipher` 选定（见 ADR_006）。打开时：
/// 1. `PRAGMA key = "x'<hex>'"` 使用原始密钥格式，跳过口令派生；
/// 2. `PRAGMA cipher_version` 必须有返回值，否则说明链接的是普通 SQLite，
///    抛异常拒绝打开（否则会写出未加密的库）；
/// 3. 读一次 `sqlite_master`，密钥不对会在此失败。
///
/// 在设备上才能验证原生部分；桌面环境的单元测试可用 [directoryProvider]
/// 指定临时目录来验证加密行为。
final class SqlCipherDatabaseOpener implements DatabaseOpener {
  SqlCipherDatabaseOpener({
    Future<Directory> Function()? directoryProvider,
    this.inBackground = true,
  }) : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directoryProvider;

  /// 是否在后台 isolate 中运行数据库。生产为 true；测试可设为 false。
  final bool inBackground;

  static final _keyPattern = RegExp(r'^[0-9a-fA-F]{64}$');

  Future<File> _file() async {
    final dir = await _directoryProvider();
    return File(p.join(dir.path, databaseFileName));
  }

  @override
  Future<bool> exists() async => (await _file()).exists();

  @override
  Future<QueryExecutor> open({required String keyHex}) async {
    if (!_keyPattern.hasMatch(keyHex)) {
      // 不回显传入的值。
      throw ArgumentError('数据库密钥必须是 64 位十六进制字符串');
    }
    final file = await _file();
    await file.parent.create(recursive: true);
    final setup = _buildSetup(keyHex);
    return inBackground
        ? NativeDatabase.createInBackground(file, setup: setup)
        : NativeDatabase(file, setup: setup);
  }
}

/// 在连接建立后立即执行的设置。只捕获 [keyHex] 一个字符串，可发送到后台 isolate。
void Function(sqlite.Database) _buildSetup(String keyHex) {
  return (sqlite.Database db) {
    try {
      db.execute('PRAGMA key = "x\'$keyHex\'";');
    } on sqlite.SqliteException {
      // 异常的文本里带有语句，不能向外传递。
      throw StateError('设置数据库密钥失败');
    }
    final version = db.select('PRAGMA cipher_version;');
    final value = version.isEmpty ? null : version.first.values.first;
    if (value is! String || value.isEmpty) {
      throw StateError('当前 SQLite 不是 SQLCipher 构建，拒绝打开未加密的数据库');
    }
    try {
      db.select('SELECT count(*) FROM sqlite_master;');
    } on sqlite.SqliteException {
      throw StateError('数据库无法用当前密钥解密，或文件已损坏');
    }
  };
}
