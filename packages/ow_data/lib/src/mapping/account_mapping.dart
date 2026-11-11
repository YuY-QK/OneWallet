import 'package:drift/drift.dart';
import 'package:ow_domain/ow_domain.dart';

import '../database/ow_database.dart';
import 'codec.dart';

/// 账户行 → 领域对象。枚举名未知时抛出 [RowDecodeException]。
Account accountFromRow(AccountRow row) => Account(
  id: row.id,
  type: decodeEnum(AccountType.values, row.type, '账户类型'),
  name: row.name,
  colorIndex: row.colorIndex,
  note: row.note,
  walletSource: decodeEnumOrNull(WalletSource.values, row.walletSource, '钱包来源'),
  exchange: decodeEnumOrNull(ExchangeId.values, row.exchange, '交易所'),
  vaultItemId: row.vaultItemId,
  backup: BackupStatus(
    offlineBackedUp: row.offlineBackedUp,
    offlineVerifiedAt: row.offlineVerifiedAt?.toUtc(),
    keyless: row.keyless,
  ),
  createdAt: row.createdAt.toUtc(),
);

/// 领域对象 → 账户行。
AccountsCompanion accountToCompanion(Account a) => AccountsCompanion(
  id: Value(a.id),
  type: Value(a.type.name),
  name: Value(a.name),
  colorIndex: Value(a.colorIndex),
  note: Value(a.note),
  walletSource: Value(a.walletSource?.name),
  exchange: Value(a.exchange?.name),
  vaultItemId: Value(a.vaultItemId),
  offlineBackedUp: Value(a.backup.offlineBackedUp),
  offlineVerifiedAt: Value(a.backup.offlineVerifiedAt?.toUtc()),
  keyless: Value(a.backup.keyless),
  createdAt: Value(a.createdAt.toUtc()),
);

/// 地址行 → 领域对象。家族、方案或链 id 未知时抛出 [RowDecodeException]。
WatchAddress addressFromRow(AddressRow row) {
  final chainIds = decodeStringSet(row.enabledChainIds)..forEach(checkChainId);
  return WatchAddress(
    id: row.id,
    accountId: row.accountId,
    family: decodeEnum(ChainFamily.values, row.family, '链家族'),
    address: row.address,
    enabledChainIds: chainIds,
    scheme: decodeEnumOrNull(DerivationScheme.values, row.scheme, '派生方案'),
    derivationIndex: row.derivationIndex,
    note: row.note,
  );
}

/// 领域对象 → 地址行。
AddressesCompanion addressToCompanion(WatchAddress a) => AddressesCompanion(
  id: Value(a.id),
  accountId: Value(a.accountId),
  family: Value(a.family.name),
  address: Value(a.address),
  enabledChainIds: Value(encodeStringSet(a.enabledChainIds)),
  scheme: Value(a.scheme?.name),
  derivationIndex: Value(a.derivationIndex),
  note: Value(a.note),
);
