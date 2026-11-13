import 'dart:convert';
import 'dart:typed_data';

import 'package:ow_domain/ow_domain.dart';
import 'package:ow_vault/ow_vault.dart';
import 'package:test/test.dart';

import '../support/hex.dart';
import '../support/vault_fixtures.dart';

/// 篡改、格式、版本、明文泄露与写入失败。
void main() {
  late SodiumVaultCrypto crypto;
  late MemoryVaultStorage storage;
  late Vault vault;
  const password = 'fake-master-password';

  setUpAll(() async => crypto = await SodiumVaultCrypto.load());
  setUp(() async {
    storage = MemoryVaultStorage();
    vault = Vault(crypto: crypto, storage: storage, defaultParams: fastParams);
    final s = okValue(await vault.create(sensitive(password)));
    okValue(
      await s.addItem('m1', mnemonicSecret(abandon, passphrase: 'TREZOR')),
    );
    okValue(await s.addItem('k1', privateKeySecret()));
    s.close();
  });

  /// 用新的 Vault 实例（模拟重新启动）以密码解锁当前存储。
  Future<Result<VaultSession>> unlock() => Vault(
    crypto: crypto,
    storage: storage,
    defaultParams: fastParams,
  ).unlockWithPassword(sensitive(password));

  Future<Failure> readFailure(String id) async {
    final session = okValue(await unlock());
    try {
      return errOf(await session.readItem(id));
    } finally {
      session.close();
    }
  }

  group('AAD 生效', () {
    test('两个条目的密文互换_读取任一条都失败', () async {
      final json = storage.json;
      final a = MemoryVaultStorage.itemOf(json, 0);
      final b = MemoryVaultStorage.itemOf(json, 1);
      for (final field in ['nonce', 'ct']) {
        final t = a[field];
        a[field] = b[field];
        b[field] = t;
      }
      storage.json = json;
      expect(await readFailure('m1'), isA<VaultCorruptedFailure>());
      expect(await readFailure('k1'), isA<VaultCorruptedFailure>());
    });

    test('条目的kind被改_读取失败', () async {
      final json = storage.json;
      MemoryVaultStorage.itemOf(json, 0)['kind'] = 'private_key';
      MemoryVaultStorage.itemOf(json, 1)['kind'] = 'mnemonic';
      storage.json = json;
      expect(await readFailure('m1'), isA<VaultCorruptedFailure>());
      expect(await readFailure('k1'), isA<VaultCorruptedFailure>());
    });

    test('条目的id被改_用新id读取失败', () async {
      final json = storage.json;
      MemoryVaultStorage.itemOf(json, 0)['id'] = 'm9';
      storage.json = json;
      expect(await readFailure('m9'), isA<VaultCorruptedFailure>());
      expect(await readFailure('m1'), isA<VaultItemNotFoundFailure>());
    });
  });

  group('篡改', () {
    Future<void> flipEachByte(
      String Function(Map<String, Object?> json) get,
      void Function(Map<String, Object?> json, String value) set,
      Future<void> Function() expectFailure,
    ) async {
      final original = Uint8List.fromList(storage.bytes!);
      final bytes = base64.decode(get(storage.json));
      for (var i = 0; i < bytes.length; i++) {
        storage.bytes = Uint8List.fromList(original);
        final json = storage.json;
        set(json, base64.encode(Uint8List.fromList(bytes)..[i] ^= 0x01));
        storage.json = json;
        await expectFailure();
      }
      storage.bytes = original;
    }

    test('条目密文或nonce的任一字节被改_读取返回VaultCorruptedFailure', () async {
      for (final field in ['ct', 'nonce']) {
        await flipEachByte(
          (j) => MemoryVaultStorage.itemOf(j, 1)[field]! as String,
          (j, v) => MemoryVaultStorage.itemOf(j, 1)[field] = v,
          () async =>
              expect(await readFailure('k1'), isA<VaultCorruptedFailure>()),
        );
      }
      // 另一条不受影响。
      final s = okValue(await unlock());
      expect(okValue(await s.readItem('m1')).kind, VaultItemKind.mnemonic);
    });

    test('密码包裹或salt的任一字节被改_解锁返回WrongPasswordFailure', () async {
      Map<String, Object?> wrap(Map<String, Object?> j) =>
          j['wrapped_vmk_pw']! as Map<String, Object?>;
      Map<String, Object?> kdf(Map<String, Object?> j) =>
          j['kdf']! as Map<String, Object?>;
      Future<void> expectWrong() async =>
          expect(errOf(await unlock()), isA<WrongPasswordFailure>());
      await flipEachByte(
        (j) => wrap(j)['ct']! as String,
        (j, v) => wrap(j)['ct'] = v,
        expectWrong,
      );
      await flipEachByte(
        (j) => wrap(j)['nonce']! as String,
        (j, v) => wrap(j)['nonce'] = v,
        expectWrong,
      );
      await flipEachByte(
        (j) => kdf(j)['salt']! as String,
        (j, v) => kdf(j)['salt'] = v,
        expectWrong,
      );
    });

    test('KDF参数在允许范围内被改_解锁返回WrongPasswordFailure', () async {
      for (final (field, value) in [('mem_kib', 16), ('iters', 2)]) {
        final json = storage.json;
        (json['kdf']! as Map<String, Object?>)[field] = value;
        storage.json = json;
        expect(
          errOf(await unlock()),
          isA<WrongPasswordFailure>(),
          reason: field,
        );
      }
    });

    test('头部字段不合法_返回VaultCorruptedFailure', () async {
      final original = Uint8List.fromList(storage.bytes!);
      final mutations = <String, void Function(Map<String, Object?>)>{
        '算法名': (j) => (j['kdf']! as Map<String, Object?>)['alg'] = 'argon2i',
        '并行度': (j) => (j['kdf']! as Map<String, Object?>)['parallelism'] = 2,
        '内存过大': (j) => (j['kdf']! as Map<String, Object?>)['mem_kib'] = 1 << 30,
        '内存过小': (j) => (j['kdf']! as Map<String, Object?>)['mem_kib'] = 4,
        '迭代为0': (j) => (j['kdf']! as Map<String, Object?>)['iters'] = 0,
        '迭代不是整数': (j) => (j['kdf']! as Map<String, Object?>)['iters'] = '3',
        'salt长度': (j) => (j['kdf']! as Map<String, Object?>)['salt'] = base64
            .encode(Uint8List(15)),
        '包裹长度': (j) => (j['wrapped_vmk_pw']! as Map<String, Object?>)['ct'] =
            base64.encode(Uint8List(47)),
        'nonce长度': (j) =>
            (j['wrapped_vmk_pw']! as Map<String, Object?>)['nonce'] = base64
                .encode(Uint8List(12)),
        '非标准base64': (j) => (j['kdf']! as Map<String, Object?>)['salt'] =
            'AAECAwQFBgcICQoLDA0ODw',
        '多出字段': (j) => j['extra'] = true,
        '缺少字段': (j) => j.remove('items'),
        'items不是数组': (j) => j['items'] = {},
        '条目缺字段': (j) => MemoryVaultStorage.itemOf(j, 0).remove('nonce'),
        '条目kind未知': (j) => MemoryVaultStorage.itemOf(j, 0)['kind'] = 'seed',
        '条目id重复': (j) => MemoryVaultStorage.itemOf(j, 1)['id'] = 'm1',
        '条目id不合法': (j) => MemoryVaultStorage.itemOf(j, 0)['id'] = '',
        '条目密文过短': (j) => MemoryVaultStorage.itemOf(j, 0)['ct'] = base64.encode(
          Uint8List(16),
        ),
        '版本为0': (j) => j['version'] = 0,
        '版本不是整数': (j) => j['version'] = '1',
        '版本为小数': (j) => j['version'] = 1.5,
        'format不对': (j) => j['format'] = 'onewallet-backup',
        'format缺失': (j) => j.remove('format'),
      };
      for (final MapEntry(key: name, value: mutate) in mutations.entries) {
        storage.bytes = Uint8List.fromList(original);
        final json = storage.json;
        mutate(json);
        storage.json = json;
        expect(
          errOf(await unlock()),
          isA<VaultCorruptedFailure>(),
          reason: name,
        );
      }
    });

    test('不是JSON或不是UTF-8或不是对象_返回VaultCorruptedFailure', () async {
      for (final bytes in [
        utf8.encode('not json'),
        Uint8List.fromList([0xff, 0xfe, 0x00]),
        utf8.encode('[1,2,3]'),
        Uint8List(0),
        storage.bytes!.sublist(0, storage.bytes!.length - 1),
      ]) {
        storage.bytes = bytes;
        expect(errOf(await unlock()), isA<VaultCorruptedFailure>());
      }
    });

    test('版本高于当前_返回VaultVersionUnsupportedFailure且不改文件', () async {
      final json = storage.json..['version'] = 2;
      // 新版本的结构可能不同，版本判断先于其余字段。
      json['kdf'] = 'something new';
      storage.json = json;
      final before = Uint8List.fromList(storage.bytes!);
      final f = errOf(await unlock());
      expect(f, isA<VaultVersionUnsupportedFailure>());
      expect(f.detail, 'version_2');
      expect(storage.bytes, before);
    });

    test('主密钥解锁_全部条目被篡改_无法校验返回WrongPasswordFailure', () async {
      final s = okValue(await unlock());
      final master = s.exportMasterKey();
      s.close();
      final json = storage.json;
      for (final i in [0, 1]) {
        final item = MemoryVaultStorage.itemOf(json, i);
        final ct = base64.decode(item['ct']! as String)..[0] ^= 1;
        item['ct'] = base64.encode(ct);
      }
      storage.json = json;
      final fresh = Vault(
        crypto: crypto,
        storage: storage,
        defaultParams: fastParams,
      );
      final f = errOf(await fresh.unlockWithMasterKey(master));
      expect(f, isA<WrongPasswordFailure>());
      expect(f.detail, 'master_key_mismatch');
    });
  });

  test('序列化后的文件字节中_搜索不到明文片段', () async {
    final latin = latin1.decode(storage.bytes!);
    final lower = latin.toLowerCase();
    for (final word in {...abandon.split(' '), ...legal.split(' '), 'TREZOR'}) {
      expect(lower, isNot(contains(word.toLowerCase())), reason: word);
    }
    // 条目明文内部以十六进制编码，也要确认十六进制与 Base64 形式都不出现。
    expect(lower, isNot(contains(tohex(utf8.encode('abandon')))));
    expect(lower, isNot(contains('1111111111')));
    expect(
      latin,
      isNot(contains(base64.encode(fakePrivateKey()).substring(0, 12))),
    );
    expect(
      latin,
      isNot(contains(base64.encode(utf8.encode(abandon)).substring(0, 12))),
    );
    final keyBytes = fakePrivateKey();
    for (var i = 0; i + 4 <= storage.bytes!.length; i++) {
      final window = storage.bytes!.sublist(i, i + 4);
      expect(window, isNot(keyBytes.sublist(0, 4)));
    }
  });

  group('写入失败', () {
    test('addItem写入失败_返回UnknownFailure_会话与存储都没变', () async {
      final s = okValue(await unlock());
      final before = Uint8List.fromList(storage.bytes!);
      storage.failBeforeStore = true;
      final f = errOf(await s.addItem('k2', privateKeySecret(0x22)));
      expect(f, isA<UnknownFailure>());
      expect(storage.bytes, before);
      expect(errOf(await s.readItem('k2')), isA<VaultItemNotFoundFailure>());
      // 恢复后同一 id 可以再次添加。
      storage.failBeforeStore = false;
      okValue(await s.addItem('k2', privateKeySecret(0x22)));
      expect(okValue(await s.readItem('k2')).kind, VaultItemKind.privateKey);
    });

    test('写入已落盘但收尾抛异常_按实际存储内容判定为成功', () async {
      final s = okValue(await unlock());
      storage.failAfterStore = true;
      okValue(await s.deleteItem('m1'));
      expect(errOf(await s.readItem('m1')), isA<VaultItemNotFoundFailure>());
      storage.failAfterStore = false;
      expect(await readFailure('m1'), isA<VaultItemNotFoundFailure>());
    });

    test('写入失败且无法确认_删除与改密码都保持原状', () async {
      final s = okValue(await unlock());
      storage.failBeforeStore = true;
      expect(errOf(await s.deleteItem('m1')), isA<UnknownFailure>());
      expect(okValue(await s.readItem('m1')).kind, VaultItemKind.mnemonic);
      expect(
        errOf(await s.changePassword(sensitive('new-fake-password'))),
        isA<UnknownFailure>(),
      );
      storage.failBeforeStore = false;
      s.close();
      expect(okValue(await unlock()), isA<VaultSession>());
    });

    test('create写入失败_返回UnknownFailure且不留下文件', () async {
      final empty = MemoryVaultStorage()..failBeforeStore = true;
      final v = Vault(
        crypto: crypto,
        storage: empty,
        defaultParams: fastParams,
      );
      expect(errOf(await v.create(sensitive(password))), isA<UnknownFailure>());
      expect(empty.bytes, isNull);
    });
  });
}
