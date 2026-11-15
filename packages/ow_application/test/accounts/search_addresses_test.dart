import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

import '../fakes/fake_repositories.dart';

void main() {
  late InMemoryAccountRepository accounts;
  late InMemoryAddressRepository addresses;
  late SearchAddresses searchAddresses;

  final now = DateTime.utc(2026, 11, 15);
  final wallet1 = Account.wallet(
    id: 'w1',
    name: 'Uni 钱包',
    colorIndex: 0,
    createdAt: now,
  );
  final wallet2 = Account.wallet(
    id: 'w2',
    name: '冷钱包',
    colorIndex: 1,
    createdAt: now,
  );

  final evmAddress = WatchAddress(
    id: 'ad1',
    accountId: 'w1',
    family: ChainFamily.evm,
    address: '0x12ab34cd56ef7890ab12cd34ef567890ab129f3c',
    enabledChainIds: {'ethereum', 'arbitrum'},
    scheme: DerivationScheme.evmStandard,
    derivationIndex: 0,
    note: '',
  );

  final solAddress = WatchAddress(
    id: 'ad2',
    accountId: 'w1',
    family: ChainFamily.solana,
    address: '7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU',
    enabledChainIds: {'solana'},
    note: '日常使用',
  );

  final btcAddress = WatchAddress(
    id: 'ad3',
    accountId: 'w2',
    family: ChainFamily.bitcoin,
    address: 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq',
    enabledChainIds: {'bitcoin'},
    note: '长期持有',
  );

  final trxAddress = WatchAddress(
    id: 'ad4',
    accountId: 'w2',
    family: ChainFamily.tron,
    address: 'TQn9Y2khEsLJW1ChVWFMSMeRDow5KcbLSE',
    enabledChainIds: {'tron'},
    note: '波场地址',
  );

  setUp(() async {
    accounts = InMemoryAccountRepository();
    addresses = InMemoryAddressRepository();
    searchAddresses = SearchAddresses(accounts: accounts, addresses: addresses);

    await accounts.upsert(wallet1);
    await accounts.upsert(wallet2);

    await addresses.upsert(evmAddress);
    await addresses.upsert(solAddress);
    await addresses.upsert(btcAddress);
    await addresses.upsert(trxAddress);
  });

  group('SearchAddresses', () {
    test('空查询词_返回全部匹配链与账户的条目', () async {
      final results = await searchAddresses();
      expect(results, hasLength(4));
      expect(results.every((r) => !r.isExactMatch), isTrue);
    });

    test('地址片段搜索_匹配部分地址且不标为精确匹配', () async {
      final results = await searchAddresses(query: '12ab');
      expect(results, hasLength(1));
      expect(results.first.address.id, 'ad1');
      expect(results.first.isExactMatch, isFalse);
    });

    test('完整地址精确搜索_标记为精确匹配且排在首位', () async {
      // 粘贴完整地址（全小写）
      final results = await searchAddresses(
        query: '0x12ab34cd56ef7890ab12cd34ef567890ab129f3c',
      );
      expect(results, hasLength(1));
      expect(results.first.address.id, 'ad1');
      expect(results.first.isExactMatch, isTrue);
    });

    test('完整地址大小写混合或带空格_依然能精确匹配', () async {
      // 模拟用户从别处复制带有大写字符和前后空格的地址
      final results = await searchAddresses(
        query: '  0X12AB34CD56EF7890AB12CD34EF567890AB129F3C  ',
      );
      expect(results, hasLength(1));
      expect(results.first.address.id, 'ad1');
      expect(results.first.isExactMatch, isTrue);
    });

    test('Solana与Tron等Base58地址大小写敏感_大小写改变后isExactMatch为false', () async {
      // 1. Solana: 原始为 7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU
      // 改变大小写后，仍作为片段模糊匹配命中，但 isExactMatch 必须为 false
      final solLower = solAddress.address.toLowerCase();
      final rSol = await searchAddresses(query: solLower);
      expect(rSol, hasLength(1));
      expect(rSol.first.address.id, 'ad2');
      expect(rSol.first.isExactMatch, isFalse);

      // 2. Tron: 原始为 TQn9Y2khEsLJW1ChVWFMSMeRDow5KcbLSE
      // 改变大小写后，isExactMatch 必须为 false
      final trxLower = trxAddress.address.toLowerCase();
      final rTrx = await searchAddresses(query: trxLower);
      expect(rTrx, hasLength(1));
      expect(rTrx.first.address.id, 'ad4');
      expect(rTrx.first.isExactMatch, isFalse);
    });

    test('全大写的BC1地址精确匹配为true', () async {
      // 原始为 bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq
      // BIP173 规范全大写 Bech32 地址在规范化后转为全小写，isExactMatch 应为 true
      final btcUpper = btcAddress.address.toUpperCase();
      final results = await searchAddresses(query: btcUpper);
      expect(results, hasLength(1));
      expect(results.first.address.id, 'ad3');
      expect(results.first.isExactMatch, isTrue);
    });

    test('不带0x的40位十六进制不是EVM精确匹配_isExactMatch为false', () async {
      // 40 位十六进制（缺少 0x 前缀）：作为片段模糊匹配命中，但 isExactMatch 为 false
      const noPrefix = '12ab34cd56ef7890ab12cd34ef567890ab129f3c';
      final results = await searchAddresses(query: noPrefix);
      expect(results, hasLength(1));
      expect(results.first.address.id, 'ad1');
      expect(results.first.isExactMatch, isFalse);
    });

    test('账户名搜索_匹配所属账户名称', () async {
      final results = await searchAddresses(query: '冷钱包');
      expect(results, hasLength(2));
      expect(results.map((r) => r.address.id), containsAll(['ad3', 'ad4']));
      expect(results.every((r) => r.account.name == '冷钱包'), isTrue);
      expect(results.every((r) => !r.isExactMatch), isTrue);
    });

    test('备注搜索_匹配备注文本', () async {
      final results = await searchAddresses(query: '长期持有');
      expect(results, hasLength(1));
      expect(results.first.address.id, 'ad3');
      expect(results.first.address.note, '长期持有');
    });

    test('链家族过滤_仅返回该链家族地址', () async {
      final results = await searchAddresses(family: ChainFamily.solana);
      expect(results, hasLength(1));
      expect(results.first.address.id, 'ad2');
    });

    test('账户过滤_仅返回属于该账户的地址', () async {
      final results = await searchAddresses(accountId: 'w2');
      expect(results, hasLength(2));
      expect(results.map((r) => r.address.id), containsAll(['ad3', 'ad4']));
    });

    test('搜索与过滤组合_同时命中条件时才返回', () async {
      // 搜索 Uni 钱包但限定 Bitcoin 链 -> 无结果
      final r1 = await searchAddresses(
        query: 'Uni',
        family: ChainFamily.bitcoin,
      );
      expect(r1, isEmpty);

      // 搜索 Uni 钱包且限定 EVM 链 -> 命中 EVM 地址
      final r2 = await searchAddresses(query: 'Uni', family: ChainFamily.evm);
      expect(r2, hasLength(1));
      expect(r2.first.address.id, 'ad1');
    });

    test('搜索无匹配_返回空列表', () async {
      final results = await searchAddresses(
        query: '0x9999999999999999999999999999999999999999',
      );
      expect(results, isEmpty);
    });

    test('精确匹配稳定置顶_其余匹配保持原有相对顺序', () {
      final addrSnippet1 = WatchAddress(
        id: 's1',
        accountId: 'w1',
        family: ChainFamily.bitcoin,
        address: 'bc1qtest_alpha',
        enabledChainIds: {'bitcoin'},
      );
      final addrExact = WatchAddress(
        id: 'e1',
        accountId: 'w1',
        family: ChainFamily.bitcoin,
        address: 'bc1qtest',
        enabledChainIds: {'bitcoin'},
      );
      final addrSnippet2 = WatchAddress(
        id: 's2',
        accountId: 'w1',
        family: ChainFamily.bitcoin,
        address: 'bc1qtest_beta',
        enabledChainIds: {'bitcoin'},
      );

      final out = executeSearchAddresses(
        addresses: [addrSnippet1, addrExact, addrSnippet2],
        accountsById: {'w1': wallet1},
        query: 'bc1qtest',
      );

      expect(out, hasLength(3));
      expect(out[0].address.id, 'e1');
      expect(out[0].isExactMatch, isTrue);
      expect(out[1].address.id, 's1');
      expect(out[1].isExactMatch, isFalse);
      expect(out[2].address.id, 's2');
      expect(out[2].isExactMatch, isFalse);
    });
  });
}
