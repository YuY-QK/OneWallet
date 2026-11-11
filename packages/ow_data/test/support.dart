import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:ow_data/ow_data.dart';
import 'package:ow_domain/ow_domain.dart';

/// 内存数据库；每个测试自己建、自己关。
OwDatabase newDb() => OwDatabase(NativeDatabase.memory());

Decimal d(String s) => Decimal.parse(s);

final t0 = DateTime.utc(2026, 11, 10, 8, 30, 15, 123);

Account makeAccount(String id, {AccountType type = AccountType.wallet}) =>
    Account(
      id: id,
      type: type,
      name: '账户$id',
      colorIndex: 2,
      createdAt: t0,
      walletSource: type == AccountType.wallet ? WalletSource.metamask : null,
      exchange: type == AccountType.exchange ? ExchangeId.okx : null,
    );

WatchAddress makeAddress(
  String id,
  String accountId, {
  String address = '0xabc',
  ChainFamily family = ChainFamily.evm,
}) => WatchAddress(
  id: id,
  accountId: accountId,
  family: family,
  address: address,
  enabledChainIds: {'ethereum', 'base'},
);

Holding makeHolding(
  String accountId, {
  String addressId = 'ad1',
  String symbol = 'ETH',
  String amount = '1.5',
  TokenRef token = const NativeToken('ethereum'),
}) => Holding(
  accountId: accountId,
  location: OnChainLocation(chainId: 'ethereum', addressId: addressId),
  token: token,
  displaySymbol: symbol,
  amount: d(amount),
  updatedAt: t0,
);

Snapshot makeSnapshot(DateTime date, {Map<String, Decimal>? byAccount}) =>
    Snapshot(
      date: date,
      totalUsd: d('300.5'),
      complete: true,
      byAccountUsd: byAccount ?? {'a1': d('100.5'), 'a2': d('200')},
      byAssetUsd: {'ETH': d('300.5')},
    );
