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
    accounts = InMemoryAccountRepository();
    addresses = InMemoryAddressRepository();
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
}
