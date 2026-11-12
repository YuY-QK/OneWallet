import 'package:drift/drift.dart';
import 'package:ow_domain/ow_domain.dart';

import '../database/ow_database.dart';
import '../mapping/account_mapping.dart';
import '../mapping/codec.dart';
import '../mapping/misc_mapping.dart';

/// [AccountRepository] 的 Drift 实现。读取时跳过无法解码的行（见 [RowDecodeException]）。
final class DriftAccountRepository implements AccountRepository {
  DriftAccountRepository(this._db);

  final OwDatabase _db;

  @override
  Stream<List<Account>> watchAll() {
    final query = _db.select(_db.accounts)
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return query.watch().map((rows) => decodeRows(rows, accountFromRow));
  }

  @override
  Future<Account?> byId(String id) async {
    final row = await (_db.select(
      _db.accounts,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : tryDecode(row, accountFromRow);
  }

  @override
  Future<void> upsert(Account account) async {
    final companion = accountToCompanion(account);
    // 不能用 INSERT OR REPLACE：REPLACE 会先删旧行，触发级联删除子表数据。
    await _db
        .into(_db.accounts)
        .insert(
          companion,
          onConflict: DoUpdate((_) => companion, target: [_db.accounts.id]),
        );
  }

  /// 单事务写入账户及其全部地址；任一地址违反唯一约束时整体回滚，
  /// 账户与已写入的地址都不会留下（异常继续抛出）。
  @override
  Future<void> insertWithAddresses(
    Account account,
    List<WatchAddress> addresses,
  ) => _db.transaction(() async {
    await upsert(account);
    for (final address in addresses) {
      final companion = addressToCompanion(address);
      await _db
          .into(_db.addresses)
          .insert(
            companion,
            onConflict: DoUpdate((_) => companion, target: [_db.addresses.id]),
          );
    }
  });

  /// 删除账户，级联删除其地址、持仓、同步记录（R6），
  /// 并删除快照明细中该账户的那一行（`kind=account` 且 `key=id`）。
  @override
  Future<void> delete(String id) => _db.transaction(() async {
    await (_db.delete(_db.snapshotItems)
          ..where((t) => t.kind.equals(snapshotKindAccount) & t.key.equals(id)))
        .go();
    await (_db.delete(_db.accounts)..where((t) => t.id.equals(id))).go();
  });
}

/// [AddressRepository] 的 Drift 实现。
///
/// (family, address) 重复时 [upsert] 抛出 Drift 的唯一约束异常（R2），
/// 调用方应先用 [find] 判断。
final class DriftAddressRepository implements AddressRepository {
  DriftAddressRepository(this._db);

  final OwDatabase _db;

  @override
  Stream<List<WatchAddress>> watchAll() {
    final query = _db.select(_db.addresses)
      ..orderBy([(t) => OrderingTerm.asc(t.rowId)]);
    return query.watch().map((rows) => decodeRows(rows, addressFromRow));
  }

  @override
  Future<List<WatchAddress>> byAccount(String accountId) async {
    final rows =
        await (_db.select(_db.addresses)
              ..where((t) => t.accountId.equals(accountId))
              ..orderBy([(t) => OrderingTerm.asc(t.rowId)]))
            .get();
    return decodeRows(rows, addressFromRow);
  }

  @override
  Future<WatchAddress?> find(
    ChainFamily family,
    String normalizedAddress,
  ) async {
    final row =
        await (_db.select(_db.addresses)..where(
              (t) =>
                  t.family.equals(family.name) &
                  t.address.equals(normalizedAddress),
            ))
            .getSingleOrNull();
    return row == null ? null : tryDecode(row, addressFromRow);
  }

  @override
  Future<void> upsert(WatchAddress address) async {
    final companion = addressToCompanion(address);
    await _db
        .into(_db.addresses)
        .insert(
          companion,
          onConflict: DoUpdate((_) => companion, target: [_db.addresses.id]),
        );
  }

  /// 删除地址，并同步删除指向该地址的持仓（持仓表对地址没有外键，由这里保证不留孤儿）。
  @override
  Future<void> delete(String id) => _db.transaction(() async {
    await (_db.delete(_db.holdings)..where((t) => t.addressId.equals(id))).go();
    await (_db.delete(_db.addresses)..where((t) => t.id.equals(id))).go();
  });
}
