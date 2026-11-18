import 'dart:convert';

import 'package:ow_domain/ow_domain.dart';

import 'asset_mappings_data.dart';

/// 内置币种映射表（PRD R8）。数据来自 `asset_mappings.json`（内嵌为 Dart 常量）。
///
/// 解析顺序：原生币按链 id；合约代币按（链 id，规范化合约）；
/// 交易所符号先查别名表，再按"大写符号 == 标准币种 id"匹配。
class BuiltInAssetCatalog implements AssetCatalog {
  /// 使用内嵌的映射数据。数据损坏属于程序缺陷，抛出 [FormatException]。
  BuiltInAssetCatalog() : this.fromJson(builtInAssetMappingsJson);

  /// 从 JSON 文本构建，格式见 `asset_mappings.json`。仅供测试使用自造数据。
  ///
  /// 结构不合法（缺字段、未知链、重复项）时抛出 [FormatException]。
  BuiltInAssetCatalog.fromJson(String json) {
    final root = jsonDecode(json);
    if (root is! Map<String, dynamic>) {
      throw const FormatException('映射表根节点必须是对象');
    }
    final assets = _list(root['assets'], 'assets');
    for (final raw in assets) {
      final item = _map(raw, 'assets[]');
      final asset = Asset(
        id: _string(item, 'id'),
        symbol: _string(item, 'symbol'),
        name: _string(item, 'name'),
        priceId: _string(item, 'priceId'),
      );
      if (_byId.containsKey(asset.id)) {
        throw FormatException('币种 id 重复：${asset.id}');
      }
      _byId[asset.id] = asset;
      _byPriceId.putIfAbsent(asset.priceId!, () => asset);

      for (final chainId in _list(item['native'] ?? const [], 'native')) {
        final chain = _chain(chainId, asset.id);
        if (_native.containsKey(chain.id)) {
          throw FormatException('链 ${chain.id} 的原生币重复');
        }
        _native[chain.id] = asset;
      }

      final contracts = _map(item['contracts'] ?? const {}, 'contracts');
      final decimalsMap = _map(item['decimals'] ?? const {}, 'decimals');
      for (final entry in contracts.entries) {
        final chain = _chain(entry.key, asset.id);
        final contract = entry.value;
        if (contract is! String || contract.isEmpty) {
          throw FormatException('${asset.id} 在 ${chain.id} 的合约必须是非空字符串');
        }
        final key = _contractKey(chain.id, contract);
        if (_contracts.containsKey(key)) {
          throw FormatException('合约重复：${chain.id} $contract');
        }
        _contracts[key] = asset;
        int? dec;
        if (decimalsMap.containsKey(chain.id)) {
          final val = decimalsMap[chain.id];
          if (val is! int || val < 0 || val > 36) {
            throw FormatException(
              '${asset.id} 在 ${chain.id} 的 decimals 必须是 0–36 的整数',
            );
          }
          dec = val;
          _contractDecimals[key] = val;
        }
        _contractList.add(
          CatalogContract(
            ContractToken(chain.id, contract),
            asset,
            decimals: dec,
          ),
        );
      }
    }

    final aliases = _map(root['exchangeAliases'] ?? const {}, 'aliases');
    for (final entry in aliases.entries) {
      final exchange = ExchangeId.values
          .where((e) => e.name == entry.key)
          .firstOrNull;
      if (exchange == null) {
        throw FormatException('未知的交易所：${entry.key}');
      }
      final table = <String, Asset>{};
      for (final alias in _map(entry.value, 'aliases.${entry.key}').entries) {
        final target = _byId[alias.value];
        if (target == null) {
          throw FormatException('别名 ${alias.key} 指向不存在的币种 ${alias.value}');
        }
        table[alias.key.toUpperCase()] = target;
      }
      _aliases[exchange] = table;
    }
  }

  final Map<String, Asset> _byId = {};
  final Map<String, Asset> _byPriceId = {};
  final Map<String, Asset> _native = {};
  final Map<String, Asset> _contracts = {};
  final Map<String, int> _contractDecimals = {};
  final List<CatalogContract> _contractList = [];
  final Map<ExchangeId, Map<String, Asset>> _aliases = {};

  /// 全部标准币种，保持 JSON 中的顺序。
  List<Asset> get assets => List.unmodifiable(_byId.values);

  /// 全部内置合约条目（合约为规范化形式）。
  List<CatalogContract> get contracts => List.unmodifiable(_contractList);

  /// 查询合约代币的小数位（未在内置表指定时为 null）。
  int? decimalsOf(ContractToken token) =>
      _contractDecimals[_contractKey(token.chainId, token.contract)];

  /// 内置 TRC-20 合约的小数位数（合约 Base58 地址 → 小数位），供 `TronChainAdapter` 使用。
  Map<String, int> get tronDecimals {
    final result = <String, int>{};
    for (final c in _contractList) {
      if (c.token.chainId == 'tron') {
        final d = decimalsOf(c.token);
        if (d != null) {
          result[c.token.contract] = d;
        }
      }
    }
    return Map.unmodifiable(result);
  }

  @override
  Asset? byId(String assetId) => _byId[assetId];

  @override
  Asset? byPriceId(String priceId) => _byPriceId[priceId];

  @override
  Asset? resolve(TokenRef token) => switch (token) {
    NativeToken(:final chainId) => _native[chainId],
    ContractToken(:final chainId, :final contract) =>
      _contracts[_contractKey(chainId, contract)],
    ExchangeToken(:final exchange, :final symbol) => _resolveExchange(
      exchange,
      symbol,
    ),
  };

  Asset? _resolveExchange(ExchangeId exchange, String symbol) {
    final upper = symbol.trim().toUpperCase();
    if (upper.isEmpty) return null;
    return _aliases[exchange]?[upper] ?? _byId[upper];
  }

  /// EVM 合约不区分大小写，查表前先转小写；其他链原样。
  static String _contractKey(String chainId, String contract) {
    final isEvm = Chains.tryById(chainId)?.family == ChainFamily.evm;
    return '$chainId|${isEvm ? contract.toLowerCase() : contract}';
  }

  static ChainInfo _chain(Object? chainId, String assetId) {
    final chain = chainId is String ? Chains.tryById(chainId) : null;
    if (chain == null) {
      throw FormatException('$assetId 引用了未知的链：$chainId');
    }
    return chain;
  }

  static List<Object?> _list(Object? v, String name) {
    if (v is! List<Object?>) throw FormatException('$name 必须是数组');
    return v;
  }

  static Map<String, dynamic> _map(Object? v, String name) {
    if (v is! Map) throw FormatException('$name 必须是对象');
    return v.cast<String, dynamic>();
  }

  static String _string(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v is! String || v.isEmpty) {
      throw FormatException('$key 必须是非空字符串');
    }
    return v;
  }
}

/// 内置合约条目：一个合约代币及其标准币种。
final class CatalogContract {
  const CatalogContract(this.token, this.asset, {this.decimals});
  final ContractToken token;
  final Asset asset;
  final int? decimals;
}
