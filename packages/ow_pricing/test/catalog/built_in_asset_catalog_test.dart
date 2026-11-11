import 'dart:convert';
import 'dart:io';

import 'package:ow_domain/ow_domain.dart';
import 'package:ow_pricing/ow_pricing.dart';
import 'package:ow_pricing/src/catalog/asset_mappings_data.dart';
import 'package:test/test.dart';

/// 测试在 packages/ow_pricing 下运行（`dart test`），JSON 相对包根目录。
const _jsonPath = 'asset_mappings.json';

final _evmContract = RegExp(r'^0x[0-9a-f]{40}$');

void main() {
  final catalog = BuiltInAssetCatalog();

  group('resolve', () {
    test('同一币种的多链合约解析到同一个 Asset', () {
      final eth = catalog.resolve(
        const ContractToken(
          'ethereum',
          '0xdac17f958d2ee523a2206206994597c13d831ec7',
        ),
      );
      final bsc = catalog.resolve(
        const ContractToken(
          'bsc',
          '0x55d398326f99059ff775485246999027b3197955',
        ),
      );
      final tron = catalog.resolve(
        const ContractToken('tron', 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t'),
      );
      final sol = catalog.resolve(
        const ContractToken(
          'solana',
          'Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB',
        ),
      );
      expect(eth, isNotNull);
      expect(eth!.id, 'USDT');
      expect(eth.priceId, 'tether');
      expect(bsc, same(eth));
      expect(tron, same(eth));
      expect(sol, same(eth));
    });

    test('arbitrum、optimism、base 的原生币解析到同一个 ETH', () {
      final eth = catalog.resolve(const NativeToken('ethereum'));
      expect(eth!.id, 'ETH');
      for (final chain in ['arbitrum', 'optimism', 'base']) {
        expect(catalog.resolve(NativeToken(chain)), same(eth), reason: chain);
      }
    });

    test('九条链的原生币都能解析', () {
      final expected = {
        'ethereum': 'ETH',
        'bsc': 'BNB',
        'arbitrum': 'ETH',
        'optimism': 'ETH',
        'base': 'ETH',
        'polygon': 'POL',
        'bitcoin': 'BTC',
        'solana': 'SOL',
        'tron': 'TRX',
      };
      expect(expected.keys.toSet(), Chains.all.map((c) => c.id).toSet());
      expected.forEach((chain, id) {
        expect(catalog.resolve(NativeToken(chain))?.id, id, reason: chain);
      });
    });

    test('未知合约、未知链返回 null', () {
      expect(
        catalog.resolve(
          const ContractToken(
            'ethereum',
            '0x0000000000000000000000000000000000000001',
          ),
        ),
        isNull,
      );
      expect(catalog.resolve(const ContractToken('nochain', '0xabc')), isNull);
      expect(catalog.resolve(const NativeToken('nochain')), isNull);
    });

    test('EVM 合约大小写不敏感', () {
      // EIP-55 混合大小写写法
      final mixed = catalog.resolve(
        const ContractToken(
          'ethereum',
          '0xdAC17F958D2ee523a2206206994597C13D831ec7',
        ),
      );
      final upper = catalog.resolve(
        const ContractToken(
          'ethereum',
          '0xDAC17F958D2EE523A2206206994597C13D831EC7',
        ),
      );
      expect(mixed?.id, 'USDT');
      expect(upper?.id, 'USDT');
    });

    test('合约在错误的链上不会匹配', () {
      expect(
        catalog.resolve(
          const ContractToken(
            'polygon',
            '0xdac17f958d2ee523a2206206994597c13d831ec7',
          ),
        ),
        isNull,
      );
    });

    test('Solana 与 Tron 合约区分大小写（原样比较）', () {
      expect(
        catalog.resolve(
          const ContractToken(
            'solana',
            'epjfwdd5aufqsqeM2qn1xzybapc8g4weggkzwytdt1v',
          ),
        ),
        isNull,
      );
    });

    test('交易所符号默认规则：大写后与标准币种 id 相同', () {
      for (final symbol in ['usdt', 'USDT', ' Usdt ']) {
        final asset = catalog.resolve(
          ExchangeToken(ExchangeId.binance, symbol),
        );
        expect(asset?.id, 'USDT', reason: symbol);
      }
      expect(
        catalog.resolve(const ExchangeToken(ExchangeId.okx, 'NOPE')),
        isNull,
      );
      expect(catalog.resolve(const ExchangeToken(ExchangeId.okx, '')), isNull);
    });

    test('交易所别名优先于默认规则', () {
      final custom = BuiltInAssetCatalog.fromJson(
        jsonEncode({
          'assets': [
            _asset('BTC', 'bitcoin', native: ['bitcoin']),
            _asset('XBT', 'other-xbt'),
          ],
          'exchangeAliases': {
            'okx': {'xbt': 'BTC'},
          },
        }),
      );
      expect(
        custom.resolve(const ExchangeToken(ExchangeId.okx, 'XBT'))?.id,
        'BTC',
      );
      // 其他交易所不受影响
      expect(
        custom.resolve(const ExchangeToken(ExchangeId.binance, 'XBT'))?.id,
        'XBT',
      );
    });
  });

  group('byId', () {
    test('存在与不存在', () {
      expect(catalog.byId('USDC')?.priceId, 'usd-coin');
      expect(catalog.byId('usdc'), isNull);
      expect(catalog.byId('NOPE'), isNull);
    });

    test('必须收录的五个币种在尽可能多的链上有合约', () {
      for (final id in ['USDT', 'USDC', 'DAI', 'WETH', 'WBTC']) {
        final asset = catalog.byId(id);
        expect(asset, isNotNull, reason: id);
        final chains = catalog.contracts
            .where((c) => c.asset == asset)
            .map((c) => c.token.chainId)
            .toSet();
        expect(chains, contains('ethereum'), reason: id);
        expect(chains.length, greaterThanOrEqualTo(4), reason: id);
      }
    });
  });

  group('数据结构校验', () {
    test('币种 id 唯一、均有 priceId、id 为大写', () {
      final ids = catalog.assets.map((a) => a.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final a in catalog.assets) {
        expect(a.priceId, isNotNull, reason: a.id);
        expect(a.priceId, isNotEmpty, reason: a.id);
        expect(a.id, a.id.toUpperCase());
        expect(a.symbol, isNotEmpty);
        expect(a.name, isNotEmpty);
      }
    });

    test('每条链 id 都在 Chains 中；EVM 合约为 0x 加 40 位小写十六进制', () {
      for (final c in catalog.contracts) {
        final chain = Chains.tryById(c.token.chainId);
        expect(chain, isNotNull, reason: c.token.toString());
        if (chain!.family == ChainFamily.evm) {
          expect(c.token.contract, matches(_evmContract), reason: c.asset.id);
        } else {
          expect(c.token.contract, isNot(startsWith('0x')));
          expect(c.token.contract.trim(), c.token.contract);
        }
      }
    });

    test('Solana 与 Tron 合约的字符集与长度合理', () {
      final base58 = RegExp(r'^[1-9A-HJ-NP-Za-km-z]+$');
      for (final c in catalog.contracts) {
        if (c.token.chainId == 'solana') {
          expect(c.token.contract, matches(base58));
          expect(c.token.contract.length, inInclusiveRange(32, 44));
        }
        if (c.token.chainId == 'tron') {
          expect(c.token.contract, matches(base58));
          expect(c.token.contract, startsWith('T'));
          expect(c.token.contract.length, 34);
        }
      }
    });

    test('没有重复的 (chainId, contract)', () {
      final keys = catalog.contracts
          .map((c) => '${c.token.chainId}|${c.token.contract.toLowerCase()}')
          .toList();
      expect(keys.toSet().length, keys.length);
    });

    test('所有内置合约都能被 resolve 解析回自己的 Asset', () {
      for (final c in catalog.contracts) {
        expect(catalog.resolve(c.token), c.asset);
      }
    });

    test('收录规模', () {
      expect(catalog.assets.length, greaterThanOrEqualTo(30));
      expect(catalog.contracts.length, greaterThan(100));
    });

    test('异常数据被拒绝', () {
      BuiltInAssetCatalog build(Map<String, Object?> root) =>
          BuiltInAssetCatalog.fromJson(jsonEncode(root));
      expect(
        () => build({
          'assets': [_asset('A', 'a'), _asset('A', 'a2')],
        }),
        throwsFormatException,
      );
      expect(
        () => build({
          'assets': [
            _asset('A', 'a', contracts: {'nochain': 'x'}),
          ],
        }),
        throwsFormatException,
      );
      expect(
        () => build({
          'assets': [
            _asset('A', 'a', contracts: {'solana': 'X'}),
            _asset('B', 'b', contracts: {'solana': 'X'}),
          ],
        }),
        throwsFormatException,
      );
      expect(
        () => build({
          'assets': [
            _asset('A', 'a', contracts: {'ethereum': '0xAB'}),
            _asset('B', 'b', contracts: {'ethereum': '0xab'}),
          ],
        }),
        throwsFormatException,
      );
      expect(
        () => build({
          'assets': [
            {'id': 'A', 'symbol': 'A', 'name': 'A'},
          ],
        }),
        throwsFormatException,
      );
      expect(
        () => build({
          'assets': [_asset('A', 'a')],
          'exchangeAliases': {
            'okx': {'X': 'MISSING'},
          },
        }),
        throwsFormatException,
      );
    });
  });

  group('JSON 与内嵌数据一致', () {
    test('内嵌文本与 asset_mappings.json 逐字相同', () {
      final file = File(_jsonPath).readAsStringSync();
      expect(
        builtInAssetMappingsJson,
        file,
        reason: '请运行 dart run tool/generate_mappings.dart 重新生成',
      );
    });

    test('解析结果与 JSON 文件逐项一致', () {
      final root = jsonDecode(
        File(_jsonPath).readAsStringSync(),
      ) as Map<String, dynamic>;
      final items = (root['assets'] as List).cast<Map<String, dynamic>>();
      expect(catalog.assets.length, items.length);
      var contractCount = 0;
      for (final item in items) {
        final asset = catalog.byId(item['id'] as String)!;
        expect(asset.priceId, item['priceId']);
        expect(asset.name, item['name']);
        for (final chain in (item['native'] as List? ?? const [])) {
          expect(catalog.resolve(NativeToken(chain as String)), asset);
        }
        final contracts = (item['contracts'] as Map? ?? const {})
            .cast<String, String>();
        contracts.forEach((chain, contract) {
          contractCount++;
          expect(catalog.resolve(ContractToken(chain, contract)), asset);
        });
      }
      expect(catalog.contracts.length, contractCount);
    });
  });
}

Map<String, Object?> _asset(
  String id,
  String priceId, {
  List<String> native = const [],
  Map<String, String> contracts = const {},
}) => {
  'id': id,
  'symbol': id,
  'name': id,
  'priceId': priceId,
  'native': native,
  'contracts': contracts,
};
