import 'dart:convert';
import 'dart:typed_data';

import 'package:ow_domain/ow_domain.dart';
import 'package:ow_vault/ow_vault.dart';
import 'package:test/test.dart';

import '../support/backup_fixtures.dart';
import '../support/vault_fixtures.dart';

/// 往返、密码、peekHeader、文件中不含明文。篡改见 backup_tamper_test.dart，
/// 载荷解析见 backup_payload_test.dart，格式钉死见 backup_golden_test.dart。
void main() {
  late SodiumVaultCrypto crypto;

  setUpAll(() async => crypto = await SodiumVaultCrypto.load());

  Future<Uint8List> encode(
    BackupPayload payload, {
    String password = backupPassword,
    KdfParams? params,
    VaultCrypto? using,
  }) => BackupCodec.encode(
    payload: payload,
    password: sensitive(password),
    crypto: using ?? crypto,
    params: params ?? fastParams,
    createdAt: t0,
    appVersion: '1.0.0+1',
  );

  Future<Result<BackupPayload>> decode(
    Uint8List file, {
    String password = backupPassword,
    VaultCrypto? using,
  }) => BackupCodec.decode(
    file: file,
    password: sensitive(password),
    crypto: using ?? crypto,
  );

  group('往返', () {
    for (final withCredentials in [false, true]) {
      test(
        'encode_decode_交易所凭据${withCredentials ? '包含' : '不包含'}_逐字段相等',
        () async {
          final payload = samplePayload(withCredentials: withCredentials);
          final decoded = okValue(await decode(await encode(payload)));
          expectSamePayload(decoded, payload);
          expect(decoded.skipped, isEmpty);
          expect(decoded.exchangeCredentials == null, !withCredentials);
          decoded.wipe();
        },
      );
    }

    test('空载荷_往返成功', () async {
      final payload = BackupPayload(
        exportedAt: t0,
        accounts: const [],
        addresses: const [],
        vaultItems: const [],
        settings: const BackupSettings(),
        exchangeCredentials: const [],
      );
      final decoded = okValue(await decode(await encode(payload)));
      expectSamePayload(decoded, payload);
      expect(decoded.exchangeCredentials, isEmpty);
    });

    test('非ASCII的助记词与附加密码_以文本往返', () async {
      // BIP39 日文词表的公开测试向量（第 1 组），单词间是全角空格 U+3000。
      const japanese =
          'あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　'
          'あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　'
          'あいこくしん　あおぞら';
      final payload = BackupPayload(
        exportedAt: t0,
        accounts: const [],
        addresses: const [],
        vaultItems: [
          BackupVaultItem(
            id: 'jp',
            name: '日文',
            createdAt: t0,
            secret: mnemonicSecret(japanese, passphrase: '㍍ガバヴァぱばぐゞちぢ十人十色'),
          ),
        ],
        settings: const BackupSettings(),
      );
      final decoded = okValue(await decode(await encode(payload)));
      expectSamePayload(decoded, payload);
    });

    test('backupDefault参数_256MiB往返成功', () async {
      final watch = Stopwatch()..start();
      final file = await encode(
        samplePayload(),
        params: KdfParams.backupDefault,
      );
      final encodeMs = watch.elapsedMilliseconds;
      final decoded = okValue(await decode(file));
      expectSamePayload(decoded, samplePayload());
      final header = okValue(BackupCodec.peekHeader(file));
      expect(header.kdfParams, KdfParams.backupDefault);
      // 耗时供汇报参考（本机），不做断言。
      printOnFailure('编码 $encodeMs ms，往返共 ${watch.elapsedMilliseconds} ms');
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('两次编码_salt与nonce不同_文件不同', () async {
      final a = await encode(samplePayload());
      final b = await encode(samplePayload());
      expect(a, isNot(b));
    });

    test('linked_account_ids_由账户的vaultItemId推出', () async {
      final payload = samplePayload();
      expect(payload.linkedAccountIds('item-abandon'), ['acc-main']);
      expect(payload.linkedAccountIds('item-legal'), isEmpty);
    });
  });

  group('密码', () {
    test('错误密码_WrongPasswordFailure且不含细节', () async {
      final file = await encode(samplePayload());
      for (final wrong in ['fake-backup-passworD', 'x', '$backupPassword ']) {
        final f = errOf(await decode(file, password: wrong));
        expect(f, isA<WrongPasswordFailure>());
        expect(f.detail, isNull);
      }
    });

    test('空密码解码_WrongPasswordFailure且不执行Argon2id', () async {
      final file = await encode(samplePayload());
      final spy = RecordingCrypto(crypto);
      final f = errOf(await decode(file, password: '', using: spy));
      expect(f, isA<WrongPasswordFailure>());
      expect(spy.argon2idCalls, 0);
    });

    test('空密码编码_抛出ArgumentError', () async {
      await expectLater(
        encode(samplePayload(), password: ''),
        throwsArgumentError,
      );
    });

    test('密码按UTF-8字节使用_非ASCII密码往返', () async {
      final file = await encode(samplePayload(), password: '备份密码-测试');
      expect(okValue(await decode(file, password: '备份密码-测试')), isNotNull);
    });
  });

  group('编码的参数检查', () {
    test('保险库条目id不合法_抛出ArgumentError且不执行Argon2id', () async {
      final spy = RecordingCrypto(crypto);
      final bad = BackupPayload(
        exportedAt: t0,
        accounts: const [],
        addresses: const [],
        vaultItems: [
          BackupVaultItem(
            id: 'bad id',
            name: 'x',
            createdAt: t0,
            secret: mnemonicSecret(abandon),
          ),
        ],
        settings: const BackupSettings(),
      );
      await expectLater(encode(bad, using: spy), throwsArgumentError);
      expect(spy.argon2idCalls, 0);
    });

    test('空助记词_抛出ArgumentError', () async {
      final bad = BackupPayload(
        exportedAt: t0,
        accounts: const [],
        addresses: const [],
        vaultItems: [
          BackupVaultItem(
            id: 'empty',
            name: 'x',
            createdAt: t0,
            secret: MnemonicSecret(mnemonic: Sensitive(Uint8List(0))),
          ),
        ],
        settings: const BackupSettings(),
      );
      await expectLater(encode(bad), throwsArgumentError);
    });

    test('应用版本过长使头部超限_抛出ArgumentError', () async {
      await expectLater(
        BackupCodec.encode(
          payload: samplePayload(),
          password: sensitive(backupPassword),
          crypto: crypto,
          params: fastParams,
          createdAt: t0,
          appVersion: 'v' * 5000,
        ),
        throwsArgumentError,
      );
    });
  });

  group('peekHeader', () {
    test('不需要密码_不执行Argon2id_返回创建时间与应用版本', () async {
      final file = await encode(samplePayload());
      final spy = RecordingCrypto(crypto);
      final header = okValue(BackupCodec.peekHeader(file));
      expect(header.createdAt, t0);
      expect(header.appVersion, '1.0.0+1');
      expect(header.containerVersion, 1);
      expect(header.kdfParams, fastParams);
      expect(spy.argon2idCalls, 0);
    });

    test('非备份文件_BackupCorruptedFailure', () {
      final f = errOf(BackupCodec.peekHeader(utf8.encode('hello world')));
      expect(f, isA<BackupCorruptedFailure>());
    });
  });

  group('文件中不含明文', () {
    test('助记词单词、私钥、交易所凭据都搜索不到', () async {
      final file = await encode(samplePayload(withCredentials: true));
      final text = latin1.decode(file);
      for (final fragment in [
        'abandon',
        'about',
        'legal',
        'winner',
        'TREZOR',
        '2222222222',
        'test-api',
        'test-passphrase',
        '主钱包',
        'acc-main',
      ]) {
        expect(text.contains(fragment), isFalse, reason: fragment);
        final utf = utf8.encode(fragment);
        expect(_indexOf(file, utf), -1, reason: fragment);
      }
      // 二进制私钥（32 个 0x11）的任一 8 字节片段。
      expect(_indexOf(file, List.filled(8, 0x11)), -1);
    });

    test('BackupPayload的toString不含内容', () {
      final p = samplePayload(withCredentials: true);
      expect(p.toString(), isNot(contains('abandon abandon')));
      expect(p.vaultItems.first.toString(), isNot(contains('abandon abandon')));
      expect(p.exchangeCredentials!.first.toString(), isNot(contains('test')));
    });

    test('wipe_清零全部密钥内容', () {
      final p = samplePayload(withCredentials: true)..wipe();
      for (final item in p.vaultItems) {
        switch (item.secret) {
          case MnemonicSecret(:final mnemonic, :final passphrase):
            expect(mnemonic.isWiped, isTrue);
            expect(passphrase?.isWiped ?? true, isTrue);
          case PrivateKeySecret(:final key):
            expect(key.isWiped, isTrue);
        }
      }
      final c = p.exchangeCredentials!.single.credentials;
      expect(
        [c.apiKey.isWiped, c.apiSecret.isWiped, c.passphrase!.isWiped],
        [true, true, true],
      );
    });
  });

  group('BackupSettings', () {
    test('of与applyTo_只迁移四项', () {
      const app = AppSettings(
        quote: Quote.cny,
        hideSmall: false,
        hideAmounts: true,
        theme: ThemePreference.light,
        autoLock: AutoLock.after1Min,
        appBiometrics: true,
        vaultBiometrics: true,
      );
      final s = BackupSettings.of(app);
      expect(s.quote, Quote.cny);
      final applied = s.applyTo(const AppSettings());
      expect(applied.quote, Quote.cny);
      expect(applied.hideSmall, isFalse);
      expect(applied.theme, ThemePreference.light);
      expect(applied.autoLock, AutoLock.after1Min);
      expect(applied.hideAmounts, isFalse);
      expect(applied.appBiometrics, isFalse);
      expect(applied.vaultBiometrics, isFalse);
      expect(s.hashCode, BackupSettings.of(app).hashCode);
    });
  });
}

int _indexOf(List<int> haystack, List<int> needle) {
  outer:
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) continue outer;
    }
    return i;
  }
  return -1;
}
