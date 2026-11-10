import 'package:ow_domain/ow_domain.dart';
import 'package:ow_vault/ow_vault.dart';
import 'package:test/test.dart';

/// 公开的测试助记词（BIP39 官方测试向量），不对应任何真实资产。
const abandon =
    'abandon abandon abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon about';
const legal =
    'legal winner thank year wave sausage worth useful legal winner '
    'thank yellow';

String hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('BIP39', () {
    test('seedFromMnemonic_官方向量_种子一致', () {
      // 来源：BIP39 规范附带的 vectors.json，passphrase 为 TREZOR。
      final seed = AddressDeriver.seedFromMnemonic(
        abandon,
        passphrase: 'TREZOR',
      ).valueOrNull!;
      expect(
        hex(seed),
        'c55257c360c07c72029aebc1b53c05ed0362ada38ead3e3e9efa3708e5349553'
        '1f09a6987599d18264c1e1c92f2cf141630c7a3c4ab7c81b2f001698e7463b04',
      );
    });

    test('isValidMnemonic_校验和正确_通过', () {
      expect(AddressDeriver.isValidMnemonic(abandon), isTrue);
      expect(AddressDeriver.isValidMnemonic(legal), isTrue);
    });

    test('isValidMnemonic_多余空格与大写_仍通过', () {
      expect(
        AddressDeriver.isValidMnemonic(
          '  ${abandon.toUpperCase()}  '.replaceAll(' ', '  '),
        ),
        isTrue,
      );
    });

    test('isValidMnemonic_校验和错误_拒绝', () {
      final bad = abandon.replaceFirst('about', 'abandon');
      expect(AddressDeriver.isValidMnemonic(bad), isFalse);
      expect(AddressDeriver.seedFromMnemonic(bad).isOk, isFalse);
    });

    test('isValidMnemonic_词不在词表_拒绝', () {
      expect(
        AddressDeriver.isValidMnemonic(abandon.replaceFirst('about', 'abouts')),
        isFalse,
      );
    });
  });

  group('deriveAddress', () {
    final seed = AddressDeriver.seedFromMnemonic(abandon).valueOrNull!;
    String at(DerivationScheme s, [int i = 0]) =>
        AddressDeriver.deriveAddress(seed: seed, scheme: s, index: i);

    // 期望值的来源见 docs/ADR_004_地址派生库.md。
    final expected = <(DerivationScheme, int), String>{
      (DerivationScheme.evmStandard, 0):
          '0x9858EfFD232B4033E47d90003D41EC34EcaEda94',
      (DerivationScheme.evmStandard, 1):
          '0x6Fac4D18c912343BF86fa7049364Dd4E424Ab9C0',
      (DerivationScheme.evmLedgerLive, 0):
          '0x9858EfFD232B4033E47d90003D41EC34EcaEda94',
      (DerivationScheme.btcNativeSegwit, 0):
          'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
      (DerivationScheme.btcTaproot, 0):
          'bc1p5cyxnuxmeuwuvkwfem96lqzszd02n6xdcjrs20cac6yqjjwudpxqkedrcr',
      (DerivationScheme.btcNestedSegwit, 0):
          '37VucYSaXLCAsxYyAPfbSi9eh4iEcbShgf',
      (DerivationScheme.btcLegacy, 0): '1LqBGSKuX5yYUonjxT5qGfpUsXKYYWeabA',
      (DerivationScheme.solanaStandard, 0):
          'HAgk14JpMQLgt6rVgv7cBQFJWFto5Dqxi472uT3DKpqk',
      (DerivationScheme.tronStandard, 0): 'TUEZSdKsoDHQMeZwihtdoBiN46zxhGWYdH',
    };

    for (final e in expected.entries) {
      test('${e.key.$1.name}_序号${e.key.$2}_与参考地址一致', () {
        expect(at(e.key.$1, e.key.$2), e.value);
      });
    }

    test('每个方案_前3个序号_互不相同', () {
      for (final s in DerivationScheme.values) {
        final addrs = {for (var i = 0; i < 3; i++) at(s, i)};
        expect(addrs, hasLength(3), reason: s.name);
      }
    });

    test('passphrase_不同_派生出不同地址', () {
      final other = AddressDeriver.seedFromMnemonic(
        abandon,
        passphrase: 'x',
      ).valueOrNull!;
      expect(
        AddressDeriver.deriveAddress(
          seed: other,
          scheme: DerivationScheme.evmStandard,
          index: 0,
        ),
        isNot(at(DerivationScheme.evmStandard)),
      );
    });
  });
}
