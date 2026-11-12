import 'dart:io';

import 'package:drift/drift.dart'
    show OpeningDetails, QueryExecutor, QueryExecutorUser;
import 'package:flutter_test/flutter_test.dart';
import 'package:ow_platform/ow_platform.dart';

/// 在桌面环境用临时目录验证 SQLCipher 的加密行为。
/// 原生库由 sqlite3 的构建钩子按根 pubspec 的 user_defines 提供。
void main() {
  final key = 'a' * 64;
  final otherKey = 'b' * 64;
  late Directory dir;
  late SqlCipherDatabaseOpener opener;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('ow_db_test_');
    opener = SqlCipherDatabaseOpener(
      directoryProvider: () async => dir,
      inBackground: false,
    );
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> writeRow(String k) async {
    final db = await opener.open(keyHex: k);
    await db.ensureOpen(_NoUser());
    await db.runCustom('CREATE TABLE IF NOT EXISTS t (v TEXT)');
    await db.runInsert('INSERT INTO t (v) VALUES (?)', ['机密数据-xyz']);
    await db.close();
  }

  test('exists_文件不存在为假_打开并写入后为真', () async {
    expect(await opener.exists(), isFalse);
    await writeRow(key);
    expect(await opener.exists(), isTrue);
  });

  test('加密_文件头不是明文SQLite且搜不到写入的内容', () async {
    await writeRow(key);
    final bytes = File('${dir.path}/$databaseFileName').readAsBytesSync();
    expect(String.fromCharCodes(bytes.take(15)), isNot('SQLite format 3'));
    expect(String.fromCharCodes(bytes), isNot(contains('xyz')));
    expect(bytes.length, greaterThan(0));
  });

  test('同一密钥重新打开_数据仍在', () async {
    await writeRow(key);
    final db = await opener.open(keyHex: key);
    await db.ensureOpen(_NoUser());
    final rows = await db.runSelect('SELECT v FROM t', []);
    expect(rows.single['v'], '机密数据-xyz');
    await db.close();
  });

  test('错误密钥_打开失败且异常信息不含密钥', () async {
    await writeRow(key);
    final db = await opener.open(keyHex: otherKey);
    Object? error;
    try {
      await db.ensureOpen(_NoUser());
    } catch (e) {
      error = e;
    }
    expect(error, isNotNull);
    expect(error.toString(), isNot(contains(otherKey)));
    expect(error.toString(), isNot(contains(key)));
  });

  test('密钥格式不对_直接拒绝且不回显', () async {
    Object? error;
    try {
      await opener.open(keyHex: 'zz-secret');
    } catch (e) {
      error = e;
    }
    expect(error, isA<ArgumentError>());
    expect(error.toString(), isNot(contains('zz-secret')));
  });
}

class _NoUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}
