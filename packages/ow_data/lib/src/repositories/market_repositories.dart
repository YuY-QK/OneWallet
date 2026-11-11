import 'package:drift/drift.dart';
import 'package:ow_domain/ow_domain.dart';

import '../database/ow_database.dart';
import '../mapping/codec.dart';
import '../mapping/holding_mapping.dart';
import '../mapping/misc_mapping.dart';

/// [HoldingRepository] 的 Drift 实现。读取时跳过无法解码的行（见 [RowDecodeException]）。
final class DriftHoldingRepository implements HoldingRepository {
  DriftHoldingRepository(this._db);

  final OwDatabase _db;

  @override
  Stream<List<Holding>> watchAll() {
    final query = _db.select(_db.holdings)
      ..orderBy([(t) => OrderingTerm.asc(t.id)]);
    return query.watch().map((rows) => decodeRows(rows, holdingFromRow));
  }

  /// 单事务：先删该账户的全部旧持仓，再写入新持仓；任何一步失败都整体回滚，旧数据保留。
  ///
  /// [holdings] 中每一项的 `accountId` 必须等于 [accountId]，否则在动数据库之前抛出
  /// [ArgumentError]。
  @override
  Future<void> replaceForAccount(
    String accountId,
    List<Holding> holdings,
  ) async {
    for (final h in holdings) {
      if (h.accountId != accountId) {
        throw ArgumentError.value(
          h.accountId,
          'holdings',
          '持仓不属于账户 $accountId',
        );
      }
    }
    await _db.transaction(() async {
      await (_db.delete(
        _db.holdings,
      )..where((t) => t.accountId.equals(accountId))).go();
      await _db.batch(
        (b) => b.insertAll(_db.holdings, holdings.map(holdingToCompanion)),
      );
    });
  }
}

/// [PriceRepository] 的 Drift 实现。
final class DriftPriceRepository implements PriceRepository {
  DriftPriceRepository(this._db);

  final OwDatabase _db;

  @override
  Stream<Map<String, Price>> watch(Quote quote) {
    final query = _db.select(_db.prices)
      ..where((t) => t.quote.equals(quote.name));
    return query.watch().map(
      (rows) => {for (final p in decodeRows(rows, priceFromRow)) p.assetId: p},
    );
  }

  @override
  Future<void> upsertAll(List<Price> prices) => _db.transaction(() async {
    for (final p in prices) {
      final companion = priceToCompanion(p);
      await _db
          .into(_db.prices)
          .insert(
            companion,
            onConflict: DoUpdate(
              (_) => companion,
              target: [_db.prices.assetId, _db.prices.quote],
            ),
          );
    }
  });
}

/// [SnapshotRepository] 的 Drift 实现。
final class DriftSnapshotRepository implements SnapshotRepository {
  DriftSnapshotRepository(this._db);

  final OwDatabase _db;

  /// 返回 [from, to]（含两端）内的快照，按日期升序。无法解码的快照被跳过。
  @override
  Future<List<Snapshot>> range(DateTime from, DateTime to) async {
    final rows =
        await (_db.select(_db.snapshots)
              ..where(
                (t) =>
                    t.date.isBiggerOrEqualValue(from.toUtc()) &
                    t.date.isSmallerOrEqualValue(to.toUtc()),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.date)]))
            .get();
    if (rows.isEmpty) return const [];
    final items = await (_db.select(
      _db.snapshotItems,
    )..where((t) => t.date.isIn(rows.map((r) => r.date)))).get();
    final byDate = <DateTime, List<SnapshotItemRow>>{};
    for (final item in items) {
      byDate.putIfAbsent(item.date.toUtc(), () => []).add(item);
    }
    return decodeRows(
      rows,
      (r) => snapshotFromRows(r, byDate[r.date.toUtc()] ?? const []),
    );
  }

  /// 以 `date` 为键整体替换：主行与明细在同一事务里重写。
  @override
  Future<void> upsert(Snapshot snapshot) => _db.transaction(() async {
    final date = snapshot.date.toUtc();
    final main = SnapshotsCompanion(
      date: Value(date),
      totalUsd: Value(encodeDecimal(snapshot.totalUsd)),
      complete: Value(snapshot.complete),
    );
    await _db
        .into(_db.snapshots)
        .insert(
          main,
          onConflict: DoUpdate((_) => main, target: [_db.snapshots.date]),
        );
    await (_db.delete(
      _db.snapshotItems,
    )..where((t) => t.date.equals(date))).go();
    await _db.batch(
      (b) => b.insertAll(_db.snapshotItems, snapshotItemCompanions(snapshot)),
    );
  });
}
