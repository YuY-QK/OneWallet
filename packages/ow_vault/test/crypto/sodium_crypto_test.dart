import 'dart:typed_data';

import 'package:ow_domain/ow_domain.dart';
import 'package:ow_vault/ow_vault.dart';
import 'package:test/test.dart';

import '../support/hex.dart';

/// 性质测试：篡改、错误密钥、参数校验、确定性。已知答案测试在
/// sodium_crypto_vectors_test.dart。
void main() {
  late SodiumVaultCrypto crypto;
  setUpAll(() async => crypto = await SodiumVaultCrypto.load());

  final key = Uint8List.fromList(List.filled(32, 0x11));
  final nonce = Uint8List.fromList(List.filled(24, 0x22));
  final aad = Uint8List.fromList('aad'.codeUnits);
  final plaintext = Uint8List.fromList('fake plaintext for tests'.codeUnits);
  final fastParams = KdfParams(memKib: 8, iterations: 1);

  group('randomBytes', () {
    test('randomBytes_长度正确且两次不同', () {
      final a = crypto.randomBytes(32);
      final b = crypto.randomBytes(32);
      expect(a, hasLength(32));
      expect(b, hasLength(32));
      expect(tohex(a), isNot(tohex(b)));
      expect(crypto.randomBytes(0), isEmpty);
      expect(crypto.randomBytes(7), hasLength(7));
    });

    test('randomBytes_负长度_抛出参数错误', () {
      expect(() => crypto.randomBytes(-1), throwsArgumentError);
    });
  });

  group('aead', () {
    late Uint8List sealed;
    setUp(() => sealed = crypto.aeadEncrypt(key, nonce, plaintext, aad));

    test('aead_往返_明文一致且密文多16字节标签', () {
      expect(sealed, hasLength(plaintext.length + 16));
      expect(
        crypto.aeadDecrypt(key, nonce, sealed, aad).valueOrNull,
        plaintext,
      );
    });

    test('aead_篡改密文任一字节_解密失败', () {
      for (var i = 0; i < sealed.length; i++) {
        final tampered = Uint8List.fromList(sealed)..[i] ^= 0x01;
        final result = crypto.aeadDecrypt(key, nonce, tampered, aad);
        expect(result.isOk, isFalse, reason: '第 $i 字节');
      }
    });

    test('aead_篡改nonce任一字节_解密失败', () {
      for (var i = 0; i < nonce.length; i++) {
        final tampered = Uint8List.fromList(nonce)..[i] ^= 0x80;
        expect(crypto.aeadDecrypt(key, tampered, sealed, aad).isOk, isFalse);
      }
    });

    test('aead_篡改关联数据任一字节或改变长度_解密失败', () {
      for (var i = 0; i < aad.length; i++) {
        final tampered = Uint8List.fromList(aad)..[i] ^= 0x01;
        expect(crypto.aeadDecrypt(key, nonce, sealed, tampered).isOk, isFalse);
      }
      expect(
        crypto.aeadDecrypt(key, nonce, sealed, Uint8List(0)).isOk,
        isFalse,
      );
      final longer = Uint8List.fromList([...aad, 0]);
      expect(crypto.aeadDecrypt(key, nonce, sealed, longer).isOk, isFalse);
    });

    test('aead_错误密钥_返回VaultCorruptedFailure', () {
      final wrong = Uint8List.fromList(key)..[0] ^= 0x01;
      final result = crypto.aeadDecrypt(wrong, nonce, sealed, aad);
      expect(result.isOk, isFalse);
      result.when(
        ok: (_) => fail('不应成功'),
        err: (f) {
          expect(f, isA<VaultCorruptedFailure>());
          expect(f.detail, 'aead_auth_failed');
        },
      );
    });

    test('aead_密文过短或nonce长度不对_返回Err而不抛异常', () {
      final short = crypto.aeadDecrypt(key, nonce, Uint8List(15), aad);
      expect(short.isOk, isFalse);
      final badNonce = crypto.aeadDecrypt(key, Uint8List(12), sealed, aad);
      expect(badNonce.isOk, isFalse);
    });

    test('aead_空明文与空关联数据_可往返', () {
      final empty = crypto.aeadEncrypt(key, nonce, Uint8List(0), Uint8List(0));
      expect(empty, hasLength(16));
      final opened = crypto.aeadDecrypt(key, nonce, empty, Uint8List(0));
      expect(opened.valueOrNull, isEmpty);
    });

    test('aead_密钥或nonce长度不对_抛出参数错误且不回显内容', () {
      expect(
        () => crypto.aeadEncrypt(Uint8List(31), nonce, plaintext, aad),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.toString(),
            'message',
            isNot(contains('17')),
          ),
        ),
      );
      expect(
        () => crypto.aeadEncrypt(key, Uint8List(12), plaintext, aad),
        throwsArgumentError,
      );
      expect(
        () => crypto.aeadDecrypt(Uint8List(16), nonce, sealed, aad),
        throwsArgumentError,
      );
    });

    test('aead_同一输入两次加密_结果相同（nonce由调用方负责更换）', () {
      // 加密本身是确定性的；"每次加密都用新 nonce"由保险库在调用处保证。
      expect(crypto.aeadEncrypt(key, nonce, plaintext, aad), sealed);
    });
  });

  group('argon2id', () {
    final salt = Uint8List.fromList(List.generate(16, (i) => i));

    test('argon2id_相同输入_结果稳定；密码或salt或参数不同_结果不同', () async {
      Future<String> run(String pw, Uint8List s, KdfParams p) async => tohex(
        await crypto.argon2id(
          Sensitive(Uint8List.fromList(pw.codeUnits)),
          s,
          p,
        ),
      );
      final base = await run('fake-password', salt, fastParams);
      expect(await run('fake-password', salt, fastParams), base);
      expect(await run('fake-passwore', salt, fastParams), isNot(base));
      final otherSalt = Uint8List.fromList(salt)..[15] ^= 1;
      expect(await run('fake-password', otherSalt, fastParams), isNot(base));
      final otherParams = KdfParams(memKib: 16, iterations: 1);
      expect(await run('fake-password', salt, otherParams), isNot(base));
    });

    test('argon2id_不清除调用方的密码', () async {
      final password = Sensitive(Uint8List.fromList('fake-password'.codeUnits));
      await crypto.argon2id(password, salt, fastParams);
      expect(password.isWiped, isFalse);
      expect(password.use((b) => b.length), 13);
    });

    test('argon2id_salt长度不对或密码为空_抛出参数错误', () async {
      final password = Sensitive(Uint8List.fromList('x'.codeUnits));
      await expectLater(
        crypto.argon2id(password, Uint8List(15), fastParams),
        throwsArgumentError,
      );
      await expectLater(
        crypto.argon2id(Sensitive(Uint8List(0)), salt, fastParams),
        throwsArgumentError,
      );
    });

    test('argon2id_在其他isolate中运行_调用方isolate不被阻塞', () async {
      // 用默认参数（64 MiB）跑一次，同时在本 isolate 上计时器照常触发。
      var ticks = 0;
      final timer = Stream<void>.periodic(const Duration(milliseconds: 1))
          .listen((_) => ticks++);
      final out = await crypto.argon2id(
        Sensitive(Uint8List.fromList('fake-password'.codeUnits)),
        salt,
        KdfParams.vaultDefault,
      );
      await timer.cancel();
      expect(out, hasLength(32));
      expect(ticks, greaterThan(0));
    });
  });

  group('KdfParams', () {
    test('KdfParams_默认值_64MiB迭代3并行1', () {
      expect(KdfParams.vaultDefault.memKib, 65536);
      expect(KdfParams.vaultDefault.iterations, 3);
      expect(KdfParams.vaultDefault.parallelism, 1);
    });

    test('KdfParams_并行度不为1或超出范围_抛出参数错误', () {
      expect(
        () => KdfParams(memKib: 65536, iterations: 3, parallelism: 2),
        throwsArgumentError,
      );
      expect(() => KdfParams(memKib: 7, iterations: 3), throwsArgumentError);
      expect(
        () => KdfParams(memKib: KdfParams.maxMemKib + 1, iterations: 3),
        throwsArgumentError,
      );
      expect(() => KdfParams(memKib: 64, iterations: 0), throwsArgumentError);
      expect(() => KdfParams(memKib: 64, iterations: 33), throwsArgumentError);
    });

    test('KdfParams_值相等与toString', () {
      expect(KdfParams(memKib: 8, iterations: 1), fastParams);
      expect(KdfParams(memKib: 8, iterations: 1).hashCode, fastParams.hashCode);
      expect(fastParams, isNot(KdfParams(memKib: 8, iterations: 2)));
      expect(fastParams.toString(), contains('memKib: 8'));
    });
  });

  group('deriveSubkey', () {
    final master = Uint8List.fromList(List.filled(32, 0x42));

    test('deriveSubkey_相同输入稳定；上下文或id不同_子密钥不同', () {
      final a = tohex(crypto.deriveSubkey(master, 'ow_items', 1));
      expect(tohex(crypto.deriveSubkey(master, 'ow_items', 1)), a);
      expect(tohex(crypto.deriveSubkey(master, 'ow_fprnt', 1)), isNot(a));
      expect(tohex(crypto.deriveSubkey(master, 'ow_items', 2)), isNot(a));
      final other = Uint8List.fromList(master)..[0] ^= 1;
      expect(tohex(crypto.deriveSubkey(other, 'ow_items', 1)), isNot(a));
      expect(crypto.deriveSubkey(master, 'ow_items', 1), hasLength(32));
    });

    test('deriveSubkey_上下文不是8个ASCII字节或id为负_抛出参数错误', () {
      expect(
        () => crypto.deriveSubkey(master, 'short', 1),
        throwsArgumentError,
      );
      expect(
        () => crypto.deriveSubkey(master, 'ow_items_', 1),
        throwsArgumentError,
      );
      expect(() => crypto.deriveSubkey(master, '保险库项', 1), throwsArgumentError);
      expect(
        () => crypto.deriveSubkey(master, 'ow_items', -1),
        throwsArgumentError,
      );
      expect(
        () => crypto.deriveSubkey(Uint8List(16), 'ow_items', 1),
        throwsArgumentError,
      );
    });
  });

  group('keyedHash', () {
    final hashKey = Uint8List.fromList(List.filled(32, 0x33));
    final message = Uint8List.fromList('fingerprint input'.codeUnits);

    test('keyedHash_确定性与密钥敏感性', () {
      final a = tohex(crypto.keyedHash(hashKey, message, 16));
      expect(tohex(crypto.keyedHash(hashKey, message, 16)), a);
      final otherKey = Uint8List.fromList(hashKey)..[31] ^= 1;
      expect(tohex(crypto.keyedHash(otherKey, message, 16)), isNot(a));
      final otherMessage = Uint8List.fromList(message)..[0] ^= 1;
      expect(tohex(crypto.keyedHash(hashKey, otherMessage, 16)), isNot(a));
      expect(crypto.keyedHash(hashKey, message, 16), hasLength(16));
    });

    test('keyedHash_密钥或输出长度超出范围_抛出参数错误', () {
      expect(
        () => crypto.keyedHash(Uint8List(15), message, 16),
        throwsArgumentError,
      );
      expect(
        () => crypto.keyedHash(Uint8List(65), message, 16),
        throwsArgumentError,
      );
      expect(() => crypto.keyedHash(hashKey, message, 15), throwsArgumentError);
      expect(() => crypto.keyedHash(hashKey, message, 65), throwsArgumentError);
    });
  });

  test('libraryVersion_为构建钩子编译的libsodium版本', () {
    expect(crypto.libraryVersion, '1.0.22');
  });
}
