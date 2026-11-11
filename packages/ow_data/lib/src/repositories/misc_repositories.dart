import 'package:drift/drift.dart';
import 'package:ow_domain/ow_domain.dart';

import '../database/ow_database.dart';
import '../mapping/codec.dart';
import '../mapping/misc_mapping.dart';
import '../mapping/settings_mapping.dart';

/// 同步记录全表保留的最大条数。
const int maxSyncRecords = 50;

/// [SyncRecordRepository] 的 Drift 实现。
final class DriftSyncRecordRepository implements SyncRecordRepository {
  DriftSyncRecordRepository(this._db);

  final OwDatabase _db;

  /// 每个账户最近一条（按写入顺序），按写入顺序从新到旧排列。
  @override
  Stream<List<SyncRecord>> watchLatestPerAccount() {
    final query = _db.select(_db.syncRecords)
      ..where(
        (t) => t.id.isInQuery(
          _db.selectOnly(_db.syncRecords)
            ..addColumns([_db.syncRecords.id.max()])
            ..groupBy([_db.syncRecords.accountId]),
        ),
      )
      ..orderBy([(t) => OrderingTerm.desc(t.id)]);
    return query.watch().map((rows) => decodeRows(rows, syncRecordFromRow));
  }

  /// 追加一条记录，并把全表裁剪到最近 [maxSyncRecords] 条（按写入顺序），同一事务内完成。
  @override
  Future<void> add(SyncRecord record) => _db.transaction(() async {
    await _db.into(_db.syncRecords).insert(syncRecordToCompanion(record));
    await _db.customStatement(
      'DELETE FROM sync_records WHERE id NOT IN '
      '(SELECT id FROM sync_records ORDER BY id DESC LIMIT $maxSyncRecords)',
    );
  });
}

/// [VaultMetaRepository] 的 Drift 实现。只存元数据，不含任何密钥材料。
final class DriftVaultMetaRepository implements VaultMetaRepository {
  DriftVaultMetaRepository(this._db);

  final OwDatabase _db;

  @override
  Stream<List<VaultItemMeta>> watchAll() {
    final query = _db.select(_db.vaultItemsMeta)
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return query.watch().map((rows) => decodeRows(rows, vaultMetaFromRow));
  }

  @override
  Future<VaultItemMeta?> byFingerprint(String fingerprint) async {
    final row = await (_db.select(
      _db.vaultItemsMeta,
    )..where((t) => t.fingerprint.equals(fingerprint))).getSingleOrNull();
    return row == null ? null : tryDecode(row, vaultMetaFromRow);
  }

  /// 以 id 为键写入。指纹与另一条目重复时抛出唯一约束异常。
  @override
  Future<void> upsert(VaultItemMeta meta) async {
    final companion = vaultMetaToCompanion(meta);
    await _db
        .into(_db.vaultItemsMeta)
        .insert(
          companion,
          onConflict: DoUpdate(
            (_) => companion,
            target: [_db.vaultItemsMeta.id],
          ),
        );
  }

  @override
  Future<void> delete(String id) =>
      (_db.delete(_db.vaultItemsMeta)..where((t) => t.id.equals(id))).go();
}

/// [SettingsRepository] 的 Drift 实现。键缺失或值无法识别的项回落到默认值。
final class DriftSettingsRepository implements SettingsRepository {
  DriftSettingsRepository(this._db);

  final OwDatabase _db;

  @override
  Stream<AppSettings> watch() => _db
      .select(_db.settings)
      .watch()
      .map((rows) => settingsFromMap({for (final r in rows) r.key: r.value}));

  /// 读取当前设置，应用 [change]，在同一事务里写回。值为 null 的项删除对应行。
  @override
  Future<void> update(AppSettings Function(AppSettings) change) =>
      _db.transaction(() async {
        final rows = await _db.select(_db.settings).get();
        final current = settingsFromMap({for (final r in rows) r.key: r.value});
        final next = settingsToMap(change(current));
        for (final key in settingKeys) {
          final value = next[key];
          if (value == null) {
            await (_db.delete(
              _db.settings,
            )..where((t) => t.key.equals(key))).go();
          } else {
            await _db
                .into(_db.settings)
                .insert(
                  SettingsCompanion.insert(key: key, value: value),
                  onConflict: DoUpdate(
                    (_) => SettingsCompanion(value: Value(value)),
                    target: [_db.settings.key],
                  ),
                );
          }
        }
      });
}

/// [TokenVisibilityRepository] 的 Drift 实现。
final class DriftTokenVisibilityRepository
    implements TokenVisibilityRepository {
  DriftTokenVisibilityRepository(this._db);

  final OwDatabase _db;

  @override
  Future<Set<String>> hidden() async {
    final rows = await (_db.select(
      _db.tokenVisibility,
    )..where((t) => t.hidden.equals(true))).get();
    return {for (final r in rows) r.tokenKey};
  }

  @override
  Future<void> setHidden(String tokenKey, bool hidden) async {
    final companion = TokenVisibilityCompanion.insert(
      tokenKey: tokenKey,
      hidden: hidden,
    );
    await _db
        .into(_db.tokenVisibility)
        .insert(
          companion,
          onConflict: DoUpdate(
            (_) => TokenVisibilityCompanion(hidden: Value(hidden)),
            target: [_db.tokenVisibility.tokenKey],
          ),
        );
  }
}
