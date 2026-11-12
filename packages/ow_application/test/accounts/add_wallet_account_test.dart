import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

import '../fakes/fake_repositories.dart';
import '../fakes/fake_services.dart';

/// 只接受 [accepted] 中地址的校验和实现，用于模拟"格式对但校验和错"。
final class _RejectingChecksum implements AddressChecksum {
  _RejectingChecksum(this.rejected);

  final Set<String> rejected;

  @override
  bool verify(String address, ChainFamily family) =>
      !rejected.contains(address);

  @override
  String toEip55(String normalizedEvmAddress) => normalizedEvmAddress;
}

/// 查重永远查不到已有地址：模拟"校验通过之后、写入之前另一处写入了同一地址"。
final class _StaleAddressRepository implements AddressRepository {
  _StaleAddressRepository(this._inner);

  final InMemoryAddressRepository _inner;

  @override
  Future<WatchAddress?> find(
    ChainFamily family,
    String normalizedAddress,
  ) async => null;

  @override
  Stream<List<WatchAddress>> watchAll() => _inner.watchAll();

  @override
  Future<List<WatchAddress>> byAccount(String accountId) =>
      _inner.byAccount(accountId);

  @override
  Future<void> upsert(WatchAddress address) => _inner.upsert(address);

  @override
  Future<void> delete(String id) => _inner.delete(id);
}

