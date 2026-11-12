import 'package:ow_data/ow_data.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  late OwDatabase db;
  late OwRepositories repos;

  setUp(() {
    db = newDb();
    repos = OwRepositories(db);
  });
  tearDown(() => db.close());

  group('AccountRepository', () {
    test('读写往返，含备份状态与 UTC 时间', () async {
      final a = makeAccount('a1').copyWith(
        note: '备注',
        vaultItemId: 'v1',
        backup: BackupStatus(offlineBackedUp: true, offlineVerifiedAt: t0),
      );
      await repos.accounts.upsert(a);
      final back = await repos.accounts.byId('a1');
      expect(back, a);
      expect(back!.createdAt.isUtc, isTrue);
      expect(await repos.accounts.byId('nope'), isNull);
    });

    test('upsert 更新已有账户且不丢子表数据', () async {
      await repos.accounts.upsert(makeAccount('a1'));
      await repos.addresses.upsert(makeAddress('ad1', 'a1'));
      await repos.accounts.upsert(makeAccount('a1').copyWith(name: '新名字'));
      expect((await repos.accounts.byId('a1'))!.name, '新名字');
      expect(await repos.addresses.byAccount('a1'), hasLength(1));
    });

    test('insertWithAddresses 一并写入账户与全部地址', () async {
      await repos.accounts.insertWithAddresses(makeAccount('a1'), [
        makeAddress('ad1', 'a1'),
        makeAddress('ad2', 'a1', address: '0xdef'),
      ]);
      expect(await repos.accounts.byId('a1'), isNotNull);
      expect(await repos.addresses.byAccount('a1'), hasLength(2));
    });

    test('insertWithAddresses 第二个地址冲突：整体回滚，账户和第一个地址都不留下', () async {
      await repos.accounts.upsert(makeAccount('a0'));
      await repos.addresses.upsert(makeAddress('ad0', 'a0', address: '0xdef'));

      await expectLater(
        repos.accounts.insertWithAddresses(makeAccount('a1'), [
          makeAddress('ad1', 'a1'),
          makeAddress('ad2', 'a1', address: '0xdef'),
        ]),
        throwsA(anything),
      );

      expect(await repos.accounts.byId('a1'), isNull);
      expect(await repos.addresses.find(ChainFamily.evm, '0xabc'), isNull);
      expect(await repos.addresses.byAccount('a0'), hasLength(1));
    });

    test('watchAll 随写入发出新列表', () async {
      final stream = repos.accounts.watchAll();
      final expectation = expectLater(
        stream,
        emitsInOrder([isEmpty, hasLength(1), hasLength(2)]),
      );
      await Future<void>.delayed(Duration.zero);
      await repos.accounts.upsert(makeAccount('a1'));
      await repos.accounts.upsert(makeAccount('a2'));
      await expectation;
    });

    test('未知的枚举名：列表读取跳过该行，byId 返回 null', () async {
      await repos.accounts.upsert(makeAccount('a1'));
      await repos.accounts.upsert(makeAccount('a2'));
      await db.customStatement(
        "UPDATE accounts SET type = 'from_the_future' WHERE id = 'a2'",
      );
      final all = await repos.accounts.watchAll().first;
      expect(all.map((a) => a.id), ['a1']);
      expect(await repos.accounts.byId('a2'), isNull);
    });

    test('删除账户级联删除地址、持仓、同步记录（R6）', () async {
      await repos.accounts.upsert(makeAccount('a1'));
      await repos.accounts.upsert(makeAccount('a2'));
      await repos.addresses.upsert(makeAddress('ad1', 'a1'));
      await repos.addresses.upsert(makeAddress('ad2', 'a2', address: '0xdef'));
      await repos.holdings.replaceForAccount('a1', [makeHolding('a1')]);
      await repos.holdings.replaceForAccount('a2', [
        makeHolding('a2', addressId: 'ad2'),
      ]);
      await repos.syncRecords.add(
        SyncRecord(accountId: 'a1', startedAt: t0, status: SyncStatus.success),
      );
      await repos.syncRecords.add(
        SyncRecord(accountId: 'a2', startedAt: t0, status: SyncStatus.success),
      );

      await repos.accounts.delete('a1');

      expect(await repos.accounts.byId('a1'), isNull);
      expect(await repos.addresses.byAccount('a1'), isEmpty);
      expect((await repos.holdings.watchAll().first).map((h) => h.accountId), [
        'a2',
      ]);
      expect(
        (await repos.syncRecords.watchLatestPerAccount().first).map(
          (r) => r.accountId,
        ),
        ['a2'],
      );
      expect(await repos.addresses.byAccount('a2'), hasLength(1));
    });

    test('删除账户同时删除快照明细中该账户的行，其余保留', () async {
      await repos.accounts.upsert(makeAccount('a1'));
      final day = DateTime.utc(2026, 11, 9);
      await repos.snapshots.upsert(makeSnapshot(day));

      await repos.accounts.delete('a1');

      final back = (await repos.snapshots.range(day, day)).single;
      expect(back.byAccountUsd.keys, ['a2']);
      expect(back.byAssetUsd.keys, ['ETH']);
    });
  });

  group('AddressRepository', () {
    setUp(() => repos.accounts.upsert(makeAccount('a1')));

    test('(family, address) 唯一：重复插入失败，find 能找到（R2）', () async {
      await repos.addresses.upsert(makeAddress('ad1', 'a1'));
      await expectLater(
        repos.addresses.upsert(makeAddress('ad2', 'a1')),
        throwsA(
          predicate<Object>(
            (e) => e.toString().toUpperCase().contains('UNIQUE'),
          ),
        ),
      );
      final found = await repos.addresses.find(ChainFamily.evm, '0xabc');
      expect(found?.id, 'ad1');
      expect(await repos.addresses.find(ChainFamily.evm, '0xzzz'), isNull);
      // 同一字符串在不同家族下不冲突。
      await repos.addresses.upsert(
        makeAddress(
          'ad3',
          'a1',
          address: '0xabc',
          family: ChainFamily.tron,
        ).copyWith(enabledChainIds: {'tron'}),
      );
      expect(await repos.addresses.byAccount('a1'), hasLength(2));
    });

    test('字段往返：方案、序号、启用的链', () async {
      final a = WatchAddress(
        id: 'ad9',
        accountId: 'a1',
        family: ChainFamily.bitcoin,
        address: 'bc1qxyz',
        enabledChainIds: {'bitcoin'},
        scheme: DerivationScheme.btcNativeSegwit,
        derivationIndex: 3,
        note: '收款',
      );
      await repos.addresses.upsert(a);
      expect(await repos.addresses.find(ChainFamily.bitcoin, 'bc1qxyz'), a);
      expect(await repos.addresses.watchAll().first, [a]);
    });

    test('upsert 同 id 更新启用的链', () async {
      final a = makeAddress('ad1', 'a1');
      await repos.addresses.upsert(a);
      await repos.addresses.upsert(a.copyWith(enabledChainIds: {'base'}));
      expect((await repos.addresses.byAccount('a1')).single.enabledChainIds, {
        'base',
      });
    });

    test('未知链 id：列表读取跳过该行，find 返回 null', () async {
      await repos.addresses.upsert(makeAddress('ad1', 'a1'));
      await repos.addresses.upsert(makeAddress('ad2', 'a1', address: '0xdef'));
      await db.customStatement(
        '''UPDATE addresses SET enabled_chain_ids = '["ethereum","mars"]' '''
        "WHERE id = 'ad2'",
      );
      expect((await repos.addresses.byAccount('a1')).map((a) => a.id), ['ad1']);
      expect(await repos.addresses.find(ChainFamily.evm, '0xdef'), isNull);
    });

    test('删除地址同时删除指向它的持仓', () async {
      await repos.addresses.upsert(makeAddress('ad1', 'a1'));
      await repos.addresses.upsert(makeAddress('ad2', 'a1', address: '0xdef'));
      await repos.holdings.replaceForAccount('a1', [
        makeHolding('a1'),
        makeHolding('a1', addressId: 'ad2', symbol: 'DAI'),
      ]);
      await repos.addresses.delete('ad1');
      expect(await repos.addresses.byAccount('a1'), hasLength(1));
      expect(
        (await repos.holdings.watchAll().first).single.displaySymbol,
        'DAI',
      );
    });
  });
}
