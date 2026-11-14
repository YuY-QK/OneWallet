import 'dart:convert';
import 'dart:typed_data';

import 'package:ow_vault/ow_vault.dart';
import 'package:ow_vault/src/backup/backup_format.dart';
import 'package:test/test.dart';

import '../support/backup_fixtures.dart';
import '../support/hex.dart';
import '../support/vault_fixtures.dart';

/// 写出的载荷 JSON：字段名、枚举写法、文本与十六进制形式、关联账户。
void main() {
  late SodiumVaultCrypto crypto;

  setUpAll(() async => crypto = await SodiumVaultCrypto.load());

  /// 解密 [file]，返回载荷 JSON（只在测试中把明文变成 `String`）。
  Future<Map<String, Object?>> openRaw(Uint8List file) async {
    final c = okValue(BackupContainer.parse(file));
    final key = await crypto.argon2id(
      sensitive(backupPassword),
      c.salt,
      c.header.kdfParams,
    );
    final plain = okValue(
      crypto.aeadDecrypt(key, c.nonce, c.ciphertext, c.aad),
    );
    return jsonDecode(utf8.decode(plain)) as Map<String, Object?>;
  }

  Future<Uint8List> encode(BackupPayload p) => BackupCodec.encode(
    payload: p,
    password: sensitive(backupPassword),
    crypto: crypto,
    params: fastParams,
    createdAt: t0,
    appVersion: 't',
  );

  group('写出的JSON', () {
    test('字段名、枚举写法、文本与十六进制形式、关联账户', () async {
      final json = await openRaw(await encode(samplePayload()));
      expect(json.keys, [
        'format',
        'payload_version',
        'exported_at',
        'accounts',
        'addresses',
        'vault_items',
        'settings',
      ]);
      expect(json['format'], 'onewallet-backup');
      expect(json['payload_version'], 1);
      expect(json['exported_at'], '2026-11-13T08:30:00.000Z');
      final accounts = objects(json['accounts']);
      expect(accounts[0], {
        'id': 'acc-main',
        'type': 'wallet',
        'name': '主钱包',
        'color_index': 2,
        'note': '日常使用 "引号" 与 \\ 反斜杠',
        'wallet_source': 'metamask',
        'exchange': null,
        'vault_item_id': 'item-abandon',
        'backup': {
          'offline_backed_up': true,
          'offline_verified_at': '2026-06-01T00:00:00.000Z',
          'keyless': false,
        },
        'created_at': '2026-01-02T03:04:05.006Z',
      });
      expect(accounts[1]['wallet_source'], 'okxWeb3');
      expect(accounts[2]['exchange'], 'binance');
      final addresses = objects(json['addresses']);
      expect(addresses[0]['enabled_chains'], ['arbitrum', 'base', 'ethereum']);
      expect(addresses[0]['scheme'], 'evmStandard');
      expect(addresses[2]['scheme'], isNull);
      expect(addresses[2]['derivation_index'], isNull);
      final items = objects(json['vault_items']);
      expect(items[0], {
        'id': 'item-abandon',
        'name': '测试助记词（带附加密码）',
        'kind': 'mnemonic',
        'created_at': '2026-01-02T00:00:00.000Z',
        'linked_account_ids': ['acc-main'],
        'mnemonic': abandon,
        'passphrase': 'TREZOR',
      });
      expect(items[1].containsKey('passphrase'), isFalse);
      expect(items[2], {
        'id': 'item-key-hex',
        'name': '二进制私钥',
        'kind': 'private_key',
        'created_at': '2026-01-04T00:00:00.000Z',
        'linked_account_ids': ['acc-cold'],
        'encoding': 'hex',
        'family': 'evm',
        'private_key': '11' * 32,
      });
      expect(items[3]['private_key'], fakeTextPrivateKey);
      expect(items[3].containsKey('encoding'), isFalse);
      expect(json['settings'], {
        'quote': 'cny',
        'hide_small': false,
        'theme': 'dark',
        'auto_lock': 'after5Min',
      });
    });

    test('交易所凭据_以文本写出', () async {
      final json = await openRaw(
        await encode(samplePayload(withCredentials: true)),
      );
      expect(json['exchange_credentials'], [
        {
          'account_id': 'acc-binance',
          'api_key': 'test-api-key',
          'api_secret': 'test-api-secret',
          'passphrase': 'test-passphrase',
        },
      ]);
    });

    test('含控制字符的助记词_整条改用十六进制_往返不变', () async {
      final payload = BackupPayload(
        exportedAt: t0,
        accounts: const [],
        addresses: const [],
        vaultItems: [
          BackupVaultItem(
            id: 'ctl',
            name: 'n',
            createdAt: t0,
            secret: mnemonicSecret('abandon\tabout', passphrase: 'x'),
          ),
          BackupVaultItem(
            id: 'c1',
            name: 'n',
            createdAt: t0,
            // U+0085（C1 控制字符）不能作为文本。
            secret: mnemonicSecret('abandon\u0085about'),
          ),
        ],
        settings: const BackupSettings(),
      );
      final file = await encode(payload);
      final item = objects((await openRaw(file))['vault_items']).first;
      expect(item['encoding'], 'hex');
      expect(item['mnemonic'], '6162616e646f6e0961626f7574');
      expect(item['passphrase'], '78');
      final decoded = okValue(
        await BackupCodec.decode(
          file: file,
          password: sensitive(backupPassword),
          crypto: crypto,
        ),
      );
      expectSamePayload(decoded, payload);
    });
  });
}