void main() {
  late InMemoryAccountRepository accounts;
  late InMemoryAddressRepository addresses;
  late FakeClock clock;
  late AddWalletAccount add;

  AddWalletAccount build({AddressCodec codec = const AddressCodec()}) =>
      AddWalletAccount(
        accounts: accounts,
        addresses: addresses,
        codec: codec,
        ids: SequentialIds(),
        clock: clock,
      );

  setUp(() {
    addresses = InMemoryAddressRepository();
    accounts = InMemoryAccountRepository(addresses: addresses);
    clock = FakeClock();
    add = build();
  });

  Failure? failureOf(Result<Object?> r) =>
      r.when(ok: (_) => null, err: (f) => f);

  test('AddWalletAccount_成功_写入账户与地址并返回账户', () async {
    final r = await add(
      name: '  主钱包 ',
      walletSource: WalletSource.metamask,
      backup: const BackupStatus(offlineBackedUp: true),
      addresses: [AddressInput(raw: ' ${TestAddresses.evmC} ')],
    );

    final account = r.valueOrNull;
    expect(account, isNotNull);
    expect(account?.name, '主钱包');
    expect(account?.type, AccountType.wallet);
    expect(account?.walletSource, WalletSource.metamask);
    expect(account?.backup.offlineBackedUp, isTrue);
    expect(account?.createdAt, clock.nowUtc());
    expect(accounts.store.value, [account]);
    final saved = addresses.store.value.single;
    expect(saved.accountId, account?.id);
    expect(saved.address, TestAddresses.evmC.toLowerCase());
    expect(saved.family, ChainFamily.evm);
  });

  test('AddWalletAccount_EVM地址未指定链_默认启用全部6条EVM链', () async {
    await add(
      name: 'a',
      addresses: [AddressInput(raw: TestAddresses.evmA)],
    );
    expect(addresses.store.value.single.enabledChainIds, {
      'ethereum',
      'bsc',
      'arbitrum',
      'optimism',
      'base',
      'polygon',
    });
  });

  test('AddWalletAccount_非EVM地址_固定启用该家族唯一的链', () async {
    await add(
      name: 'a',
      addresses: [
        AddressInput(raw: TestAddresses.tron),
        AddressInput(raw: TestAddresses.btc),
      ],
    );
    expect(addresses.store.value.map((a) => a.enabledChainIds), [
      {'tron'},
      {'bitcoin'},
    ]);
  });

  test('AddWalletAccount_指定部分EVM链_只启用所选', () async {
    await add(
      name: 'a',
      addresses: [
        AddressInput(raw: TestAddresses.evmA, chainIds: {'base', 'arbitrum'}),
      ],
    );
    expect(addresses.store.value.single.enabledChainIds, {'base', 'arbitrum'});
  });

  test('AddWalletAccount_链选择为空或不属于该家族_返回校验失败', () async {
    for (final chains in [
      <String>{},
      {'tron'},
      {'nope'},
    ]) {
      final r = await add(
        name: 'a',
        addresses: [AddressInput(raw: TestAddresses.evmA, chainIds: chains)],
      );
      expect(failureOf(r), isA<ValidationFailure>());
    }
    expect(accounts.store.value, isEmpty);
  });

  test('AddWalletAccount_名称为空或超过30字_返回校验失败', () async {
    for (final name in ['', '   ', '字' * 31]) {
      final r = await add(
        name: name,
        addresses: [AddressInput(raw: TestAddresses.evmA)],
      );
      expect(failureOf(r), isA<ValidationFailure>(), reason: name);
    }
    final ok = await add(
      name: '字' * 30,
      addresses: [AddressInput(raw: TestAddresses.evmA)],
    );
    expect(ok.isOk, isTrue);
  });

  test('AddWalletAccount_地址列表为空_返回校验失败', () async {
    final r = await add(name: 'a', addresses: const []);
    expect(failureOf(r), isA<ValidationFailure>());
    expect(accounts.store.value, isEmpty);
  });

  test('AddWalletAccount_无法识别或格式非法的地址_返回校验失败且不写入', () async {
    for (final raw in ['hello', '0x123']) {
      final r = await add(
        name: 'a',
        addresses: [AddressInput(raw: raw)],
      );
      expect(failureOf(r), isA<ValidationFailure>(), reason: raw);
    }
    final wrongFamily = await add(
      name: 'a',
      addresses: [
        AddressInput(raw: TestAddresses.evmA, family: ChainFamily.tron),
      ],
    );
    expect(failureOf(wrongFamily), isA<ValidationFailure>());
    expect(accounts.store.value, isEmpty);
    expect(addresses.store.value, isEmpty);
  });

  test('AddWalletAccount_校验和错误_返回校验失败', () async {
    add = build(
      codec: AddressCodec(checksum: _RejectingChecksum({TestAddresses.evmC})),
    );
    final r = await add(
      name: 'a',
      addresses: [AddressInput(raw: TestAddresses.evmC)],
    );
    expect(failureOf(r), isA<ValidationFailure>());
  });

  test('AddWalletAccount_与已有地址重复_返回所属账户名且不写入', () async {
    await add(
      name: '老钱包',
      addresses: [AddressInput(raw: TestAddresses.evmC)],
    );

    final r = await add(
      name: '新钱包',
      addresses: [
        AddressInput(raw: TestAddresses.evmB),
        // 大小写不同，规范化后相同。
        AddressInput(raw: TestAddresses.evmC.toLowerCase()),
      ],
    );

    final f = failureOf(r);
    expect(f, isA<DuplicateAddressFailure>());
    if (f is DuplicateAddressFailure) {
      expect(f.existingAccountName, '老钱包');
      expect(f.isWithinInput, isFalse);
      expect(f.shortAddress, '0xaaaa…aaaa');
    }
    expect(accounts.store.value, hasLength(1));
    expect(addresses.store.value, hasLength(1));
  });

  test('AddWalletAccount_本次输入内重复_返回无账户名的重复失败', () async {
    final r = await add(
      name: 'a',
      addresses: [
        AddressInput(raw: TestAddresses.evmC),
        AddressInput(
          raw: ' ${TestAddresses.evmC.toUpperCase().replaceFirst('0X', '0x')}',
        ),
      ],
    );
    final f = failureOf(r);
    expect(f, isA<DuplicateAddressFailure>());
    if (f is DuplicateAddressFailure) expect(f.isWithinInput, isTrue);
    expect(accounts.store.value, isEmpty);
  });

  test('AddWalletAccount_颜色未指定_按已有账户数轮换；越界返回校验失败', () async {
    final first = await add(
      name: 'a',
      addresses: [AddressInput(raw: TestAddresses.evmA)],
    );
    final second = await add(
      name: 'b',
      addresses: [AddressInput(raw: TestAddresses.evmB)],
    );
    expect(first.valueOrNull?.colorIndex, 0);
    expect(second.valueOrNull?.colorIndex, 1);

    final bad = await add(
      name: 'c',
      colorIndex: 8,
      addresses: [AddressInput(raw: TestAddresses.evmC)],
    );
    expect(failureOf(bad), isA<ValidationFailure>());
  });

  test('AddWalletAccount_第二个地址写入时冲突_整体回滚不留下账户和任何地址', () async {
    // 已有地址 B 属于另一个账户；查重被绕过（模拟并发写入），写入时第二个地址冲突。
    await accounts.insertWithAddresses(
      Account(
        id: 'other',
        type: AccountType.wallet,
        name: '别的钱包',
        colorIndex: 0,
        createdAt: clock.nowUtc(),
      ),
      [
        WatchAddress(
          id: 'other-addr',
          accountId: 'other',
          family: ChainFamily.evm,
          address: TestAddresses.evmB.toLowerCase(),
          enabledChainIds: {'ethereum'},
        ),
      ],
    );
    final racing = AddWalletAccount(
      accounts: accounts,
      addresses: _StaleAddressRepository(addresses),
      codec: const AddressCodec(),
      ids: SequentialIds(),
      clock: clock,
    );

    await expectLater(
      racing(
        name: '新钱包',
        addresses: [
          AddressInput(raw: TestAddresses.evmA),
          AddressInput(raw: TestAddresses.evmB),
        ],
      ),
      throwsStateError,
    );

    expect(accounts.store.value.map((a) => a.id), ['other']);
    expect(addresses.store.value.map((a) => a.id), ['other-addr']);
  });

  test('AddWalletAccount_地址存在而所属账户不存在_返回所属账户缺失的重复失败', () async {
    await addresses.upsert(
      WatchAddress(
        id: 'orphan',
        accountId: 'ghost',
        family: ChainFamily.evm,
        address: TestAddresses.evmC.toLowerCase(),
        enabledChainIds: {'ethereum'},
      ),
    );

    final r = await add(
      name: 'a',
      addresses: [AddressInput(raw: TestAddresses.evmC)],
    );

    final f = failureOf(r);
    expect(f, isA<DuplicateAddressFailure>());
    if (f is DuplicateAddressFailure) {
      expect(f.kind, DuplicateAddressKind.ownerMissing);
      expect(f.existingAccountName, isNull);
      expect(f.isWithinInput, isFalse);
    }
    expect(accounts.store.value, isEmpty);
  });
}
