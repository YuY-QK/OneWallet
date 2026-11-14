import 'dart:convert';

import 'package:ow_domain/ow_domain.dart';
import 'package:ow_vault/ow_vault.dart';
import 'package:test/test.dart';

import '../support/backup_fixtures.dart';
import '../support/vault_fixtures.dart';

/// 载荷 JSON 的解析：向前兼容、跳过、密钥字段的形式、损坏、版本。写法见
/// backup_payload_write_test.dart。
void main() {
  late SodiumVaultCrypto crypto;

  setUpAll(() async => crypto = await SodiumVaultCrypto.load());

  Future<Result<BackupPayload>> decodeJson(Map<String, Object?> json) async =>
      BackupCodec.decode(
        file: await sealJson(crypto, json),
        password: sensitive(backupPassword),
        crypto: crypto,
      );

  Map<String, Object?> mnemonicItem() => {
    'id': 'm1',
    'name': 'n',
    'kind': 'mnemonic',
    'created_at': '2026-01-01T00:00:00Z',
    'mnemonic': abandon,
  };

  Map<String, Object?> payloadWith(String key, List<Object?> entries) =>
      minimalPayloadJson()..[key] = entries;

  group('向前兼容', () {
    test('未知的顶层字段与条目字段_被忽略', () async {
      final json = minimalPayloadJson()
        ..['future'] = {
          'nested': [1, 2.5, true, null],
        }
        ..['vault_items'] = [mnemonicItem()..['color'] = 'red'];
      (json['settings']! as Map<String, Object?>)['font_size'] = 3;
      final p = okValue(await decodeJson(json));
      expect(p.vaultItems.single.id, 'm1');
      expect(p.skipped, isEmpty);
    });

    test('未知枚举的账户_被跳过并计数_其余正常', () async {
      Map<String, Object?> account(String id, {String type = 'wallet'}) => {
        'id': id,
        'type': type,
        'name': id,
        'color_index': 0,
        'note': '',
        'wallet_source': null,
        'exchange': null,
        'vault_item_id': null,
        'backup': {'offline_backed_up': false, 'keyless': false},
        'created_at': '2026-01-01T00:00:00Z',
      };
      final p = okValue(
        await decodeJson(
          payloadWith('accounts', [
            account('a1'),
            account('a2', type: 'dao'),
            account('a3')..['wallet_source'] = 'phantom',
            account('a4')..['exchange'] = 'kraken',
            account('a5')..remove('vault_item_id'),
          ]),
        ),
      );
      expect(p.accounts.map((a) => a.id), ['a1', 'a5']);
      expect(p.skipped, const [
        BackupSkipped(BackupSection.account, 'a2'),
        BackupSkipped(BackupSection.account, 'a3'),
        BackupSkipped(BackupSection.account, 'a4'),
      ]);
      expect(p.accounts.first.createdAt, DateTime.utc(2026));
    });

    test('未知链家族、派生方案或链id的地址_被跳过', () async {
      Map<String, Object?> address(String id) => {
        'id': id,
        'account_id': 'a1',
        'family': 'evm',
        'address': '0x000000000000000000000000000000000000dead',
        'enabled_chains': ['ethereum'],
        'scheme': null,
        'derivation_index': null,
        'note': '',
      };
      final p = okValue(
        await decodeJson(
          payloadWith('addresses', [
            address('ok'),
            address('f')..['family'] = 'cosmos',
            address('s')..['scheme'] = 'evmFuture',
            address('c')..['enabled_chains'] = ['ethereum', 'zksync'],
          ]),
        ),
      );
      expect(p.addresses.map((a) => a.id), ['ok']);
      expect(p.skipped.map((s) => s.id), ['f', 's', 'c']);
    });

    test('未知类型或链家族的保险库条目_被跳过', () async {
      final p = okValue(
        await decodeJson(
          payloadWith('vault_items', [
            mnemonicItem(),
            mnemonicItem()
              ..['id'] = 'x'
              ..['kind'] = 'seed_qr',
            {
              'id': 'k',
              'name': 'n',
              'kind': 'private_key',
              'created_at': '2026-01-01T00:00:00Z',
              'family': 'cosmos',
              'private_key': 'abc',
            },
          ]),
        ),
      );
      expect(p.vaultItems.map((i) => i.id), ['m1']);
      expect(p.skipped, const [
        BackupSkipped(BackupSection.vaultItem, 'x'),
        BackupSkipped(BackupSection.vaultItem, 'k'),
      ]);
    });

    test('不认识的设置值_取默认值并记录', () async {
      final json = minimalPayloadJson()
        ..['settings'] = {
          'quote': 'eur',
          'hide_small': false,
          'theme': 'sepia',
          'auto_lock': 'after5Min',
        };
      final p = okValue(await decodeJson(json));
      expect(
        p.settings,
        const BackupSettings(hideSmall: false, autoLock: AutoLock.after5Min),
      );
      expect(p.skipped, const [
        BackupSkipped(BackupSection.setting, 'quote'),
        BackupSkipped(BackupSection.setting, 'theme'),
      ]);
    });

    test('时间带时区偏移与微秒_转为UTC', () async {
      final json = minimalPayloadJson()
        ..['exported_at'] = '2026-11-13T16:30:00.123456+08:00';
      final p = okValue(await decodeJson(json));
      expect(p.exportedAt, DateTime.utc(2026, 11, 13, 8, 30, 0, 123, 456));
      expect(p.exportedAt.isUtc, isTrue);
    });
  });

  group('密钥字段的形式', () {
    test('十六进制（大小写均可）与文本形式_解码为相同字节', () async {
      final hex = utf8
          .encode(abandon)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      final p = okValue(
        await decodeJson(
          payloadWith('vault_items', [
            mnemonicItem(),
            mnemonicItem()
              ..['id'] = 'h'
              ..['encoding'] = 'hex'
              ..['mnemonic'] = hex.toUpperCase()
              ..['passphrase'] = '',
          ]),
        ),
      );
      final [a, b] = p.vaultItems;
      final sa = a.secret as MnemonicSecret;
      final sb = b.secret as MnemonicSecret;
      expect(bytesOf(sb.mnemonic), bytesOf(sa.mnemonic));
      expect(sa.passphrase, isNull);
      expect(bytesOf(sb.passphrase!), isEmpty);
    });

    test('passphrase为null_视为没有附加密码', () async {
      final p = okValue(
        await decodeJson(
          payloadWith('vault_items', [mnemonicItem()..['passphrase'] = null]),
        ),
      );
      expect((p.vaultItems.single.secret as MnemonicSecret).passphrase, isNull);
    });

    test('JSON转义写成的助记词_还原为原文', () async {
      final raw = utf8.encode(
        '{"format":"onewallet-backup","payload_version":1,'
        '"exported_at":"2026-11-13T08:30:00Z","accounts":[],"addresses":[],'
        '"settings":{"quote":"usd","hide_small":true,"theme":"system","auto_lock":"immediately"},'
        r'"vault_items":[{"id":"e","name":"名","kind":"mnemonic",'
        r'"created_at":"2026-01-01T00:00:00Z","mnemonic":"abandon\/x 😀"}]}',
      );
      final p = okValue(
        await BackupCodec.decode(
          file: await sealRaw(crypto, raw),
          password: sensitive(backupPassword),
          crypto: crypto,
        ),
      );
      final item = p.vaultItems.single;
      expect(item.name, '名');
      expect(textOf((item.secret as MnemonicSecret).mnemonic), 'abandon/x 😀');
    });
  });

  group('损坏与版本', () {
    Future<Failure> failureOf(Map<String, Object?> json) async =>
        errOf(await decodeJson(json));

    test('payload_version为2_版本不支持', () async {
      final f = await failureOf(minimalPayloadJson()..['payload_version'] = 2);
      expect(f, isA<BackupVersionUnsupportedFailure>());
    });

    test('format不对或版本不合法_损坏', () async {
      for (final json in [
        minimalPayloadJson()..['format'] = 'onewallet-vault',
        minimalPayloadJson()..remove('format'),
        minimalPayloadJson()..['payload_version'] = 0,
        minimalPayloadJson()..['payload_version'] = '1',
        minimalPayloadJson()..['payload_version'] = 1.5,
        minimalPayloadJson()..remove('payload_version'),
      ]) {
        expect(await failureOf(json), isA<BackupCorruptedFailure>());
      }
    });

    test('缺少必需字段或类型不对_损坏', () async {
      final cases = <Map<String, Object?>>[
        for (final key in [
          'exported_at',
          'accounts',
          'addresses',
          'vault_items',
          'settings',
        ])
          minimalPayloadJson()..remove(key),
        minimalPayloadJson()..['accounts'] = {},
        minimalPayloadJson()..['exchange_credentials'] = 'none',
        payloadWith('vault_items', [mnemonicItem()..remove('mnemonic')]),
        payloadWith('vault_items', [mnemonicItem()..remove('name')]),
        payloadWith('vault_items', [mnemonicItem()..['mnemonic'] = '']),
        payloadWith('vault_items', [mnemonicItem()..['mnemonic'] = 7]),
        payloadWith('vault_items', [mnemonicItem()..['id'] = 'has space']),
        payloadWith('vault_items', [mnemonicItem()..['encoding'] = 'base64']),
        payloadWith('vault_items', [
          mnemonicItem()
            ..['encoding'] = 'hex'
            ..['mnemonic'] = 'abc',
        ]),
        payloadWith('vault_items', [
          mnemonicItem()
            ..['encoding'] = 'hex'
            ..['mnemonic'] = 'zz',
        ]),
        payloadWith('vault_items', [mnemonicItem()..['passphrase'] = 1]),
        payloadWith('vault_items', [1]),
        payloadWith('addresses', [
          {'id': 'a', 'family': 'evm'},
        ]),
        payloadWith('exchange_credentials', [
          {'account_id': 'a', 'api_key': 'k'},
        ]),
        minimalPayloadJson()..['exported_at'] = '昨天',
      ];
      for (final json in cases) {
        expect(
          await failureOf(json),
          isA<BackupCorruptedFailure>(),
          reason: jsonEncode(json),
        );
      }
    });

    test('载荷不是JSON对象_损坏', () async {
      for (final raw in [
        '[]',
        'not json',
        '{"format":"onewallet-backup"',
        '',
      ]) {
        final r = await BackupCodec.decode(
          file: await sealRaw(crypto, utf8.encode(raw)),
          password: sensitive(backupPassword),
          crypto: crypto,
        );
        expect(errOf(r), isA<BackupCorruptedFailure>(), reason: raw);
      }
    });

    test('交易所凭据不合法_已解出的密钥被清零_不返回内容', () async {
      final r = await decodeJson(
        payloadWith('vault_items', [mnemonicItem()])
          ..['exchange_credentials'] = [
            {'account_id': 'a', 'api_key': 'test-api-key', 'api_secret': 5},
          ],
      );
      expect(errOf(r), isA<BackupCorruptedFailure>());
    });
  });
}
