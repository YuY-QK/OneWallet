import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:ow_domain/ow_domain.dart';

import '../database/ow_database.dart';
import 'codec.dart';

/// `snapshot_items.kind` 的取值。
const snapshotKindAccount = 'account';
const snapshotKindAsset = 'asset';

/// 价格行 → 领域对象。
Price priceFromRow(PriceRow row) => Price(
  assetId: row.assetId,
  quote: decodeEnum(Quote.values, row.quote, '计价货币'),
  price: decodeDecimal(row.price),
  change24hPercent: row.change24hPercent == null
      ? null
      : decodeDecimal(row.change24hPercent!),
  updatedAt: row.updatedAt.toUtc(),
);

/// 领域对象 → 价格行。
PricesCompanion priceToCompanion(Price p) => PricesCompanion(
  assetId: Value(p.assetId),
  quote: Value(p.quote.name),
  price: Value(encodeDecimal(p.price)),
  change24hPercent: Value(
    p.change24hPercent == null ? null : encodeDecimal(p.change24hPercent!),
  ),
  updatedAt: Value(p.updatedAt.toUtc()),
);

/// 同步记录行 → 领域对象。
SyncRecord syncRecordFromRow(SyncRecordRow row) => SyncRecord(
  accountId: row.accountId,
  startedAt: row.startedAt.toUtc(),
  finishedAt: row.finishedAt?.toUtc(),
  status: decodeEnum(SyncStatus.values, row.status, '同步状态'),
  failureType: row.failureType,
);

/// 领域对象 → 同步记录行（主键自增，不写入）。
SyncRecordsCompanion syncRecordToCompanion(SyncRecord r) =>
    SyncRecordsCompanion.insert(
      accountId: r.accountId,
      startedAt: r.startedAt.toUtc(),
      finishedAt: Value(r.finishedAt?.toUtc()),
      status: r.status.name,
      failureType: Value(r.failureType),
    );

/// 保险库元数据行 → 领域对象。
VaultItemMeta vaultMetaFromRow(VaultItemMetaRow row) => VaultItemMeta(
  id: row.id,
  name: row.name,
  kind: decodeEnum(VaultItemKind.values, row.kind, '保险库条目类型'),
  wordCount: row.wordCount,
  family: decodeEnumOrNull(ChainFamily.values, row.family, '链家族'),
  hasPassphrase: row.hasPassphrase,
  fingerprint: row.fingerprint,
  createdAt: row.createdAt.toUtc(),
);

/// 领域对象 → 保险库元数据行。
VaultItemsMetaCompanion vaultMetaToCompanion(VaultItemMeta m) =>
    VaultItemsMetaCompanion(
      id: Value(m.id),
      name: Value(m.name),
      kind: Value(m.kind.name),
      wordCount: Value(m.wordCount),
      family: Value(m.family?.name),
      hasPassphrase: Value(m.hasPassphrase),
      fingerprint: Value(m.fingerprint),
      createdAt: Value(m.createdAt.toUtc()),
    );

/// 快照主行加明细行 → 领域对象。
Snapshot snapshotFromRows(SnapshotRow row, List<SnapshotItemRow> items) {
  final byAccount = <String, Decimal>{};
  final byAsset = <String, Decimal>{};
  for (final item in items) {
    final value = decodeDecimal(item.valueUsd);
    switch (item.kind) {
      case snapshotKindAccount:
        byAccount[item.key] = value;
      case snapshotKindAsset:
        byAsset[item.key] = value;
      default:
        throw RowDecodeException('未知的快照明细类型：${item.kind}');
    }
  }
  return Snapshot(
    date: row.date.toUtc(),
    totalUsd: decodeDecimal(row.totalUsd),
    complete: row.complete,
    byAccountUsd: byAccount,
    byAssetUsd: byAsset,
  );
}

/// 快照 → 明细行。
List<SnapshotItemsCompanion> snapshotItemCompanions(Snapshot s) {
  final date = s.date.toUtc();
  return [
    for (final e in s.byAccountUsd.entries)
      SnapshotItemsCompanion.insert(
        date: date,
        kind: snapshotKindAccount,
        key: e.key,
        valueUsd: encodeDecimal(e.value),
      ),
    for (final e in s.byAssetUsd.entries)
      SnapshotItemsCompanion.insert(
        date: date,
        kind: snapshotKindAsset,
        key: e.key,
        valueUsd: encodeDecimal(e.value),
      ),
  ];
}
