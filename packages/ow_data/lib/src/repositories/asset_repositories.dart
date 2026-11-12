import 'package:drift/drift.dart';
import 'package:ow_domain/ow_domain.dart';

import '../database/ow_database.dart';

/// [AssetRepository] 的 Drift 实现。
final class DriftAssetRepository implements AssetRepository {
  DriftAssetRepository(this._db);

  final OwDatabase _db;

  static Asset _asset(AssetRow r) =>
      Asset(id: r.id, symbol: r.symbol, name: r.name, priceId: r.priceId);

  /// 单事务；已存在的币种只更新符号、名称、价格源标识，创建时间保持不变。
  @override
  Future<void> upsertAll(List<Asset> assets, {required DateTime now}) =>
      _db.transaction(() async {
        for (final a in assets) {
          await _db
              .into(_db.assets)
              .insert(
                AssetsCompanion.insert(
                  id: a.id,
                  symbol: a.symbol,
                  name: a.name,
                  priceId: Value(a.priceId),
                  createdAt: now.toUtc(),
                ),
                onConflict: DoUpdate(
                  (_) => AssetsCompanion(
                    symbol: Value(a.symbol),
                    name: Value(a.name),
                    priceId: Value(a.priceId),
                  ),
                  target: [_db.assets.id],
                ),
              );
        }
      });

  @override
  Future<List<Asset>> all() async {
    final rows = await (_db.select(
      _db.assets,
    )..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get();
    return [for (final r in rows) _asset(r)];
  }

  @override
  Future<Asset?> byId(String id) async {
    final row = await (_db.select(
      _db.assets,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _asset(row);
  }

  /// 单事务；币种 id 不存在时外键约束失败，整体回滚。
  @override
  Future<void> upsertContracts(Map<ContractToken, String> assetIdByContract) =>
      _db.transaction(() async {
        for (final e in assetIdByContract.entries) {
          final companion = AssetContractsCompanion.insert(
            chainId: e.key.chainId,
            contract: e.key.contract,
            assetId: e.value,
          );
          await _db
              .into(_db.assetContracts)
              .insert(
                companion,
                onConflict: DoUpdate(
                  (_) => AssetContractsCompanion(assetId: Value(e.value)),
                  target: [
                    _db.assetContracts.chainId,
                    _db.assetContracts.contract,
                  ],
                ),
              );
        }
      });

  @override
  Future<Map<ContractToken, String>> contracts() async {
    final rows = await _db.select(_db.assetContracts).get();
    return {
      for (final r in rows) ContractToken(r.chainId, r.contract): r.assetId,
    };
  }
}
