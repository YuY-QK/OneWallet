import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

import '../fakes/fake_repositories.dart';
import '../fakes/fake_services.dart';

void main() {
  late InMemoryAccountRepository accounts;
  late InMemoryAddressRepository addresses;
  late AddAddressesToAccount addTo;
  late String walletId;

  setUp(() async {
    accounts = InMemoryAccountRepository();
    addresses = InMemoryAddressRepository();
    final ids = SequentialIds();
    final created =
        await AddWalletAccount(
          accounts: accounts,
          addresses: addresses,
          codec: const AddressCodec(),
          ids: ids,
          clock: FakeClock(),
        )(
          name: '主钱包',
          addresses: [AddressInput(raw: TestAddresses.evmA)],
        );
    walletId = created.valueOrNull?.id ?? '';
    addTo = AddAddressesToAccount(
      accounts: accounts,
      addresses: addresses,
      codec: const AddressCodec(),
      ids: ids,
    );
  });

  Failure? failureOf(Result<Object?> r) =>
      r.when(ok: (_) => null, err: (f) => f);

  test('AddAddressesToAccount_成功_写入新地址并返回', () async {
    final r = await addTo(
      accountId: walletId,
      addresses: [
        AddressInput(raw: TestAddresses.evmB, chainIds: {'base'}),
        AddressInput(raw: TestAddresses.tron),
      ],
    );
    final written = r.valueOrNull ?? const [];
    expect(written, hasLength(2));
    expect(written.every((a) => a.accountId == walletId), isTrue);
    expect(written.first.enabledChainIds, {'base'});
    expect(await addresses.byAccount(walletId), hasLength(3));
  });

  test('AddAddressesToAccount_账户不存在_返回校验失败', () async {
    final r = await addTo(
      accountId: 'missing',
      addresses: [AddressInput(raw: TestAddresses.evmB)],
    );
    expect(failureOf(r), isA<ValidationFailure>());
  });

  test('AddAddressesToAccount_交易所账户_返回校验失败', () async {
    await accounts.upsert(
      Account(
        id: 'x1',
        type: AccountType.exchange,
        name: '交易所',
        colorIndex: 0,
        exchange: ExchangeId.binance,
        createdAt: DateTime.utc(2026),
      ),
    );
    final r = await addTo(
      accountId: 'x1',
      addresses: [AddressInput(raw: TestAddresses.evmB)],
    );
    expect(failureOf(r), isA<ValidationFailure>());
    expect(addresses.store.value, hasLength(1));
  });

  test('AddAddressesToAccount_已在本账户中_返回重复失败并带账户名', () async {
    final r = await addTo(
      accountId: walletId,
      addresses: [AddressInput(raw: TestAddresses.evmA)],
    );
    final f = failureOf(r);
    expect(f, isA<DuplicateAddressFailure>());
    if (f is DuplicateAddressFailure) expect(f.existingAccountName, '主钱包');
  });

  test('AddAddressesToAccount_空列表或非法地址_返回校验失败', () async {
    expect(
      failureOf(await addTo(accountId: walletId, addresses: const [])),
      isA<ValidationFailure>(),
    );
    expect(
      failureOf(
        await addTo(
          accountId: walletId,
          addresses: [AddressInput(raw: 'x')],
        ),
      ),
      isA<ValidationFailure>(),
    );
  });
}
