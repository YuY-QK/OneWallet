import 'dart:io';
import 'dart:typed_data';

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
}

/// 固定的 salt（01…10）、nonce（20…37）、时间、密码、参数（8 KiB、迭代 1）与
/// 载荷生成的样本。FORMAT.md 第 7 节的示例就是这个文件。
Future<Uint8List> encodeGoldenSample(VaultCrypto crypto) => BackupCodec.encode(
  payload: samplePayload(withCredentials: true),
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
