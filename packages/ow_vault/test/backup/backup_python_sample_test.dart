import 'dart:io';
import 'dart:typed_data';

import 'package:ow_domain/ow_domain.dart';
import 'package:ow_vault/ow_vault.dart';
import 'package:test/test.dart';

import '../support/backup_fixtures.dart';
import '../support/vault_fixtures.dart';

/// 反向互操作：格式说明 FORMAT.md 本身足以实现。样本由 Python 独立生成，
/// 不依赖本项目代码；这里只读取固定下来的样本文件，不需要 Python。
void main() {
  late SodiumVaultCrypto crypto;

  setUpAll(() async => crypto = await SodiumVaultCrypto.load());

  test('Python按FORMAT.md独立生成的样本_Dart端解码成功', () async {
    // 出处：test/fixtures/generate_python_backup.py（只用 PyNaCl 与标准库，
    // 不 import 本项目代码）。它故意使用不同的 JSON 写法：缩进、不同的键顺序、
    // \u 转义的非 ASCII 字符、未知字段、十六进制形式的私钥。
    final file = File('test/fixtures/backup_v1_python.owbak').readAsBytesSync();
    final p = okValue(
      await BackupCodec.decode(
        file: file,
        password: sensitive('python-generated-password'),
        crypto: crypto,
      ),
    );
    expect(
      okValue(BackupCodec.peekHeader(file)).appVersion,
      'python-generator',
    );
    expect(p.exportedAt, DateTime.utc(2026, 11, 13, 9));
    expect(p.accounts.single.name, '主钱包');
    expect(p.accounts.single.vaultItemId, 'py-item-1');
    expect(p.addresses.single.enabledChainIds, {'ethereum', 'base'});
    expect(p.addresses.single.scheme, DerivationScheme.evmStandard);
    final [m, k] = p.vaultItems;
    final ms = m.secret as MnemonicSecret;
    expect(textOf(ms.mnemonic), abandon);
    expect(textOf(ms.passphrase!), 'TREZOR');
    final ks = k.secret as PrivateKeySecret;
    expect(ks.family, ChainFamily.solana);
    expect(bytesOf(ks.key), Uint8List.fromList(List.filled(32, 0x33)));
    expect(p.settings.quote, Quote.cny);
    final c = p.exchangeCredentials!.single.credentials;
    expect(textOf(c.apiKey), 'test-api-key');
    expect(c.passphrase, isNull);
    expect(p.skipped, isEmpty);
  });
}
