import 'dart:typed_data';

import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

final class FakeDatabaseCloser implements DatabaseCloser {
  FakeDatabaseCloser(this.log);
  final List<String> log;

  @override
  Future<void> close() async {
    log.add('close');
  }
}

final class FakeDatabaseDeleter implements DatabaseDeleter {
  FakeDatabaseDeleter(this.log);
  final List<String> log;

  @override
  Future<void> delete() async {
    log.add('deleteDb');
  }
}

final class FakeVaultStorage implements VaultStorage {
  FakeVaultStorage(this.log);
  final List<String> log;

  @override
  Future<void> delete() async {
    log.add('deleteVault');
  }

  @override
  Future<Uint8List?> read() async => null;

  @override
  Future<void> writeAtomic(Uint8List bytes) async {}
}

final class FakeClearableSecretStore implements ClearableSecretStore {
  FakeClearableSecretStore(this.log);
  final List<String> log;
  final Map<String, String> data = {};

  @override
  Future<void> clearAll() async {
    log.add('clearSecrets');
    data.clear();
  }

  @override
  Future<void> delete(String key) async => data.remove(key);

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;
}

void main() {
  group('WipeAllData', () {
    test('严格按顺序执行：关闭连接、删除数据库文件、删除保险库与清空安全存储', () async {
      final log = <String>[];
      final closer = FakeDatabaseCloser(log);
      final deleter = FakeDatabaseDeleter(log);
      final vault = FakeVaultStorage(log);
      final secrets = FakeClearableSecretStore(log);

      final usecase = WipeAllData(
        closer: closer,
        databaseDeleter: deleter,
        vaultStorage: vault,
        secrets: secrets,
      );

      final result = await usecase();
      expect(result.isOk, isTrue);
      expect(log, ['close', 'deleteDb', 'deleteVault', 'clearSecrets']);
    });

    test('closer为空时_正常执行删库、删保险库与清安全存储', () async {
      final log = <String>[];
      final deleter = FakeDatabaseDeleter(log);
      final vault = FakeVaultStorage(log);
      final secrets = FakeClearableSecretStore(log);

      final usecase = WipeAllData(
        databaseDeleter: deleter,
        vaultStorage: vault,
        secrets: secrets,
      );

      final result = await usecase();
      expect(result.isOk, isTrue);
      expect(log, ['deleteDb', 'deleteVault', 'clearSecrets']);
    });

    test('也可在call时动态传入closer覆盖构造函数closer', () async {
      final log = <String>[];
      final closer = FakeDatabaseCloser(log);
      final deleter = FakeDatabaseDeleter(log);

      final usecase = WipeAllData(databaseDeleter: deleter);

      final result = await usecase(closer: closer);
      expect(result.isOk, isTrue);
      expect(log, ['close', 'deleteDb']);
    });
  });
}
