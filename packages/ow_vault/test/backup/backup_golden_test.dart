import 'dart:io';
import 'dart:typed_data';

import 'package:ow_domain/ow_domain.dart';
import 'package:ow_vault/ow_vault.dart';
import 'package:test/test.dart';

import '../support/backup_fixtures.dart';
import '../support/vault_fixtures.dart';

/// 格式钉死：版本 1 的文件字节永远不变，且永远能被读出。
///
/// `test/fixtures/backup_v1_sample.owbak` 是"版本 1 必须能读"的回归基准，
/// 不得修改或重新生成（见同目录 README_backup.md）。编码结果与它不一致，说明
/// 格式被无意改动了——要改格式就升版本，旧样本仍须能读。
void main() {
  late SodiumVaultCrypto crypto;

  setUpAll(() async => crypto = await SodiumVaultCrypto.load());

  test('固定输入的编码结果_与样本文件逐字节相同', () async {
    final file = await encodeGoldenSample(crypto);
    final sample = File('test/fixtures/backup_v1_sample.owbak')
        .readAsBytesSync();
    expect(file, sample);
  });

  test('样本文件_用真实codec解开_内容与固定载荷相同', () async {
    final sample = File('test/fixtures/backup_v1_sample.owbak')
        .readAsBytesSync();
    final header = okValue(BackupCodec.peekHeader(sample));
    expect(header.createdAt, t0);
    expect(header.appVersion, '1.0.0+1');
    final decoded = okValue(
      await BackupCodec.decode(
        file: sample,
        password: sensitive(backupPassword),
        crypto: crypto,
      ),
    );
    expectSamePayload(decoded, samplePayload(withCredentials: true));
    decoded.wipe();
  });

  test('FORMAT.md第7节的示例文件_逐字节相同且可解开', () async {
    final file = await encodeGoldenSample(
      crypto,
      payload: formatExamplePayload(),
    );
    final example = File('test/fixtures/backup_v1_format_example.owbak')
        .readAsBytesSync();
    expect(file, example);
    final decoded = okValue(
      await BackupCodec.decode(
        file: example,
        password: sensitive(backupPassword),
        crypto: crypto,
      ),
    );
    expectSamePayload(decoded, formatExamplePayload());
  });
}

/// FORMAT.md 第 7 节十六进制示例的载荷：一个账户、一组公开测试助记词、默认设置。
BackupPayload formatExamplePayload() => BackupPayload(
  exportedAt: t0,
  accounts: [
    Account(
      id: 'acc-1',
      type: AccountType.wallet,
      name: 'Test',
      colorIndex: 0,
      createdAt: t0,
      vaultItemId: 'item-1',
    ),
  ],
  addresses: const [],
  vaultItems: [
    BackupVaultItem(
      id: 'item-1',
      name: 'Test',
      createdAt: t0,
      secret: mnemonicSecret(abandon),
    ),
  ],
  settings: const BackupSettings(),
);

/// 固定的 salt（01…10）、nonce（20…37）、时间、密码、参数（8 KiB、迭代 1）与
/// 载荷（默认为 `samplePayload(withCredentials: true)`）生成的样本。
Future<Uint8List> encodeGoldenSample(
  VaultCrypto crypto, {
  BackupPayload? payload,
}) => BackupCodec.encode(
  payload: payload ?? samplePayload(withCredentials: true),
  password: sensitive(backupPassword),
  crypto: RecordingCrypto(
    crypto,
    fixedRandom: [
      Uint8List.fromList([for (var i = 1; i <= 16; i++) i]),
      Uint8List.fromList([for (var i = 0x20; i < 0x38; i++) i]),
    ],
  ),
  params: fastParams,
  createdAt: t0,
  appVersion: '1.0.0+1',
);
