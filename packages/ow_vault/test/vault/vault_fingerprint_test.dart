import 'dart:typed_data';

import 'package:ow_domain/ow_domain.dart';
import 'package:ow_vault/ow_vault.dart';
import 'package:test/test.dart';

import '../support/vault_fixtures.dart';

/// 查重指纹与默认参数下的完整流程。往返测试见 vault_test.dart。
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

  group('查重指纹', () {
    test('fingerprintOf_同内容相同_不同内容不同_与addItem返回值一致', () async {
      final session = await created();
      final fp = session.fingerprintOf(mnemonicSecret(abandon));
      expect(fp, matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(session.fingerprintOf(mnemonicSecret(abandon)), fp);
      expect(session.fingerprintOf(mnemonicSecret(legal)), isNot(fp));
      expect(
        session.fingerprintOf(mnemonicSecret(abandon, passphrase: 'TREZOR')),
        isNot(fp),
      );
      expect(
        session.fingerprintOf(privateKeySecret()),
        isNot(session.fingerprintOf(privateKeySecret(0x12))),
      );
      final returned = okValue(
        await session.addItem('m1', mnemonicSecret(abandon)),
      );
      expect(returned, fp);
    });

    test('fingerprintOf_不同保险库下同一内容_指纹不同', () async {
      final a = await created();
      final otherVault = Vault(
        crypto: crypto,
        storage: MemoryVaultStorage(),
        defaultParams: fastParams,
      );
      final b = okValue(
        await otherVault.create(sensitive('fake-master-password')),
      );
      expect(
        a.fingerprintOf(mnemonicSecret(abandon)),
        isNot(b.fingerprintOf(mnemonicSecret(abandon))),
      );
    });

    test('fingerprintOf_内容不合法_抛出参数错误', () async {
      final session = await created();
      final empty = MnemonicSecret(mnemonic: Sensitive(Uint8List(0)));
      expect(() => session.fingerprintOf(empty), throwsArgumentError);
    });
  });

  test('默认参数_完整流程一次', () async {
    final real = Vault(
      crypto: crypto,
      storage: storage,
      defaultParams: KdfParams.vaultDefault,
    );
    final session = okValue(
      await real.create(sensitive('default-fake-password')),
    );
    expect((storage.json['kdf']! as Map<String, Object?>)['mem_kib'], 65536);
    okValue(
      await session.addItem(
        'm1',
        mnemonicSecret(abandon, passphrase: 'TREZOR'),
      ),
    );
    okValue(await session.changePassword(sensitive('default-fake-password-2')));
    session.close();
    final again = okValue(
      await real.unlockWithPassword(sensitive('default-fake-password-2')),
    );
    final m1 = okValue(await again.readItem('m1')) as MnemonicSecret;
    expect(textOf(m1.mnemonic), abandon);
    expect(textOf(m1.passphrase!), 'TREZOR');
    again.close();
  });
}
