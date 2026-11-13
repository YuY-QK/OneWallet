import 'dart:convert';
import 'dart:typed_data';

import 'package:ow_domain/ow_domain.dart';
import 'package:ow_vault/ow_vault.dart';
import 'package:ow_vault/src/vault/vault_file.dart';
import 'package:test/test.dart';

import '../support/hex.dart';
import '../support/vault_fixtures.dart';

/// 文件整体校验值 `mac`（SECURITY_DESIGN 5.1）：精确编码与它能检测到的篡改。
void main() {
  late SodiumVaultCrypto crypto;
  late MemoryVaultStorage storage;
  late Sensitive master;
  const password = 'fake-master-password';

  setUpAll(() async => crypto = await SodiumVaultCrypto.load());
  setUp(() async {
    storage = MemoryVaultStorage();
    final vault = Vault(
      crypto: crypto,
      storage: storage,
      defaultParams: fastParams,
    );
    final s = okValue(await vault.create(sensitive(password)));
    okValue(await s.addItem('m1', mnemonicSecret(abandon)));
    okValue(await s.addItem('k1', privateKeySecret()));
    okValue(await s.addItem('k2', privateKeySecret(0x12)));
    master = s.exportMasterKey();
    s.close();
  });

  Vault fresh() =>
      Vault(crypto: crypto, storage: storage, defaultParams: fastParams);
  Future<Failure> passwordFailure() async =>
      errOf(await fresh().unlockWithPassword(sensitive(password)));
  Future<Failure> masterKeyFailure() async =>
      errOf(await fresh().unlockWithMasterKey(master));
  List<Object?> itemsOf(Map<String, Object?> json) =>
      json['items']! as List<Object?>;

  /// 改动后：主密码解锁报损坏，主密钥解锁报主密钥不符。
  Future<void> expectDetected() async {
    final f = await passwordFailure();
    expect(f, isA<VaultCorruptedFailure>());
    expect(f.detail, 'mac_mismatch');
    expect(await masterKeyFailure(), isA<WrongPasswordFailure>());
  }

  group('精确编码', () {
    test('macInput_固定输入_与文档定义的字节一致', () {
      final file = VaultFile(
        version: 1,
        salt: Uint8List.fromList(List.filled(16, 1)),
        kdfParams: KdfParams(memKib: 8, iterations: 1),
        wrapNonce: Uint8List.fromList(List.filled(24, 2)),
        wrapCiphertext: Uint8List.fromList(List.filled(48, 3)),
        items: [
          VaultFileItem(
            id: 'a',
            kind: VaultItemKind.mnemonic,
            nonce: Uint8List.fromList(List.filled(24, 4)),
            ciphertext: Uint8List.fromList(List.filled(17, 5)),
          ),
        ],
        mac: Uint8List(0),
      );
      final m = file.macInput();
      expect(
        tohex(m),
        '000f6f6e6577616c6c65742d7661756c74' // lp("onewallet-vault")
        '000866696c655f6d6163' // lp("file_mac")
        '0001' // u16be(version)
        '00086172676f6e326964' // lp("argon2id")
        '00000008'
        '00000001'
        '00000001' // mem_kib、iters、parallelism
        '0010${'01' * 16}' // lp(salt)
        '0018${'02' * 24}' // lp(wrap nonce)
        '0030${'03' * 48}' // lp(wrap ct)
        '00000001' // 条目数
        '000161' // lp("a")
        '00086d6e656d6f6e6963' // lp("mnemonic")
        '0018${'04' * 24}' // lp(nonce)
        '0011${'05' * 17}', // lp(ct)
      );
      // K_mac = crypto_kdf(VMK = 32×0x42, 编号 1, "ow_fmac_")；mac = BLAKE2b(K_mac, M, 32)。
      // 期望值用 Python hashlib.blake2b 独立算出。
      final macKey = crypto.deriveSubkey(
        Uint8List.fromList(List.filled(32, 0x42)),
        'ow_fmac_',
        1,
      );
      expect(
        tohex(crypto.keyedHash(macKey, m, 32)),
        '3c154ee8c85287836599a3ed0da45e803ce5e64a70e47db740ee94afcf5a037c',
      );
    });

    test('encode_尚未计算mac_抛出StateError', () {
      final file = okValue(VaultFile.decode(storage.bytes!));
      expect(file.withoutItem('m1').encode, throwsStateError);
    });

    test('每次写入都重新计算mac', () async {
      final s = okValue(await fresh().unlockWithPassword(sensitive(password)));
      final initial = storage.json['mac'];
      okValue(await s.addItem('k3', privateKeySecret(0x13)));
      final added = storage.json['mac'];
      expect(added, isNot(initial));
      okValue(await s.deleteItem('k3'));
      // 删回原来的内容，mac 也回到原值（mac 是内容的确定性函数）。
      expect(storage.json['mac'], initial);
      okValue(await s.changePassword(sensitive('new-fake-password')));
      expect(storage.json['mac'], isNot(initial));
      s.close();
      okValue(await fresh().unlockWithPassword(sensitive('new-fake-password')))
          .close();
      okValue(await fresh().unlockWithMasterKey(master)).close();
    });
  });

  group('能检测到的篡改', () {
    test('删除一个条目_被检测到', () async {
      final json = storage.json;
      itemsOf(json).removeAt(1);
      storage.json = json;
      await expectDetected();
    });

    test('调换条目顺序_被检测到', () async {
      final json = storage.json;
      final items = itemsOf(json);
      final first = items.removeAt(0);
      items.add(first);
      storage.json = json;
      await expectDetected();
    });

    test('插入从另一个保险库复制来的合法条目_被检测到', () async {
      final other = MemoryVaultStorage();
      final s = okValue(
        await Vault(
          crypto: crypto,
          storage: other,
          defaultParams: fastParams,
        ).create(sensitive(password)),
      );
      okValue(await s.addItem('x1', privateKeySecret(0x33)));
      s.close();
      final json = storage.json;
      itemsOf(json).add(MemoryVaultStorage.itemOf(other.json, 0));
      storage.json = json;
      await expectDetected();
    });

    test('插入本库旧版本中的条目（已删除的条目）_被检测到', () async {
      final before = storage.json;
      final s = okValue(await fresh().unlockWithPassword(sensitive(password)));
      okValue(await s.deleteItem('k2'));
      s.close();
      final json = storage.json;
      itemsOf(json).add(MemoryVaultStorage.itemOf(before, 2));
      storage.json = json;
      await expectDetected();
    });

    test('mac自身任一字节被改_被检测到', () async {
      final original = Uint8List.fromList(storage.bytes!);
      final mac = base64.decode(storage.json['mac']! as String);
      for (var i = 0; i < mac.length; i++) {
        storage.bytes = Uint8List.fromList(original);
        final json = storage.json;
        json['mac'] = base64.encode(Uint8List.fromList(mac)..[i] ^= 0x80);
        storage.json = json;
        await expectDetected();
      }
    });

    test('去掉mac字段_视为损坏', () async {
      final json = storage.json..remove('mac');
      storage.json = json;
      expect(await passwordFailure(), isA<VaultCorruptedFailure>());
      expect(await masterKeyFailure(), isA<VaultCorruptedFailure>());
    });

    test('修改kdf参数但保留原包裹_主密码解锁仍先表现为密码错误', () async {
      // 参数变了，派生出的 KEK_pw 就不同，包裹先解不开；这一行为不变。
      final json = storage.json;
      (json['kdf']! as Map<String, Object?>)['iters'] = 2;
      storage.json = json;
      expect(await passwordFailure(), isA<WrongPasswordFailure>());
      // mac 覆盖 kdf 参数，所以主密钥解锁同样发现文件被改。
      expect(await masterKeyFailure(), isA<WrongPasswordFailure>());
    });

    test('未被改动的文件_两种解锁都成功', () async {
      okValue(await fresh().unlockWithPassword(sensitive(password))).close();
      final s = okValue(await fresh().unlockWithMasterKey(master));
      expect(okValue(await s.readItem('k2')).kind, VaultItemKind.privateKey);
    });
  });
}
