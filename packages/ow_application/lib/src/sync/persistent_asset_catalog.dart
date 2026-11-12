import 'package:ow_domain/ow_domain.dart';

/// 记住价格源查到的"合约 → 币种"，使下次同步不再重复查询（`HoldingNormalizer` 使用）。
abstract interface class ContractAssetRecorder {
  /// 记住 [found]，返回每个合约最终采用的币种。
  ///
  /// 返回值可能与传入的币种不同：币种 id 与已有的另一个币种（价格源标识不同）冲突时
  /// 会改名，调用方必须使用返回的币种。
  Future<Map<ContractToken, Asset>> remember(Map<ContractToken, Asset> found);
}

/// "内置映射表 + 数据库"的币种目录（M1-18）。
///
/// 放在 `ow_application`：只组合 `ow_domain` 的 [AssetCatalog] 与 [AssetRepository]，
/// 不涉及 IO 实现，也不需要 `ow_pricing`、`ow_data` 的具体类型，依赖方向合规。
///
/// `AssetCatalog` 的方法是同步的，所以启动时先 [load] 把库中的币种与合约对应读入内存；
/// [remember] 新增时先写库、成功后再更新内存，内存里的内容永远不超前于库。
/// 查找顺序：内置表优先，库中的在后；库中币种的 id 与内置币种相同时以内置的为准（忽略库中那条）。
final class PersistentAssetCatalog
    implements AssetCatalog, ContractAssetRecorder {
  PersistentAssetCatalog({
    required this._builtIn,
    required this._repository,
    required this._clock,
  });

  final AssetCatalog _builtIn;
  final AssetRepository _repository;
  final Clock _clock;

  final Map<String, Asset> _byId = {};
  final Map<String, Asset> _byPriceId = {};
  final Map<String, String> _contracts = {};

  /// 把库中的币种与合约对应读入内存；可重复调用（会重新读取）。
  ///
  /// 库中币种的 id 与内置币种相同但内容不同时（内置表后来新增了同名币种），
  /// 忽略库中那条及指向它的合约对应，让下次同步重新查询并合并到内置币种。
  Future<void> load() async {
    final assets = await _repository.all();
    final contracts = await _repository.contracts();
    _byId.clear();
    _byPriceId.clear();
    _contracts.clear();
    for (final a in assets) {
      final builtIn = _builtIn.byId(a.id);
      if (builtIn != null && builtIn != a) continue;
      _byId[a.id] = a;
      final pid = a.priceId;
      if (pid != null) _byPriceId.putIfAbsent(pid, () => a);
    }
    contracts.forEach((token, assetId) {
      if (_byId.containsKey(assetId)) _contracts[_key(token)] = assetId;
    });
  }

  @override
  Asset? resolve(TokenRef token) {
    final builtIn = _builtIn.resolve(token);
    if (builtIn != null || token is! ContractToken) return builtIn;
    final id = _contracts[_key(token)];
    return id == null ? null : byId(id);
  }

  @override
  Asset? byId(String assetId) => _builtIn.byId(assetId) ?? _byId[assetId];

  @override
  Asset? byPriceId(String priceId) =>
      _builtIn.byPriceId(priceId) ?? _byPriceId[priceId];

  @override
  Future<Map<ContractToken, Asset>> remember(
    Map<ContractToken, Asset> found,
  ) async {
    final chosen = <ContractToken, Asset>{};
    final pending = <String, Asset>{};
    for (final e in found.entries) {
      final asset = _canonical(e.value, pending);
      chosen[e.key] = asset;
      if (!_byId.containsKey(asset.id)) pending[asset.id] = asset;
    }
    final newContracts = {
      for (final e in chosen.entries)
        if (_contracts[_key(e.key)] != e.value.id) e.key: e.value.id,
    };
    if (pending.isEmpty && newContracts.isEmpty) return chosen;
    // 先写库、成功后再更新内存。
    await _repository.upsertAll(pending.values.toList(), now: _clock.nowUtc());
    await _repository.upsertContracts(newContracts);
    for (final a in pending.values) {
      _byId[a.id] = a;
      final pid = a.priceId;
      if (pid != null) _byPriceId.putIfAbsent(pid, () => a);
    }
    newContracts.forEach((token, id) => _contracts[_key(token)] = id);
    return chosen;
  }

  /// 同一价格源标识复用已有币种；id 被另一个价格源标识占用时改名为 `<符号>-<价格源标识大写>`，
  /// 避免同名仿冒币覆盖已保存的真币。
  Asset _canonical(Asset asset, Map<String, Asset> pending) {
    final pid = asset.priceId;
    if (pid != null) {
      final existing = byPriceId(pid) ?? _pendingByPriceId(pending, pid);
      if (existing != null) return existing;
    }
    final taken = byId(asset.id) ?? pending[asset.id];
    if (taken == null) return asset;
    return Asset(
      id: '${asset.symbol}-${(pid ?? asset.id).toUpperCase()}',
      symbol: asset.symbol,
      name: asset.name,
      priceId: pid,
    );
  }

  static Asset? _pendingByPriceId(Map<String, Asset> pending, String pid) {
    for (final a in pending.values) {
      if (a.priceId == pid) return a;
    }
    return null;
  }

  /// EVM 合约不区分大小写：键统一转小写；其他链原样。
  static String _key(ContractToken t) {
    final isEvm = Chains.tryById(t.chainId)?.family == ChainFamily.evm;
    return '${t.chainId}|${isEvm ? t.contract.toLowerCase() : t.contract}';
  }
}
