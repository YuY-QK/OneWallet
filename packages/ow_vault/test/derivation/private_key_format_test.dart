import 'dart:convert';
import 'dart:typed_data';

import 'package:blockchain_utils/blockchain_utils.dart' hide Err, Ok, Result;
import 'package:ow_domain/ow_domain.dart';
import 'package:ow_vault/private_key_format.dart';
import 'package:test/test.dart';

Sensitive sensitiveString(String s) =>
    Sensitive(Uint8List.fromList(utf8.encode(s)));

void main() {
  group('T16 PrivateKeyFormat', () {
    group('EVM', () {
      // 公开测试向量：Foundry / Hardhat 默认账户 0
      // 私钥: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
      // 期望地址: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 (EIP-55)
      const privHex =
          'ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
      const expectedAddr = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';

      test('合法输入（带0x、不带0x、大写、有空白）均可规范化', () {
        for (final input in [
          privHex,
          '0x$privHex',
          '0X${privHex.toUpperCase()}',
          '  0x$privHex  \n',
        ]) {
          final res = PrivateKeyFormat.normalize(
            ChainFamily.evm,
            sensitiveString(input),
          );
          expect(res.isOk, isTrue);
          final norm = res.valueOrNull!;
          norm.use((bytes) {
            expect(utf8.decode(bytes), privHex.toLowerCase());
          });
          expect(
            PrivateKeyFormat.addressOf(ChainFamily.evm, norm),
            expectedAddr,
          );
        }
      });

      test('非法输入被拒绝且detail不含私钥', () {
        for (final bad in [
          '',
          '   ',
          '0x123', // 过短
          'zz' * 32, // 非十六进制
          '00' * 32, // secp256k1 无效（为0）
          'ff' * 32, // secp256k1 溢出
        ]) {
          final res = PrivateKeyFormat.normalize(
            ChainFamily.evm,
            sensitiveString(bad),
          );
          expect(res.isOk, isFalse);
          final failure = (res as Err<Sensitive>).failure;
          expect(failure, isA<ValidationFailure>());
          if (bad.trim().isNotEmpty) {
            expect(failure.detail, isNot(contains(bad)));
          }
        }
      });
    });

    group('Tron', () {
      // 相同私钥，Tron 格式相同（64位 hex），派生 Tron 地址
      const privHex =
          'ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';

      test('合法输入与地址派生', () {
        final res = PrivateKeyFormat.normalize(
          ChainFamily.tron,
          sensitiveString('0x$privHex'),
        );
        expect(res.isOk, isTrue);
        final norm = res.valueOrNull!;
        final addr = PrivateKeyFormat.addressOf(ChainFamily.tron, norm);
        expect(addr.startsWith('T'), isTrue);
      });
    });

    group('Bitcoin', () {
      // 公开压缩 WIF 向量
      const compressedWif =
          'KwdMAjGmerYanjeui5SHS7JkmpZvVipYvB2LJGU1ZxJwYvP98617';

      test('压缩 WIF 规范化与各地址派生', () {
        final res = PrivateKeyFormat.normalize(
          ChainFamily.bitcoin,
          sensitiveString('  $compressedWif  '),
        );
        expect(res.isOk, isTrue);
        final norm = res.valueOrNull!;
        norm.use((bytes) {
          expect(utf8.decode(bytes), compressedWif);
        });

        // 默认 Native Segwit (bc1q...)
        final segwitAddr = PrivateKeyFormat.addressOf(
          ChainFamily.bitcoin,
          norm,
        );
        expect(segwitAddr.startsWith('bc1q'), isTrue);

        // Taproot (bc1p...)
        final taprootAddr = PrivateKeyFormat.addressOf(
          ChainFamily.bitcoin,
          norm,
          bitcoinScheme: DerivationScheme.btcTaproot,
        );
        expect(taprootAddr.startsWith('bc1p'), isTrue);

        // Nested Segwit (3...)
        final nestedAddr = PrivateKeyFormat.addressOf(
          ChainFamily.bitcoin,
          norm,
          bitcoinScheme: DerivationScheme.btcNestedSegwit,
        );
        expect(nestedAddr.startsWith('3'), isTrue);

        // Legacy (1...)
        final legacyAddr = PrivateKeyFormat.addressOf(
          ChainFamily.bitcoin,
          norm,
          bitcoinScheme: DerivationScheme.btcLegacy,
        );
        expect(legacyAddr, '1LoVGDgRs9hTfTNJNuXKSpywcbdvwRXpmK');
      });

      test('非压缩 WIF 只能用于 btcLegacy，其他 scheme 抛 ArgumentError', () {
        final (privBytes, _) = WifDecoder.decode(
          compressedWif,
          netVer: const [0x80],
        );
        final uncompressedWif = WifEncoder.encode(
          privBytes,
          netVer: const [0x80],
          pubKeyMode: PubKeyModes.uncompressed,
        );

        final res = PrivateKeyFormat.normalize(
          ChainFamily.bitcoin,
          sensitiveString(uncompressedWif),
        );
        expect(res.isOk, isTrue);
        final norm = res.valueOrNull!;

        // btcLegacy 成功且为 1 开头的 Legacy 地址
        final legacyAddr = PrivateKeyFormat.addressOf(
          ChainFamily.bitcoin,
          norm,
          bitcoinScheme: DerivationScheme.btcLegacy,
        );
        expect(legacyAddr.startsWith('1'), isTrue);

        // 默认（Native Segwit）应抛异常
        expect(
          () => PrivateKeyFormat.addressOf(ChainFamily.bitcoin, norm),
          throwsArgumentError,
        );
      });

      test('非法 WIF 被拒绝', () {
        for (final bad in [
          '',
          'not-a-wif',
          '5HueCGU8rMjxEXxiPuD5BDku4MkFqeZyd4dZ1jvhTVq9CD45n2tX', // 校验和错
        ]) {
          final res = PrivateKeyFormat.normalize(
            ChainFamily.bitcoin,
            sensitiveString(bad),
          );
          expect(res.isOk, isFalse);
          expect((res as Err<Sensitive>).failure, isA<ValidationFailure>());
        }
      });
    });

    group('Solana', () {
      // 32 字节全 1 测试向量
      final seed32 = Uint8List(32)..fillRange(0, 32, 1);
      final seedBase58 = Base58Encoder.encode(seed32);

      // 64 字节密钥对：seed32 + pubkey
      final edKey = Ed25519PrivateKey.fromBytes(seed32);
      final pubBytes = edKey.publicKey.point.toBytes();
      final keypair64 = Uint8List(64);
      keypair64.setRange(0, 32, seed32);
      keypair64.setRange(32, 64, pubBytes);
      final keypairBase58 = Base58Encoder.encode(keypair64);

      test('32字节种子与64字节密钥对派生相同地址', () {
        final res1 = PrivateKeyFormat.normalize(
          ChainFamily.solana,
          sensitiveString(seedBase58),
        );
        expect(res1.isOk, isTrue);
        final addr1 = PrivateKeyFormat.addressOf(
          ChainFamily.solana,
          res1.valueOrNull!,
        );

        final res2 = PrivateKeyFormat.normalize(
          ChainFamily.solana,
          sensitiveString(keypairBase58),
        );
        expect(res2.isOk, isTrue);
        final addr2 = PrivateKeyFormat.addressOf(
          ChainFamily.solana,
          res2.valueOrNull!,
        );

        expect(addr1, addr2);
        expect(addr1, Base58Encoder.encode(pubBytes));
      });

      test('公私钥不匹配的64字节数据被拒绝', () {
        final badKeypair = Uint8List.fromList(keypair64);
        badKeypair[63] ^= 0x01; // 改动公钥字节
        final badBase58 = Base58Encoder.encode(badKeypair);
        final res = PrivateKeyFormat.normalize(
          ChainFamily.solana,
          sensitiveString(badBase58),
        );
        expect(res.isOk, isFalse);
        expect((res as Err<Sensitive>).failure, isA<ValidationFailure>());
      });

      test('非法 Base58 或长度不对被拒绝', () {
        for (final bad in [
          '',
          '0OIl', // 非 Base58 字符
          Base58Encoder.encode(Uint8List(16)), // 长度非 32/64
        ]) {
          final res = PrivateKeyFormat.normalize(
            ChainFamily.solana,
            sensitiveString(bad),
          );
          expect(res.isOk, isFalse);
        }
      });
    });
  });
}
