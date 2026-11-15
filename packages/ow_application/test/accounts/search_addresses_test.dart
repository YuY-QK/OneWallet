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

  setUp(() async {
    accounts = InMemoryAccountRepository();
    addresses = InMemoryAddressRepository();
    searchAddresses = SearchAddresses(accounts: accounts, addresses: addresses);

    await accounts.upsert(wallet1);
    await accounts.upsert(wallet2);

    await addresses.upsert(evmAddress);
    await addresses.upsert(solAddress);
    await addresses.upsert(btcAddress);
  });

  group('SearchAddresses', () {
    test('空查询词_返回全部匹配链与账户的条目', () async {
      final results = await searchAddresses();
      expect(results, hasLength(3));
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

    test('账户名搜索_匹配所属账户名称', () async {
      final results = await searchAddresses(query: '冷钱包');
      expect(results, hasLength(1));
      expect(results.first.address.id, 'ad3');
      expect(results.first.account.name, '冷钱包');
      expect(results.first.isExactMatch, isFalse);
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
      expect(results, hasLength(1));
      expect(results.first.address.id, 'ad3');
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

    test('精确匹配排序优先于非精确匹配', () {
      final addrExact = WatchAddress(
        id: 'ad4',
        accountId: 'w1',
        family: ChainFamily.bitcoin,
        address: 'bc1qtest',
        enabledChainIds: {'bitcoin'},
      );
      final addrSnippet = WatchAddress(
        id: 'ad5',
        accountId: 'w1',
        family: ChainFamily.bitcoin,
        address: 'bc1qtest123',
        enabledChainIds: {'bitcoin'},
      );

      final out = searchAddresses.execute(
        addresses: [addrSnippet, addrExact],
        accountsById: {'w1': wallet1},
        query: 'bc1qtest',
      );

      expect(out, hasLength(2));
      expect(out[0].address.id, 'ad4');
      expect(out[0].isExactMatch, isTrue);
      expect(out[1].address.id, 'ad5');
      expect(out[1].isExactMatch, isFalse);
    });
  });
}
