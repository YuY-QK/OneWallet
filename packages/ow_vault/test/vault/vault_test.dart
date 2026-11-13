import 'dart:typed_data';

import 'package:ow_domain/ow_domain.dart';
import 'package:ow_vault/ow_vault.dart';
import 'package:test/test.dart';

import '../support/vault_fixtures.dart';

/// 创建、解锁、增删读、改密码、关闭的往返测试。篡改与格式见 vault_tamper_test.dart。
void main() {
  late SodiumVaultCrypto crypto;
  late MemoryVaultStorage storage;
  late Vault vault;

  setUpAll(() async => crypto = await SodiumVaultCrypto.load());
  setUp(() {
    storage = MemoryVaultStorage();
    vault = Vault(crypto: crypto, storage: storage, defaultParams: fastParams);
  });

  Future<VaultSession> created([
    String password = 'fake-master-password',
  ]) async => okValue(await vault.create(sensitive(password)));

  group('创建与解锁', () {
    test('create_新保险库_文件存在且会话可用', () async {
      expect(await vault.exists(), isFalse);
      final session = await created();
      expect(await vault.exists(), isTrue);
      expect(storage.json['format'], 'onewallet-vault');
      expect(storage.json['version'], 1);
      expect(storage.json['items'], isEmpty);
      session.close();
    });

    test('create_文件已存在_拒绝且不覆盖', () async {
      (await created()).close();
      final before = Uint8List.fromList(storage.bytes!);
      final again = await vault.create(sensitive('another-fake-password'));
      expect(errOf(again), isA<VaultAlreadyExistsFailure>());
      expect(storage.bytes, before);
    });

    test('create_空密码_返回ValidationFailure且不写文件', () async {
      expect(
        errOf(await vault.create(Sensitive(Uint8List(0)))),
        isA<ValidationFailure>(),
      );
      expect(storage.bytes, isNull);
    });

    test('unlockWithPassword_文件不存在_返回VaultNotFoundFailure', () async {
      final r = await vault.unlockWithPassword(
        sensitive('fake-master-password'),
      );
      expect(errOf(r), isA<VaultNotFoundFailure>());
    });

    test('unlockWithPassword_错误密码_WrongPasswordFailure且不泄露信息', () async {
      (await created('fake-master-password')).close();
      for (final wrong in ['fake-master-passwore', '', 'x']) {
        final f = errOf(await vault.unlockWithPassword(sensitive(wrong)));
        expect(f, isA<WrongPasswordFailure>());
        expect(f.detail, isNull);
        expect(f.toString(), 'WrongPasswordFailure');
      }
    });

    test('读取存储失败_返回UnknownFailure', () async {
      (await created()).close();
      storage.failRead = true;
      final f = errOf(
        await vault.unlockWithPassword(sensitive('fake-master-password')),
      );
      expect(f, isA<UnknownFailure>());
      expect(errOf(await vault.create(sensitive('p'))), isA<UnknownFailure>());
    });
  });

  group('条目往返', () {
    test('增读删_助记词带与不带passphrase及私钥_关闭后重新解锁仍可读', () async {
      final session = await created();
      okValue(await session.addItem('m1', mnemonicSecret(abandon)));
      okValue(
        await session.addItem(
          'm2',
          mnemonicSecret(legal, passphrase: 'TREZOR'),
        ),
      );
      okValue(await session.addItem('k1', privateKeySecret()));
      session.close();

      final again = okValue(
        await vault.unlockWithPassword(sensitive('fake-master-password')),
      );
      final m1 = okValue(await again.readItem('m1')) as MnemonicSecret;
      expect(textOf(m1.mnemonic), abandon);
      expect(m1.passphrase, isNull);
      final m2 = okValue(await again.readItem('m2')) as MnemonicSecret;
      expect(textOf(m2.mnemonic), legal);
      expect(textOf(m2.passphrase!), 'TREZOR');
      final k1 = okValue(await again.readItem('k1')) as PrivateKeySecret;
      expect(k1.family, ChainFamily.evm);
      expect(k1.key.use(Uint8List.fromList), fakePrivateKey());

      okValue(await again.deleteItem('m1'));
      expect(
        errOf(await again.readItem('m1')),
        isA<VaultItemNotFoundFailure>(),
      );
      expect(
        errOf(await again.deleteItem('m1')),
        isA<VaultItemNotFoundFailure>(),
      );
      again.close();
      final third = okValue(
        await vault.unlockWithPassword(sensitive('fake-master-password')),
      );
      expect(
        errOf(await third.readItem('m1')),
        isA<VaultItemNotFoundFailure>(),
      );
      expect(
        okValue(await third.readItem('k1')).kind,
        VaultItemKind.privateKey,
      );
      third.close();
    });

    test('readItem_返回的明文由调用方清除不影响再次读取', () async {
      final session = await created();
      okValue(await session.addItem('m1', mnemonicSecret(abandon)));
      final first = okValue(await session.readItem('m1'))..wipe();
      expect((first as MnemonicSecret).mnemonic.isWiped, isTrue);
      final second = okValue(await session.readItem('m1')) as MnemonicSecret;
      expect(textOf(second.mnemonic), abandon);
    });

    test('addItem_不清除调用方传入的明文', () async {
      final session = await created();
      final secret = mnemonicSecret(abandon);
      okValue(await session.addItem('m1', secret));
      expect(secret.mnemonic.isWiped, isFalse);
    });

    test('addItem_id不合法或重复或内容为空_返回ValidationFailure', () async {
      final session = await created();
      okValue(await session.addItem('m1', mnemonicSecret(abandon)));
      for (final id in ['', 'has space', 'a' * 65, '../x', '条目']) {
        expect(
          errOf(await session.addItem(id, mnemonicSecret(abandon))),
          isA<ValidationFailure>(),
        );
      }
      final dup = errOf(await session.addItem('m1', mnemonicSecret(legal)));
      expect(dup, isA<ValidationFailure>());
      expect(dup.detail, 'duplicate_item_id');
      final empty = MnemonicSecret(mnemonic: Sensitive(Uint8List(0)));
      expect(
        errOf(await session.addItem('m2', empty)),
        isA<ValidationFailure>(),
      );
      final emptyKey = PrivateKeySecret(
        family: ChainFamily.tron,
        key: Sensitive(Uint8List(0)),
      );
      expect(
        errOf(await session.addItem('k2', emptyKey)),
        isA<ValidationFailure>(),
      );
      expect(storage.json['items'], hasLength(1));
    });

    test('addItem_UUID形式的id_可保存', () async {
      final session = await created();
      const id = '0f8fad5b-d9cb-469f-a165-70867728950e';
      okValue(await session.addItem(id, privateKeySecret()));
      expect(
        okValue(await session.readItem(id)).kind,
        VaultItemKind.privateKey,
      );
    });

    test('并发写入_同一Vault的多个会话_串行执行且互不覆盖', () async {
      final a = await created();
      final b = okValue(
        await vault.unlockWithPassword(sensitive('fake-master-password')),
      );
      await Future.wait([
        for (var i = 0; i < 6; i++)
          (i.isEven ? a : b).addItem('k$i', privateKeySecret(0x10 + i)),
      ]);
      expect(storage.json['items'], hasLength(6));
      a.close();
      b.close();
      final fresh = Vault(
        crypto: crypto,
        storage: storage,
        defaultParams: fastParams,
      );
      final c = okValue(
        await fresh.unlockWithPassword(sensitive('fake-master-password')),
      );
      for (var i = 0; i < 6; i++) {
        final k = okValue(await c.readItem('k$i')) as PrivateKeySecret;
        expect(k.key.use(Uint8List.fromList), fakePrivateKey(0x10 + i));
      }
    });
  });

  group('主密钥解锁', () {
    test('unlockWithMasterKey_用exportMasterKey的结果_可解锁并读条目', () async {
      final session = await created();
      okValue(await session.addItem('k1', privateKeySecret()));
      final master = session.exportMasterKey();
      session.close();
      final again = okValue(await vault.unlockWithMasterKey(master));
      expect(master.isWiped, isFalse);
      expect(
        okValue(await again.readItem('k1')).kind,
        VaultItemKind.privateKey,
      );
    });

    test('unlockWithMasterKey_错误主密钥或长度不对_WrongPasswordFailure', () async {
      final session = await created();
      okValue(await session.addItem('k1', privateKeySecret()));
      final wrong = errOf(
        await vault.unlockWithMasterKey(Sensitive(Uint8List(32))),
      );
      expect(wrong, isA<WrongPasswordFailure>());
      final short = errOf(
        await vault.unlockWithMasterKey(Sensitive(Uint8List(31))),
      );
      expect(short, isA<WrongPasswordFailure>());
    });

    test('unlockWithMasterKey_空保险库_正确主密钥成功_错误主密钥失败', () async {
      final session = await created();
      final master = session.exportMasterKey();
      session.close();
      final again = okValue(await vault.unlockWithMasterKey(master));
      okValue(await again.addItem('k1', privateKeySecret()));
      again.close();
      // 用主密码仍能读到经主密钥会话写入的条目。
      final viaPassword = okValue(
        await vault.unlockWithPassword(sensitive('fake-master-password')),
      );
      expect(
        okValue(await viaPassword.readItem('k1')).kind,
        VaultItemKind.privateKey,
      );
      viaPassword.close();
    });

    test('unlockWithMasterKey_空保险库_错误主密钥失败', () async {
      (await created()).close();
      final f = errOf(
        await vault.unlockWithMasterKey(Sensitive(Uint8List(32))),
      );
      expect(f, isA<WrongPasswordFailure>());
      expect(f.detail, 'master_key_mismatch');
    });

    test('unlockWithMasterKey_过期主密钥（另一个保险库的VMK）_对空保险库失败', () async {
      final old = await created();
      final stale = old.exportMasterKey();
      old.close();
      // 保险库被删除后重建：新的 VMK，旧的硬件包裹已过期。
      await storage.delete();
      final rebuilt = Vault(
        crypto: crypto,
        storage: storage,
        defaultParams: fastParams,
      );
      okValue(await rebuilt.create(sensitive('fake-master-password'))).close();
      final f = errOf(await rebuilt.unlockWithMasterKey(stale));
      expect(f, isA<WrongPasswordFailure>());
      expect(storage.json['items'], isEmpty);
    });

    test('exportMasterKey_副本被调用方清零_不影响会话', () async {
      final session = await created();
      session.exportMasterKey().wipe();
      okValue(await session.addItem('k1', privateKeySecret()));
      expect(
        okValue(await session.readItem('k1')).kind,
        VaultItemKind.privateKey,
      );
      final master = session.exportMasterKey();
      expect(master.use((b) => b.any((x) => x != 0)), isTrue);
    });
  });

  group('改密码', () {
    test('changePassword_旧密码失效新密码可用_条目仍可读_salt与包裹都变了', () async {
      final session = await created('old-fake-password');
      okValue(await session.addItem('m1', mnemonicSecret(abandon)));
      final before = storage.json;
      final kdfBefore = before['kdf']! as Map<String, Object?>;
      final wrapBefore = before['wrapped_vmk_pw']! as Map<String, Object?>;
      okValue(await session.changePassword(sensitive('new-fake-password')));
      final after = storage.json;
      final kdfAfter = after['kdf']! as Map<String, Object?>;
      final wrapAfter = after['wrapped_vmk_pw']! as Map<String, Object?>;
      expect(kdfAfter['salt'], isNot(kdfBefore['salt']));
      expect(wrapAfter['nonce'], isNot(wrapBefore['nonce']));
      expect(wrapAfter['ct'], isNot(wrapBefore['ct']));
      // VMK 不变，条目密文无需重加密。
      expect(after['items'], before['items']);
      // 会话在改密码后继续可用。
      expect(
        okValue(await session.readItem('m1')).kind,
        VaultItemKind.mnemonic,
      );
      session.close();

      expect(
        errOf(await vault.unlockWithPassword(sensitive('old-fake-password'))),
        isA<WrongPasswordFailure>(),
      );
      final again = okValue(
        await vault.unlockWithPassword(sensitive('new-fake-password')),
      );
      final m1 = okValue(await again.readItem('m1')) as MnemonicSecret;
      expect(textOf(m1.mnemonic), abandon);
    });

    test('changePassword_空密码_ValidationFailure且文件不变', () async {
      final session = await created();
      final before = Uint8List.fromList(storage.bytes!);
      expect(
        errOf(await session.changePassword(Sensitive(Uint8List(0)))),
        isA<ValidationFailure>(),
      );
      expect(storage.bytes, before);
    });
  });

  group('关闭', () {
    test('close之后_任何操作抛StateError_可重复close', () async {
      final session = await created();
      okValue(await session.addItem('k1', privateKeySecret()));
      session.close();
      session.close();
      expect(session.exportMasterKey, throwsStateError);
      expect(() => session.fingerprintOf(privateKeySecret()), throwsStateError);
      await expectLater(session.readItem('k1'), throwsStateError);
      await expectLater(
        session.addItem('k2', privateKeySecret()),
        throwsStateError,
      );
      await expectLater(session.deleteItem('k1'), throwsStateError);
      await expectLater(
        session.changePassword(sensitive('new-fake')),
        throwsStateError,
      );
    });

    test('文件被外部替换后重新解锁_旧会话失效', () async {
      final old = await created('first-fake-password');
      await storage.delete();
      final other = Vault(
        crypto: crypto,
        storage: storage,
        defaultParams: fastParams,
      );
      okValue(await other.create(sensitive('second-fake-password'))).close();
      okValue(await vault.unlockWithPassword(sensitive('second-fake-password')))
          .close();
      await expectLater(
        old.addItem('k1', privateKeySecret()),
        throwsStateError,
      );
      expect(old.exportMasterKey, throwsStateError);
    });
  });
}
