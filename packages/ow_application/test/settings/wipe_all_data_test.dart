import 'dart:typed_data';

import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

final class FakeDatabaseWiper implements DatabaseWiper {
  int wipeCount = 0;

  @override
  Future<void> wipe() async {
    wipeCount++;
  }
}

final class FakeVaultStorage implements VaultStorage {
  int deleteCount = 0;

  @override
  Future<void> delete() async {
    deleteCount++;
  }

  @override
  Future<Uint8List?> read() async => null;

  @override
  Future<void> writeAtomic(Uint8List bytes) async {}
}

final class FakeClearableSecretStore implements ClearableSecretStore {
  int clearAllCount = 0;
  final Map<String, String> data = {};

  @override
  Future<void> clearAll() async {
    clearAllCount++;
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
    test('依次执行数据库清空、保险库删除与安全存储清理', () async {
      final wiper = FakeDatabaseWiper();
      final vault = FakeVaultStorage();
      final secrets = FakeClearableSecretStore();

      final usecase = WipeAllData(
        databaseWiper: wiper,
        vaultStorage: vault,
        secrets: secrets,
      );

      final result = await usecase();
      expect(result.isOk, isTrue);
      expect(wiper.wipeCount, 1);
      expect(vault.deleteCount, 1);
      expect(secrets.clearAllCount, 1);
    });

    test('vaultStorage与secrets可为空并正常完成', () async {
      final wiper = FakeDatabaseWiper();
      final usecase = WipeAllData(databaseWiper: wiper);

      final result = await usecase();
      expect(result.isOk, isTrue);
      expect(wiper.wipeCount, 1);
    });
  });
}
