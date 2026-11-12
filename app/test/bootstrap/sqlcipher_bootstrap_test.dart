import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/bootstrap/app_bootstrap.dart';
import 'package:ow_data/ow_data.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:ow_platform/ow_platform.dart';

import 'support.dart';

/// 真实的 SQLCipher 文件库 + 启动流程（桌面环境，临时目录，假的安全存储）。
/// 验证"重启后数据仍在"与"文件加密"这两条验收在 Dart 侧的部分；
/// 设备上的文件路径、备份排除等仍需真机验证。
void main() {
  late Directory dir;
  late FakeSecretStore secrets;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('ow_boot_test_');
    secrets = FakeSecretStore();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  SqlCipherDatabaseOpener newOpener() => SqlCipherDatabaseOpener(
    directoryProvider: () async => dir,
    inBackground: false,
  );

  Future<BootstrapResult> boot() =>
      bootstrapApp(secrets: secrets, opener: newOpener());

  test('重启后数据仍在_文件是加密的', () async {
    final first = await boot() as BootstrapSuccess;
    await OwRepositories(first.database).accounts.upsert(
      Account(
        id: 'a1',
        type: AccountType.wallet,
        name: '持久化测试',
        colorIndex: 1,
        createdAt: DateTime.utc(2026, 11, 12),
      ),
    );
    await first.database.close();

    final bytes = File('${dir.path}/$databaseFileName').readAsBytesSync();
    expect(String.fromCharCodes(bytes.take(15)), isNot('SQLite format 3'));
    expect(String.fromCharCodes(bytes), isNot(contains('持久化测试')));

    final second = await boot() as BootstrapSuccess;
    final back = await OwRepositories(second.database).accounts.byId('a1');
    expect(back?.name, '持久化测试');
    await second.database.close();
  });

  test('数据库在但密钥丢失_报密钥缺失_文件原样保留', () async {
    final first = await boot() as BootstrapSuccess;
    await first.database.close();
    final before = File('${dir.path}/$databaseFileName').readAsBytesSync();

    secrets.data.remove(databaseKeyStoreKey);
    final result = await boot();

    expect(
      result,
      isA<BootstrapFailure>().having(
        (f) => f.kind,
        'kind',
        BootstrapFailureKind.databaseKeyMissing,
      ),
    );
    expect(File('${dir.path}/$databaseFileName').readAsBytesSync(), before);
  });

  test('密钥不匹配_报打开失败_文件原样保留', () async {
    final first = await boot() as BootstrapSuccess;
    await first.database.close();
    final before = File('${dir.path}/$databaseFileName').readAsBytesSync();

    secrets.data[databaseKeyStoreKey] = 'c' * 64;
    final result = await boot();

    expect(
      result,
      isA<BootstrapFailure>().having(
        (f) => f.kind,
        'kind',
        BootstrapFailureKind.databaseOpenFailed,
      ),
    );
    expect(File('${dir.path}/$databaseFileName').readAsBytesSync(), before);
  });
}
