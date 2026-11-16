import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/bootstrap/app_bootstrap.dart';
import 'package:onewallet/bootstrap/logger.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_data/ow_data.dart';

import 'support.dart';

void main() {
  late FakeSecretStore secrets;
  late MemoryDatabaseOpener opener;
  late List<OwLogRecord> logs;
  late OwLogger logger;
  final hex64 = RegExp(r'^[0-9a-f]{64}$');

  setUp(() {
    secrets = FakeSecretStore();
    opener = MemoryDatabaseOpener();
    logs = [];
    logger = OwLogger(minLevel: OwLogLevel.debug, sink: logs.add);
  });

  Future<BootstrapResult> boot() =>
      bootstrapApp(secrets: secrets, opener: opener, logger: logger);

  test('首次启动_生成64位十六进制密钥并写入_数据库可用', () async {
    final result = await boot();

    expect(result, isA<BootstrapSuccess>());
    final key = secrets.data[databaseKeyStoreKey];
    expect(key, matches(hex64));
    expect(opener.openedKeys, [key]);

    final db = (result as BootstrapSuccess).database;
    expect(await OwRepositories(db).settings.watch().first, isNotNull);
    await db.close();
  });

  test('第二次启动_复用同一密钥', () async {
    final first = await boot() as BootstrapSuccess;
    final key = secrets.data[databaseKeyStoreKey];
    await first.database.close();

    final second = await boot();
    expect(second, isA<BootstrapSuccess>());
    expect(secrets.data[databaseKeyStoreKey], key);
    expect(opener.openedKeys, [key, key]);
    await (second as BootstrapSuccess).database.close();
  });

  test('两次全新启动_密钥不同', () async {
    final a = await boot() as BootstrapSuccess;
    final keyA = secrets.data[databaseKeyStoreKey];
    await a.database.close();

    secrets = FakeSecretStore();
    opener = MemoryDatabaseOpener();
    final b = await boot() as BootstrapSuccess;
    expect(secrets.data[databaseKeyStoreKey], isNot(keyA));
    await b.database.close();
  });

  test('数据库文件不存在_先清除残留的ow前缀条目再生成新密钥', () async {
    secrets = FakeSecretStore({
      'ow.db.key': 'f' * 64,
      'ow.datasource.alchemy.key': '旧的残留',
      'other.keep': '保留',
    });

    final result = await boot();

    expect(result, isA<BootstrapSuccess>());
    expect(secrets.data.containsKey('ow.datasource.alchemy.key'), isFalse);
    expect(secrets.data['ow.db.key'], isNot('f' * 64));
    expect(secrets.data['ow.db.key'], matches(hex64));
    expect(secrets.data['other.keep'], '保留');
    await (result as BootstrapSuccess).database.close();
  });

  test('数据库文件存在_不清除其他条目', () async {
    opener.fileExists = true;
    secrets = FakeSecretStore({
      databaseKeyStoreKey: 'a' * 64,
      'ow.datasource.alchemy.key': 'k',
    });

    final result = await boot();

    expect(result, isA<BootstrapSuccess>());
    expect(secrets.data['ow.datasource.alchemy.key'], 'k');
    expect(opener.openedKeys, ['a' * 64]);
    await (result as BootstrapSuccess).database.close();
  });

  test('数据库存在但密钥缺失_失败且不打开不重建', () async {
    opener.fileExists = true;
    secrets = FakeSecretStore({'ow.datasource.alchemy.key': 'k'});

    final result = await boot();

    expect(
      result,
      isA<BootstrapFailure>().having(
        (f) => f.kind,
        'kind',
        BootstrapFailureKind.databaseKeyMissing,
      ),
    );
    expect(opener.openedKeys, isEmpty);
    expect(secrets.data.containsKey(databaseKeyStoreKey), isFalse);
    expect(secrets.data['ow.datasource.alchemy.key'], 'k');
  });

  test('数据库打不开_返回失败且不清除密钥', () async {
    opener = MemoryDatabaseOpener(failOpen: true);
    final result = await boot();

    expect(
      result,
      isA<BootstrapFailure>().having(
        (f) => f.kind,
        'kind',
        BootstrapFailureKind.databaseOpenFailed,
      ),
    );
    expect(secrets.data[databaseKeyStoreKey], matches(hex64));
  });

  test('安全存储故障_返回失败', () async {
    secrets.failWith = StateError('keystore down');
    final result = await boot();
    expect(
      result,
      isA<BootstrapFailure>().having(
        (f) => f.kind,
        'kind',
        BootstrapFailureKind.secureStorageFailed,
      ),
    );
  });

  test('日志不含数据库密钥', () async {
    final ok = await boot() as BootstrapSuccess;
    final key = secrets.data[databaseKeyStoreKey]!;
    await ok.database.close();
    opener = MemoryDatabaseOpener(fileExists: true, failOpen: true);
    await boot();

    expect(logs, isNotEmpty);
    for (final r in logs) {
      expect(r.message, isNot(contains(key)));
    }
  });

  test('WipeAllData 清除后再次启动_成功且为全新启动状态而不是 databaseKeyMissing', () async {
    // 1. 首次正常启动并写入数据
    final first = await boot() as BootstrapSuccess;
    final initialKey = secrets.data[databaseKeyStoreKey];
    expect(initialKey, matches(hex64));
    expect(opener.fileExists, isTrue);

    // 写入残留凭据
    await secrets.write('ow.datasource.alchemy.key', 'some_key');

    // 2. 执行 WipeAllData（关闭连接、删数据库文件、删保险库与清空安全存储）
    final fakeVault = FakeVaultStorage();
    final wipeAll = WipeAllData(
      closer: first.database,
      databaseDeleter: opener,
      vaultStorage: fakeVault,
      secrets: secrets,
    );
    final wipeResult = await wipeAll();
    expect(wipeResult.isOk, isTrue);

    // 断言数据库文件已被删除、安全存储已被清空
    expect(opener.fileExists, isFalse);
    expect(fakeVault.deleteCount, 1);
    expect(secrets.data.isEmpty, isTrue);

    // 3. 再次启动，必须成功且为全新启动，而不是 databaseKeyMissing
    final second = await boot();
    expect(second, isA<BootstrapSuccess>());
    final newKey = secrets.data[databaseKeyStoreKey];
    expect(newKey, isNotNull);
    expect(newKey, matches(hex64));
    expect(newKey, isNot(initialKey));
    await (second as BootstrapSuccess).database.close();
  });
}
