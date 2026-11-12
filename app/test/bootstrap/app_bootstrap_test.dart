import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/bootstrap/app_bootstrap.dart';
import 'package:onewallet/bootstrap/logger.dart';
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
}
