import 'package:drift/drift.dart' show QueryExecutor;
import 'package:drift/native.dart';
import 'package:ow_platform/ow_platform.dart';

/// 内存里的安全存储，行为与 [SecureSecretStore] 一致（键名必须以 `ow.` 开头）。
final class FakeSecretStore implements ClearableSecretStore {
  FakeSecretStore([Map<String, String>? initial]) : data = {...?initial};

  final Map<String, String> data;

  /// 设置后，所有读写都抛出它（模拟 Keystore、钥匙串故障）。
  Object? failWith;

  void _check(String key) {
    if (failWith != null) throw failWith!;
    if (!key.startsWith('ow.')) throw ArgumentError.value(key);
  }

  @override
  Future<void> write(String key, String value) async {
    _check(key);
    data[key] = value;
  }

  @override
  Future<String?> read(String key) async {
    _check(key);
    return data[key];
  }

  @override
  Future<void> delete(String key) async {
    _check(key);
    data.remove(key);
  }

  @override
  Future<void> clearAll() async {
    if (failWith != null) throw failWith!;
    data.removeWhere((k, _) => k.startsWith('ow.'));
  }
}

/// 用内存数据库代替 SQLCipher 文件的打开器；记录收到的密钥。
final class MemoryDatabaseOpener implements DatabaseOpener {
  MemoryDatabaseOpener({this.fileExists = false, this.failOpen = false});

  /// 模拟数据库文件是否已存在。
  bool fileExists;

  /// 为真时 `open` 抛出异常（模拟密钥不匹配、文件损坏）。
  bool failOpen;

  final openedKeys = <String>[];

  @override
  Future<bool> exists() async => fileExists;

  @override
  Future<QueryExecutor> open({required String keyHex}) async {
    openedKeys.add(keyHex);
    if (failOpen) throw StateError('模拟的打开失败');
    // 首次打开后文件就存在了。
    fileExists = true;
    return NativeDatabase.memory();
  }
}
