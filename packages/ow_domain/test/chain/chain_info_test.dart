import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

/// 以以太坊的字段为默认值构造 [ChainInfo]，供值相等测试逐字段替换。
ChainInfo ethLike({
  String id = 'ethereum',
  ChainFamily family = ChainFamily.evm,
  String name = 'Ethereum',
  String nativeSymbol = 'ETH',
  int nativeDecimals = 18,
  int? evmChainId = 1,
  String explorerAddressUrl = 'https://etherscan.io/address/{address}',
}) => ChainInfo(
  id: id,
  family: family,
  name: name,
  nativeSymbol: nativeSymbol,
  nativeDecimals: nativeDecimals,
  evmChainId: evmChainId,
  explorerAddressUrl: explorerAddressUrl,
);

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

  group('ChainInfo 值语义', () {
    final base = ethLike();

    test('ChainInfo_字段与内置链相同_相等且哈希相同', () {
      const same = ChainInfo(
        id: 'ethereum',
        family: ChainFamily.evm,
        name: 'Ethereum',
        nativeSymbol: 'ETH',
        nativeDecimals: 18,
        evmChainId: 1,
        explorerAddressUrl: 'https://etherscan.io/address/{address}',
      );
      expect(same, base);
      expect(same, Chains.byId('ethereum'));
      expect(same.hashCode, base.hashCode);
    });

    test('ChainInfo_任一字段不同_不相等', () {
      expect(ethLike(id: 'base'), isNot(base));
      expect(ethLike(family: ChainFamily.solana), isNot(base));
      expect(ethLike(name: 'Ethereum Mainnet'), isNot(base));
      expect(ethLike(nativeSymbol: 'WETH'), isNot(base));
      expect(ethLike(nativeDecimals: 8), isNot(base));
      expect(ethLike(evmChainId: null), isNot(base));
      expect(
        ethLike(explorerAddressUrl: 'https://x.test/{address}'),
        isNot(base),
      );
    });

    test('toString_含链id', () {
      expect(base.toString(), 'ChainInfo(ethereum)');
    });

    test('Chains.all_列表不可修改', () {
      expect(() => Chains.all.add(base), throwsUnsupportedError);
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
