import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:ow_domain/ow_domain.dart';
import 'package:ow_vault/ow_vault.dart';
import 'package:ow_vault/src/vault/async_mutex.dart';
import 'package:ow_vault/src/vault/item_codec.dart';
import 'package:ow_vault/src/vault/vault_format.dart';
import 'package:test/test.dart';

import '../support/hex.dart';
import '../support/vault_fixtures.dart';

/// AAD 与条目明文的精确字节编码（SECURITY_DESIGN 5.1 的依据），以及异步互斥。
void main() {
  group('AAD 的精确编码', () {
    test('vmkWrapAad_版本1_与文档定义的字节一致', () {
      // lp("onewallet-vault") ‖ lp("wrapped_vmk_pw") ‖ u16be(1)
      expect(
        tohex(vmkWrapAad(1)),
        '000f6f6e6577616c6c65742d7661756c74'
        '000e777261707065645f766d6b5f7077'
        '0001',
      );
    });

    test('itemAad_UUID与私钥类型_与文档定义的字节一致', () {
      // lp("onewallet-vault") ‖ lp("item") ‖ u16be(1) ‖ lp(id) ‖ lp("private_key")
      expect(
        tohex(
          itemAad(
            1,
            '0f8fad5b-d9cb-469f-a165-70867728950e',
            VaultItemKind.privateKey,
          ),
        ),
        '000f6f6e6577616c6c65742d7661756c74'
        '00046974656d'
        '0001'
        '0024'
        '30663866616435622d643963622d343639662d613136352d373038363737323839353065'
        '000b707269766174655f6b6579',
      );
    });

    test('itemAad_id或kind或版本不同_结果不同', () {
      final base = tohex(itemAad(1, 'a', VaultItemKind.mnemonic));
      expect(tohex(itemAad(1, 'b', VaultItemKind.mnemonic)), isNot(base));
      expect(tohex(itemAad(1, 'a', VaultItemKind.privateKey)), isNot(base));
      expect(tohex(itemAad(2, 'a', VaultItemKind.mnemonic)), isNot(base));
      expect(
        () => itemAad(1 << 16, 'a', VaultItemKind.mnemonic),
        throwsArgumentError,
      );
    });

    test('常量_与SECURITY_DESIGN一致', () {
      expect(vaultFormatId, 'onewallet-vault');
      expect(vaultFormatVersion, 1);
      expect(itemKeyContext, 'ow_items');
      expect(fingerprintKeyContext, 'ow_fprnt');
      expect(vaultItemKindFromName('seed'), isNull);
    });
  });

  group('条目明文的规范编码', () {
    String encoded(VaultItemSecret s) => utf8.decode(ItemCodec.encode(s));

    test('encode_三种形式_与文档定义的字节一致', () {
      expect(
        encoded(mnemonicSecret('abandon')),
        '{"v":1,"kind":"mnemonic","mnemonic":"6162616e646f6e","passphrase":null}',
      );
      expect(
        encoded(mnemonicSecret('ab', passphrase: 'T')),
        '{"v":1,"kind":"mnemonic","mnemonic":"6162","passphrase":"54"}',
      );
      expect(
        encoded(mnemonicSecret('ab', passphrase: '')),
        '{"v":1,"kind":"mnemonic","mnemonic":"6162","passphrase":""}',
      );
      for (final (family, name) in [
        (ChainFamily.evm, 'evm'),
        (ChainFamily.bitcoin, 'bitcoin'),
        (ChainFamily.solana, 'solana'),
        (ChainFamily.tron, 'tron'),
      ]) {
        final s = PrivateKeySecret(
          family: family,
          key: Sensitive(Uint8List.fromList([0x00, 0xab, 0xff])),
        );
        expect(
          encoded(s),
          '{"v":1,"kind":"private_key","family":"$name","key":"00abff"}',
        );
      }
    });

    test('decode_编码结果_往返一致', () {
      final m = ItemCodec.decode(
        ItemCodec.encode(mnemonicSecret(legal, passphrase: 'TREZOR')),
      ) as MnemonicSecret;
      expect(textOf(m.mnemonic), legal);
      expect(textOf(m.passphrase!), 'TREZOR');
      final empty = ItemCodec.decode(
        ItemCodec.encode(mnemonicSecret(abandon, passphrase: '')),
      ) as MnemonicSecret;
      expect(empty.passphrase!.use((b) => b.length), 0);
      for (final family in ChainFamily.values) {
        final k = PrivateKeySecret(
          family: family,
          key: Sensitive(fakePrivateKey()),
        );
        final back = ItemCodec.decode(ItemCodec.encode(k)) as PrivateKeySecret;
        expect(back.family, family);
        expect(back.key.use(Uint8List.fromList), fakePrivateKey());
      }
    });

    test('decode_非规范形式_一律返回null', () {
      const bad = [
        '',
        '{}',
        '{"v":2,"kind":"mnemonic","mnemonic":"61","passphrase":null}',
        '{"v":1,"kind":"seed","mnemonic":"61","passphrase":null}',
        '{"v":1,"kind":"mnemonic","mnemonic":"","passphrase":null}',
        '{"v":1,"kind":"mnemonic","mnemonic":"6","passphrase":null}',
        '{"v":1,"kind":"mnemonic","mnemonic":"6A","passphrase":null}',
        '{"v":1,"kind":"mnemonic","mnemonic":"6g","passphrase":null}',
        '{"v":1,"kind":"mnemonic","mnemonic":"61","passphrase":nul}',
        '{"v":1,"kind":"mnemonic","mnemonic":"61","passphrase":"6"}',
        '{"v":1,"kind":"mnemonic","mnemonic":"61","passphrase":"61}',
        '{"v":1,"kind":"mnemonic","mnemonic":"61","passphrase":null} ',
        '{"v":1,"kind":"mnemonic","mnemonic":"61","passphrase":"62"}x',
        '{"v":1,"kind":"mnemonic","mnemonic":"61", "passphrase":null}',
        '{"v":1,"kind":"mnemonic","mnemonic":"61"',
        '{"v":1,"kind":"private_key","family":"eth","key":"11"}',
        '{"v":1,"kind":"private_key","family":"EVM","key":"11"}',
        '{"v":1,"kind":"private_key","family":"evm","key":""}',
        '{"v":1,"kind":"private_key","family":"evm","key":"11"',
        '{"v":1,"kind":"private_key","family":"evm","key":"zz"}',
        '{"v":1,"kind":"private_key","family":"evm"}',
        '{"v":1,"kind":"private_key","family":"aaaaaaaaaaaaaaaaaaaa","key":"11"}',
        '{"v":1,"kind":"private_key","family":"evm,"key":"11"}',
      ];
      for (final text in bad) {
        expect(ItemCodec.decode(utf8.encode(text)), isNull, reason: text);
      }
    });

    test('invalidReason与长度上限', () {
      Sensitive bytes(int n) => Sensitive(Uint8List(n));
      expect(
        ItemCodec.invalidReason(MnemonicSecret(mnemonic: bytes(1024))),
        isNull,
      );
      expect(
        ItemCodec.invalidReason(MnemonicSecret(mnemonic: bytes(1025))),
        'mnemonic_length',
      );
      expect(
        ItemCodec.invalidReason(MnemonicSecret(mnemonic: bytes(0))),
        'mnemonic_length',
      );
      expect(
        ItemCodec.invalidReason(
          MnemonicSecret(mnemonic: bytes(1), passphrase: bytes(1025)),
        ),
        'passphrase_length',
      );
      expect(
        ItemCodec.invalidReason(
          PrivateKeySecret(family: ChainFamily.evm, key: bytes(257)),
        ),
        'private_key_length',
      );
      expect(
        () => ItemCodec.encode(MnemonicSecret(mnemonic: bytes(0))),
        throwsArgumentError,
      );
      final hexTooLong =
          '{"v":1,"kind":"private_key","family":"evm","key":"${'11' * 257}"}';
      expect(ItemCodec.decode(utf8.encode(hexTooLong)), isNull);
    });

    test('toString_不输出内容', () {
      expect(mnemonicSecret(abandon).toString(), isNot(contains('abandon')));
      expect(privateKeySecret().toString(), 'PrivateKeySecret(evm, ***)');
      final s = mnemonicSecret(abandon, passphrase: 'TREZOR')..wipe();
      expect(s.mnemonic.isWiped && s.passphrase!.isWiped, isTrue);
      final k = privateKeySecret()..wipe();
      expect(k.key.isWiped, isTrue);
    });
  });

  group('AsyncMutex', () {
    test('run_按顺序执行且不交错_异常不影响后续', () async {
      final mutex = AsyncMutex();
      final log = <String>[];
      Future<void> step(String name) => mutex.run(() async {
        log.add('$name+');
        await Future<void>.delayed(const Duration(milliseconds: 2));
        log.add('$name-');
      });
      final failing = mutex.run<void>(() async => throw StateError('boom'));
      await Future.wait([
        step('a'),
        step('b'),
        expectLater(failing, throwsStateError),
        step('c'),
      ]);
      expect(log, ['a+', 'a-', 'b+', 'b-', 'c+', 'c-']);
      expect(await mutex.run(() async => 42), 42);
    });

    test('run_同步完成的动作_结果原样返回', () async {
      final mutex = AsyncMutex();
      final c = Completer<int>();
      final r = mutex.run(() => c.future);
      c.complete(7);
      expect(await r, 7);
    });
  });
}
