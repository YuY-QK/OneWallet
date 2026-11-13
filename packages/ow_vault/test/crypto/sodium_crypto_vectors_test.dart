import 'dart:typed_data';

import 'package:ow_domain/ow_domain.dart';
import 'package:ow_vault/ow_vault.dart';
import 'package:test/test.dart';

import '../support/hex.dart';

/// 已知答案测试。
///
/// - 官方向量：libsodium 测试套件（`test/fixtures/libsodium_vectors.json`，由
///   `extract_libsodium_vectors.py` 从 `sodium` 包随附的 libsodium 源码包提取）；
///   XChaCha20-Poly1305 另用 IETF 草案 draft-irtf-cfrg-xchacha-03 附录 A.3.1。
/// - 独立实现对照（非官方）：`test/fixtures/crosscheck_vectors.json`，由
///   `generate_crosscheck_vectors.py` 用 PyNaCl 与 Python hashlib 生成，覆盖本项目
///   实际使用的输出长度与上下文。
void main() {
  late SodiumVaultCrypto crypto;
  final official = readFixture('libsodium_vectors.json');
  final cross = readFixture('crosscheck_vectors.json');

  setUpAll(() async => crypto = await SodiumVaultCrypto.load());

  group('Argon2id', () {
    for (final (i, v) in objects(official['argon2id']).indexed) {
      final expected = v['expected_hex'] as String?;
      // libsodium 内部把字节数的内存上限按 1024 向下取整为 KiB，
      // 所以传 memlimit ~/ 1024 KiB 得到的 Argon2 参数与原测试完全相同。
      final memKib = (v['memlimit_bytes']! as int) ~/ 1024;
      final params = KdfParams(
        memKib: memKib,
        iterations: v['opslimit']! as int,
      );
      final outLen = v['outlen']! as int;
      test(
        'argon2id_libsodium官方向量${i}_${expected == null ? '输出过短被拒绝' : '输出一致'}',
        () async {
          final password = Sensitive(unhex(v['password_hex']! as String));
          final salt = unhex(v['salt_hex']! as String);
          if (expected == null) {
            await expectLater(
              crypto.argon2idWithLength(password, salt, params, outLen),
              throwsA(anything),
            );
          } else {
            final out = await crypto.argon2idWithLength(
              password,
              salt,
              params,
              outLen,
            );
            expect(tohex(out), expected);
          }
        },
      );
    }

    for (final (i, v) in objects(cross['argon2id_32']).indexed) {
      test('argon2id_32字节输出_与PyNaCl对照一致$i', () async {
        final out = await crypto.argon2id(
          Sensitive(unhex(v['password_hex']! as String)),
          unhex(v['salt_hex']! as String),
          KdfParams(
            memKib: v['mem_kib']! as int,
            iterations: v['iterations']! as int,
          ),
        );
        expect(out, hasLength(32));
        expect(tohex(out), v['expected_hex']);
      });
    }
  });

  group('XChaCha20-Poly1305-IETF', () {
    test('aead_IETF草案A.3.1向量_密文与标签一致且可解密', () {
      // draft-irtf-cfrg-xchacha-03，附录 A.3.1。本环境无法访问 IETF 站点，
      // 向量按草案转录；generate_crosscheck_vectors.py 断言 PyNaCl 得出相同结果。
      final key = Uint8List.fromList(List.generate(32, (i) => 0x80 + i));
      final nonce = Uint8List.fromList(List.generate(24, (i) => 0x40 + i));
      final aad = unhex('50515253c0c1c2c3c4c5c6c7');
      final plaintext = Uint8List.fromList(
        "Ladies and Gentlemen of the class of '99: If I could offer you "
                'only one tip for the future, sunscreen would be it.'
            .codeUnits,
      );
      const ciphertext =
          'bd6d179d3e83d43b9576579493c0e939572a1700252bfaccbed2902c21396cbb'
          '731c7f1b0b4aa6440bf3a82f4eda7e39ae64c6708c54c216cb96b72e1213b452'
          '2f8c9ba40db5d945b11b69b982c1bb9e3f3fac2bc369488f76b2383565d3fff9'
          '21f9664c97637da9768812f615c68b13b52e';
      const tag = 'c0875924c1c7987947deafd8780acf49';
      expect(cross['xchacha_draft_a31'], {'confirmed_by_pynacl': true});

      final sealed = crypto.aeadEncrypt(key, nonce, plaintext, aad);
      expect(tohex(sealed), ciphertext + tag);
      final opened = crypto.aeadDecrypt(key, nonce, sealed, aad);
      expect(opened.valueOrNull, plaintext);
    });

    test('aead_libsodium官方向量_密文一致且可解密', () {
      final v =
          official['aead_xchacha20poly1305_ietf']! as Map<String, Object?>;
      final key = unhex(v['key_hex']! as String);
      final nonce = unhex(v['nonce_hex']! as String);
      final aad = unhex(v['ad_hex']! as String);
      final plaintext = unhex(v['plaintext_hex']! as String);
      final sealed = crypto.aeadEncrypt(key, nonce, plaintext, aad);
      expect(tohex(sealed), v['ciphertext_hex']);
      expect(
        crypto.aeadDecrypt(key, nonce, sealed, aad).valueOrNull,
        plaintext,
      );
    });
  });

  group('crypto_kdf', () {
    final kdf = official['kdf']! as Map<String, Object?>;
    final master = unhex(kdf['master_key_hex']! as String);
    final context = kdf['context']! as String;
    for (final v in objects(kdf['vectors'])) {
      final id = v['subkey_id']! as int;
      final length = v['length']! as int;
      test('deriveSubkey_libsodium官方向量_id$id长度$length一致', () {
        final out = crypto.deriveSubkeyWithLength(master, context, id, length);
        expect(tohex(out), v['expected_hex']);
        if (length == 32) {
          expect(
            tohex(crypto.deriveSubkey(master, context, id)),
            v['expected_hex'],
          );
        }
      });
    }

    for (final v in objects(cross['kdf_32'])) {
      test(
        'deriveSubkey_本项目上下文${v['context']}_id${v['subkey_id']}_与hashlib对照一致',
        () {
          final out = crypto.deriveSubkey(
            unhex(v['master_key_hex']! as String),
            v['context']! as String,
            v['subkey_id']! as int,
          );
          expect(tohex(out), v['expected_hex']);
        },
      );
    }
  });

  group('带密钥的 BLAKE2b', () {
    for (final (i, v) in objects(official['generichash_keyed']).indexed) {
      test('keyedHash_libsodium官方向量${i}_一致', () {
        final out = crypto.keyedHash(
          unhex(v['key_hex']! as String),
          unhex(v['in_hex']! as String),
          64,
        );
        expect(tohex(out), v['out_hex']);
      });
    }

    for (final (i, v) in objects(cross['keyed_hash']).indexed) {
      test('keyedHash_与hashlib对照一致$i', () {
        final out = crypto.keyedHash(
          unhex(v['key_hex']! as String),
          unhex(v['message_hex']! as String),
          v['length']! as int,
        );
        expect(tohex(out), v['expected_hex']);
      });
    }
  });
}
