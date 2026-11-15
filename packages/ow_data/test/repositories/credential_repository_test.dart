import 'package:ow_data/ow_data.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

final class _MemorySecretStore implements SecretStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

void main() {
  group('SecretStoreCredentialRepository', () {
    late _MemorySecretStore store;
    late SecretStoreCredentialRepository repo;

    setUp(() {
      store = _MemorySecretStore();
      repo = SecretStoreCredentialRepository(store);
    });

    test('save 与 load_含Passphrase_正确往返', () async {
      final creds = ExchangeCredentials(
        apiKey: Sensitive.fromString('binance-key-123'),
        apiSecret: Sensitive.fromString('binance-secret-456'),
        passphrase: Sensitive.fromString('okx-pass-789'),
      );

      await repo.save('acc-1', creds);

      expect(store.values['ow.exchange.acc-1.key'], 'binance-key-123');
      expect(store.values['ow.exchange.acc-1.secret'], 'binance-secret-456');
      expect(store.values['ow.exchange.acc-1.passphrase'], 'okx-pass-789');

      final loaded = await repo.load('acc-1');
      expect(loaded, isNotNull);
      expect(loaded!.apiKey.useString((s) => s), 'binance-key-123');
      expect(loaded.apiSecret.useString((s) => s), 'binance-secret-456');
      expect(loaded.passphrase?.useString((s) => s), 'okx-pass-789');
    });

    test('save 与 load_不含Passphrase_正确往返且passphrase为null', () async {
      final creds = ExchangeCredentials(
        apiKey: Sensitive.fromString('my-key'),
        apiSecret: Sensitive.fromString('my-secret'),
      );

      await repo.save('acc-2', creds);

      expect(store.values['ow.exchange.acc-2.key'], 'my-key');
      expect(store.values['ow.exchange.acc-2.secret'], 'my-secret');
      expect(store.values.containsKey('ow.exchange.acc-2.passphrase'), isFalse);

      final loaded = await repo.load('acc-2');
      expect(loaded, isNotNull);
      expect(loaded!.apiKey.useString((s) => s), 'my-key');
      expect(loaded.apiSecret.useString((s) => s), 'my-secret');
      expect(loaded.passphrase, isNull);
    });

    test('save_更新去掉Passphrase_旧Passphrase被删除', () async {
      await repo.save(
        'acc-3',
        ExchangeCredentials(
          apiKey: Sensitive.fromString('k'),
          apiSecret: Sensitive.fromString('s'),
          passphrase: Sensitive.fromString('p'),
        ),
      );
      expect(store.values['ow.exchange.acc-3.passphrase'], 'p');

      await repo.save(
        'acc-3',
        ExchangeCredentials(
          apiKey: Sensitive.fromString('k2'),
          apiSecret: Sensitive.fromString('s2'),
        ),
      );
      expect(store.values.containsKey('ow.exchange.acc-3.passphrase'), isFalse);

      final loaded = await repo.load('acc-3');
      expect(loaded!.apiKey.useString((s) => s), 'k2');
      expect(loaded.apiSecret.useString((s) => s), 's2');
      expect(loaded.passphrase, isNull);
    });

    test('load_缺失key或secret时返回null', () async {
      await store.write('ow.exchange.acc-4.key', 'only-key');
      expect(await repo.load('acc-4'), isNull);

      await store.delete('ow.exchange.acc-4.key');
      await store.write('ow.exchange.acc-4.secret', 'only-secret');
      expect(await repo.load('acc-4'), isNull);

      expect(await repo.load('acc-non-existent'), isNull);
    });

    test('delete_删除全部三个存储项', () async {
      await repo.save(
        'acc-5',
        ExchangeCredentials(
          apiKey: Sensitive.fromString('k'),
          apiSecret: Sensitive.fromString('s'),
          passphrase: Sensitive.fromString('p'),
        ),
      );

      expect(store.values.length, 3);
      await repo.delete('acc-5');
      expect(store.values, isEmpty);

      // 再次删除不存在的 key 不报错
      await repo.delete('acc-5');
    });

    test('参数校验_空accountId抛出ArgumentError', () {
      expect(
        () => repo.save(
          '',
          ExchangeCredentials(
            apiKey: Sensitive.fromString('k'),
            apiSecret: Sensitive.fromString('s'),
          ),
        ),
        throwsArgumentError,
      );
      expect(() => repo.load(''), throwsArgumentError);
      expect(() => repo.delete(''), throwsArgumentError);
    });

    test('toString_不泄漏任何内部信息', () {
      expect(repo.toString(), 'SecretStoreCredentialRepository');
    });
  });
}
