import 'dart:convert';
import 'dart:typed_data';

import 'package:ow_domain/ow_domain.dart';
import 'package:ow_vault/ow_vault.dart';
import 'package:test/test.dart';

import '../support/backup_fixtures.dart';
import '../support/vault_fixtures.dart';

/// 篡改、截断、追加、头部与 KDF 参数越界、版本过新。任何一种都不得返回内容。
void main() {
  late SodiumVaultCrypto crypto;
  late Uint8List file;
  late int headerEnd;

  setUpAll(() async {
    crypto = await SodiumVaultCrypto.load();
    file = await BackupCodec.encode(
      payload: BackupPayload(
        exportedAt: t0,
        accounts: const [],
        addresses: const [],
        vaultItems: [
          BackupVaultItem(
            id: 'item',
            name: 'n',
            createdAt: t0,
            secret: mnemonicSecret(abandon),
          ),
        ],
        settings: const BackupSettings(),
      ),
      password: sensitive(backupPassword),
      crypto: crypto,
      params: fastParams,
      createdAt: t0,
      appVersion: '1.0.0',
    );
    headerEnd = 9 + ByteData.sublistView(file).getUint32(5);
  });

  Future<(Failure, int)> failureOf(Uint8List bytes) async {
    final spy = RecordingCrypto(crypto);
    final r = await BackupCodec.decode(
      file: bytes,
      password: sensitive(backupPassword),
      crypto: spy,
    );
    expect(r.isOk, isFalse, reason: '被改动的文件不得解出内容');
    return (errOf(r), spy.argon2idCalls);
  }

  Uint8List flipped(int index) =>
      Uint8List.fromList(file)..[index] = file[index] ^ 0x01;

  test('原文件_可以解开', () async {
    final r = await BackupCodec.decode(
      file: file,
      password: sensitive(backupPassword),
      crypto: crypto,
    );
    expect(r.isOk, isTrue);
  });

  test('魔数任一字节被改_BackupCorrupted且不执行Argon2id', () async {
    for (var i = 0; i < 4; i++) {
      final (f, calls) = await failureOf(flipped(i));
      expect(f, isA<BackupCorruptedFailure>());
      expect(calls, 0);
    }
  });

  test('版本字节为0_BackupCorrupted；为2或255_版本不支持；均不执行Argon2id', () async {
    for (final (v, matcher) in [
      (0, isA<BackupCorruptedFailure>()),
      (2, isA<BackupVersionUnsupportedFailure>()),
      (255, isA<BackupVersionUnsupportedFailure>()),
    ]) {
      final (f, calls) = await failureOf(Uint8List.fromList(file)..[4] = v);
      expect(f, matcher);
      expect(calls, 0);
    }
  });

  test('头部长度被改_BackupCorrupted且不执行Argon2id', () async {
    final length = headerEnd - 9;
    for (final l in [0, 1, length - 1, length + 1, 4097, 0xffffffff]) {
      final bytes = Uint8List.fromList(file);
      ByteData.sublistView(bytes).setUint32(5, l);
      final (f, calls) = await failureOf(bytes);
      expect(f, isA<BackupCorruptedFailure>(), reason: 'L=$l');
      expect(calls, 0);
    }
  });

  test('头部JSON任一字节被改_结构不合法则损坏，否则认证失败', () async {
    for (var i = 9; i < headerEnd; i++) {
      final bytes = flipped(i);
      final peek = BackupCodec.peekHeader(bytes);
      final (f, calls) = await failureOf(bytes);
      if (peek.isOk) {
        expect(f, isA<WrongPasswordFailure>(), reason: '偏移 $i');
      } else {
        expect(f, isA<BackupCorruptedFailure>(), reason: '偏移 $i');
        expect(calls, 0);
      }
    }
  });

  test('密文任一字节被改_WrongPasswordFailure', () async {
    for (var i = headerEnd; i < file.length; i++) {
      final (f, _) = await failureOf(flipped(i));
      expect(f, isA<WrongPasswordFailure>(), reason: '偏移 $i');
    }
  });

  test('截断_各位置都失败', () async {
    for (final cut in [0, 3, 8, 9, headerEnd - 1, headerEnd, headerEnd + 16]) {
      final (f, calls) = await failureOf(Uint8List.sublistView(file, 0, cut));
      expect(f, isA<BackupCorruptedFailure>(), reason: '保留 $cut 字节');
      expect(calls, 0);
    }
    for (final cut in [headerEnd + 17, file.length - 16, file.length - 1]) {
      final (f, _) = await failureOf(Uint8List.sublistView(file, 0, cut));
      expect(f, isA<WrongPasswordFailure>(), reason: '保留 $cut 字节');
    }
  });

  test('末尾追加字节_WrongPasswordFailure', () async {
    for (final extra in [
      [0],
      List.filled(16, 0),
      utf8.encode('{}'),
    ]) {
      final (f, _) = await failureOf(Uint8List.fromList([...file, ...extra]));
      expect(f, isA<WrongPasswordFailure>());
    }
  });

  group('构造的头部', () {
    Map<String, Object?> header() => {
      'kdf': {
        'alg': 'argon2id',
        'salt': base64.encode(List.filled(16, 1)),
        'mem_kib': 8,
        'iters': 1,
        'parallelism': 1,
      },
      'nonce': base64.encode(List.filled(24, 2)),
      'created_at': '2026-11-13T08:30:00.000Z',
      'app_version': 'x',
    };

    Uint8List withHeader(List<int> json, {int version = 1}) {
      final out = BytesBuilder()
        ..add(utf8.encode('OWBK'))
        ..addByte(version)
        ..add((ByteData(4)..setUint32(0, json.length)).buffer.asUint8List())
        ..add(json)
        ..add(List.filled(64, 0));
      return out.toBytes();
    }

    Future<void> expectCorrupted(Map<String, Object?> h) async {
      final (f, calls) = await failureOf(
        withHeader(utf8.encode(jsonEncode(h))),
      );
      expect(f, isA<BackupCorruptedFailure>(), reason: jsonEncode(h));
      expect(calls, 0, reason: '不得执行 Argon2id');
    }

    Map<String, Object?> withKdf(String key, Object? value) {
      final h = header();
      (h['kdf']! as Map<String, Object?>)[key] = value;
      return h;
    }

    test('合法的构造头部_执行Argon2id后认证失败', () async {
      final (f, calls) = await failureOf(
        withHeader(utf8.encode(jsonEncode(header()))),
      );
      expect(f, isA<WrongPasswordFailure>());
      expect(calls, 1);
    });

    test('KDF参数越界_损坏且不执行Argon2id', () async {
      await expectCorrupted(withKdf('mem_kib', 1024 * 1024 + 1));
      await expectCorrupted(withKdf('mem_kib', 4));
      await expectCorrupted(withKdf('mem_kib', 8.5));
      await expectCorrupted(withKdf('mem_kib', '8'));
      await expectCorrupted(withKdf('iters', 0));
      await expectCorrupted(withKdf('iters', 33));
      await expectCorrupted(withKdf('parallelism', 2));
      await expectCorrupted(withKdf('alg', 'argon2i'));
      await expectCorrupted(withKdf('salt', base64.encode(List.filled(15, 1))));
      await expectCorrupted(withKdf('salt', 'AQEBAQEBAQEBAQEBAQEBAQ'));
    });

    test('头部字段缺失或类型不对_损坏', () async {
      for (final key in ['kdf', 'nonce', 'created_at', 'app_version']) {
        await expectCorrupted(header()..remove(key));
      }
      await expectCorrupted(header()..['nonce'] = base64.encode([1, 2, 3]));
      await expectCorrupted(header()..['created_at'] = '2026-11-13 08:30:00');
      await expectCorrupted(header()..['created_at'] = '2026-11-13T08:30:00');
      await expectCorrupted(header()..['app_version'] = 1);
    });

    test('头部不是JSON对象、有重复键、非UTF-8或缺字段_损坏', () async {
      for (final raw in [
        utf8.encode('[1,2]'),
        utf8.encode('{"a":1,"a":2}'),
        [0x7b, 0xff, 0x7d],
        utf8.encode('{} '),
      ]) {
        final (f, calls) = await failureOf(withHeader(raw));
        expect(f, isA<BackupCorruptedFailure>());
        expect(calls, 0);
      }
    });

    test('头部超过4096字节_损坏且不执行Argon2id', () async {
      final h = header()..['app_version'] = 'v' * 4096;
      await expectCorrupted(h);
    });

    test('头部里的未知字段_被忽略', () async {
      final h = header()..['future_field'] = {'x': 1};
      final peek = BackupCodec.peekHeader(
        withHeader(utf8.encode(jsonEncode(h))),
      );
      expect(okValue(peek).appVersion, 'x');
    });
  });
}
