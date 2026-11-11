import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

void main() {
  // 与 IMPLEMENTATION_SPEC 2.1 的表逐行对应：id、家族、原生币、evmChainId。
  const expected = <(String, ChainFamily, String, int?)>[
    ('ethereum', ChainFamily.evm, 'ETH', 1),
    ('bsc', ChainFamily.evm, 'BNB', 56),
    ('arbitrum', ChainFamily.evm, 'ETH', 42161),
    ('optimism', ChainFamily.evm, 'ETH', 10),
    ('base', ChainFamily.evm, 'ETH', 8453),
    ('polygon', ChainFamily.evm, 'POL', 137),
    ('bitcoin', ChainFamily.bitcoin, 'BTC', null),
    ('solana', ChainFamily.solana, 'SOL', null),
    ('tron', ChainFamily.tron, 'TRX', null),
  ];

  group('Chains.all', () {
    test('all_内置链表_恰好9条且与规格表一致', () {
      expect(Chains.all, hasLength(9));
      final actual = [
        for (final c in Chains.all)
          (c.id, c.family, c.nativeSymbol, c.evmChainId),
      ];
      expect(actual, expected);
    });

    test('all_每条链_id唯一且浏览器模板含占位符', () {
      expect(Chains.all.map((c) => c.id).toSet(), hasLength(9));
      for (final c in Chains.all) {
        expect(c.explorerAddressUrl, contains('{address}'), reason: c.id);
        expect(c.explorerAddressUrl, startsWith('https://'), reason: c.id);
        expect(c.name, isNotEmpty, reason: c.id);
      }
    });

    test('all_原生币小数位_与各链一致', () {
      final decimals = {for (final c in Chains.all) c.id: c.nativeDecimals};
      expect(decimals['bitcoin'], 8);
      expect(decimals['solana'], 9);
      expect(decimals['tron'], 6);
      for (final c in Chains.ofFamily(ChainFamily.evm)) {
        expect(c.nativeDecimals, 18, reason: c.id);
      }
    });
  });

  group('Chains.byId', () {
    test('byId_已知id_返回对应链', () {
      for (final (id, family, _, _) in expected) {
        final chain = Chains.byId(id);
        expect(chain.id, id);
        expect(chain.family, family);
      }
    });

    test('byId_未知id_抛出ArgumentError', () {
      expect(() => Chains.byId('dogecoin'), throwsArgumentError);
      expect(() => Chains.byId(''), throwsArgumentError);
      expect(() => Chains.byId('Ethereum'), throwsArgumentError);
    });

    test('tryById_未知id_返回null', () {
      expect(Chains.tryById('dogecoin'), isNull);
      expect(Chains.tryById('tron'), same(Chains.byId('tron')));
    });
  });

  group('Chains.ofFamily', () {
    test('ofFamily_evm_返回六条且保持顺序', () {
      expect(Chains.ofFamily(ChainFamily.evm).map((c) => c.id), [
        'ethereum',
        'bsc',
        'arbitrum',
        'optimism',
        'base',
        'polygon',
      ]);
    });

    test('ofFamily_非EVM家族_各一条', () {
      for (final family in [
        ChainFamily.bitcoin,
        ChainFamily.solana,
        ChainFamily.tron,
      ]) {
        expect(Chains.ofFamily(family), hasLength(1), reason: family.name);
      }
    });
  });
}
