import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:ow_net/ow_net.dart';

import 'exact_json.dart';

/// 基于 CoinGecko 免费（Demo）档的价格源。接口核对记录见 docs/EXTERNAL_APIS.md。
///
/// - [fetchPrices]：`GET /simple/price`，按 `priceId` 批量查价与 24 小时涨跌。
/// - [lookupContracts]：`GET /coins/{平台}/contract/{地址}`，为内置映射表没有的合约代币
///   查出 CoinGecko 的币种标识。
///
/// 失败一律以 [Err] 返回，不抛异常。API Key 通过 [DataSourceConfig.apiKey]（`coingecko`）
/// 读取，可为空；有 Key 时放在 `x-cg-demo-api-key` 请求头，日志中会被脱敏。
class CoinGeckoPriceSource implements PriceSource {
  /// [client] 仅供测试注入（例如带假适配器的客户端）；生产代码不传。
  CoinGeckoPriceSource({
    required this._config,
    required this._clock,
    this._catalog,
    OwHttpClient? client,
    RateLimiter? rateLimiter,
    OwLogSink? onLog,
    this.cacheTtl = const Duration(minutes: 5),
    this.lookupCacheTtl = const Duration(hours: 1),
    this.maxIdsPerRequest = 100,
    this.maxLookupsPerCall = 20,
  }) : _client =
           client ??
           OwHttpClientFactory.create(
             OwHttpConfig(
               baseUrl: baseUrl,
               extraSensitiveNames: const [keyHeader],
               onLog: onLog,
             ),
           ),
       // Demo 档官方口径为每分钟 100 次（errors-and-rate-limits）；这里取更保守的 30 次。
       _limiter =
           rateLimiter ??
           RateLimiter(maxRequests: 30, window: const Duration(minutes: 1));

  static const providerId = 'coingecko';
  static const baseUrl = 'https://api.coingecko.com/api/v3';
  static const keyHeader = 'x-cg-demo-api-key';

  /// 内置链 id 到 CoinGecko asset platform id。Bitcoin 没有合约代币，不在表中。
  static const platformIds = <String, String>{
    'ethereum': 'ethereum',
    'bsc': 'binance-smart-chain',
    'arbitrum': 'arbitrum-one',
    'optimism': 'optimistic-ethereum',
    'base': 'base',
    'polygon': 'polygon-pos',
    'solana': 'solana',
    'tron': 'tron',
  };

  /// 同一 (币种, 计价货币) 的价格在这段时间内不重复请求。
  final Duration cacheTtl;

  /// 合约查询结果（含"查不到"）的缓存时长；合约与币种的对应关系很少变化。
  final Duration lookupCacheTtl;

  /// `simple/price` 单次请求的 id 数量上限。官方文档未明示 Demo 档的上限
  /// （见 EXTERNAL_APIS.md），取保守值 100，也让 URL 长度保持在安全范围。
  final int maxIdsPerRequest;

  /// 一次 [lookupContracts] 最多发出的请求数（每个合约一次，受限频约束）。
  final int maxLookupsPerCall;

  final DataSourceConfig _config;
  final Clock _clock;
  final AssetCatalog? _catalog;
  final OwHttpClient _client;
  final RateLimiter _limiter;

  final Map<(String, Quote), _CachedPrice> _priceCache = {};
  final Map<ContractToken, _CachedLookup> _lookupCache = {};

  @override
  Future<Result<List<Price>>> fetchPrices(
    Set<Asset> assets,
    Quote quote,
  ) async {
    // 没有 priceId 的跳过；同一 priceId 可能对应多个 Asset。
    final byPriceId = <String, List<Asset>>{};
    for (final asset in assets) {
      final pid = asset.priceId;
      if (pid == null || pid.isEmpty) continue;
      byPriceId.putIfAbsent(pid, () => []).add(asset);
    }

    final now = _clock.nowUtc();
    final result = <Price>[];
    final missing = <String>[];
    for (final entry in byPriceId.entries) {
      var allCached = true;
      for (final asset in entry.value) {
        final cached = _priceCache[(asset.id, quote)];
        if (cached != null && now.difference(cached.fetchedAt) < cacheTtl) {
          result.add(cached.price);
        } else {
          allCached = false;
        }
      }
      if (!allCached) missing.add(entry.key);
    }
    if (missing.isEmpty) return Ok(result);

    // 已在缓存里的同 priceId 资产会被重新写入，不会重复出现在结果中。
    result.clear();
    missing.sort();
    for (var i = 0; i < missing.length; i += maxIdsPerRequest) {
      final batch = missing.sublist(
        i,
        i + maxIdsPerRequest > missing.length
            ? missing.length
            : i + maxIdsPerRequest,
      );
      final response = await _getJson('/simple/price', {
        'ids': batch.join(','),
        'vs_currencies': quote.name,
        'include_24hr_change': 'true',
        'include_last_updated_at': 'true',
        // 官方文档：precision=full 返回完整小数位，避免低价币被截断。
        'precision': 'full',
      });
      switch (response) {
        // 任一批失败则整体失败；已成功的批次已写入缓存，重试时不会重复请求。
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          final parsed = _parsePrices(value, batch, quote, now);
          _storeBatch(parsed, batch, byPriceId, quote, now);
      }
    }

    for (final entry in byPriceId.entries) {
      for (final asset in entry.value) {
        final cached = _priceCache[(asset.id, quote)];
        if (cached != null && now.difference(cached.fetchedAt) < cacheTtl) {
          result.add(cached.price);
        }
      }
    }
    return Ok(result);
  }

  void _storeBatch(
    Map<String, ({Decimal price, Decimal? change, DateTime at})> fresh,
    List<String> batch,
    Map<String, List<Asset>> byPriceId,
    Quote quote,
    DateTime now,
  ) {
    for (final pid in batch) {
      final item = fresh[pid];
      if (item == null) continue;
      for (final asset in byPriceId[pid]!) {
        _priceCache[(asset.id, quote)] = _CachedPrice(
          Price(
            assetId: asset.id,
            quote: quote,
            price: item.price,
            change24hPercent: item.change,
            updatedAt: item.at,
          ),
          now,
        );
      }
    }
  }

  /// 解析 `simple/price` 的响应：`{"bitcoin": {"usd": 1.0, "usd_24h_change": 2.5, ...}}`。
  /// 缺少某个币、缺少价格或价格不是数字的条目被跳过。
  Map<String, ({Decimal price, Decimal? change, DateTime at})> _parsePrices(
    Object? body,
    List<String> requested,
    Quote quote,
    DateTime now,
  ) {
    final out = <String, ({Decimal price, Decimal? change, DateTime at})>{};
    if (body is! Map<String, Object?>) return out;
    for (final pid in requested) {
      final item = body[pid];
      if (item is! Map<String, Object?>) continue;
      final price = decimalFromJson(item[quote.name]);
      // 价格为 0 或负数视为无效，避免把"无报价"估成 0。
      if (price == null || price <= Decimal.zero) continue;
      final change = decimalFromJson(item['${quote.name}_24h_change']);
      final ts = item['last_updated_at'];
      final seconds = ts is JsonNumber ? int.tryParse(ts.text) : null;
      out[pid] = (
        price: price,
        change: change,
        at: seconds == null
            ? now
            : DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true),
      );
    }
    return out;
  }

  @override
  Future<Result<Map<ContractToken, Asset>>> lookupContracts(
    Set<ContractToken> tokens,
  ) async {
    final found = <ContractToken, Asset>{};
    final now = _clock.nowUtc();
    var requests = 0;
    for (final token in tokens) {
      final platform = platformIds[token.chainId];
      // CoinGecko 不支持的链、或不合法的地址写法：跳过，不算失败。
      if (platform == null || !_safeSegment.hasMatch(token.contract)) continue;

      final cached = _lookupCache[token];
      if (cached != null && now.difference(cached.at) < lookupCacheTtl) {
        final asset = cached.asset;
        if (asset != null) found[token] = asset;
        continue;
      }
      if (requests >= maxLookupsPerCall) continue;
      requests++;

      final response = await _getJson(
        '/coins/$platform/contract/${token.contract}',
        // 官方文档（Demo 档 /coins/{id}/contract/{contract_address}）没有列出
        // 任何查询参数，故不带。
        const {},
        // 404：CoinGecko 不认识这个合约；403：该接口在当前档位不可用。
        // 两者都按"查不到"处理，其余错误（限频、网络、服务故障、401）照实返回。
        emptyOnStatus: const {403, 404},
      );
      switch (response) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          final asset = value == null ? null : _assetFromCoin(value);
          _lookupCache[token] = _CachedLookup(asset, now);
          if (asset != null) found[token] = asset;
      }
    }
    return Ok(found);
  }

  /// `/coins/{平台}/contract/{地址}` 的响应里取 `id`、`symbol`、`name`。
  Asset? _assetFromCoin(Object body) {
    if (body is! Map<String, Object?>) return null;
    final id = body['id'];
    final symbol = body['symbol'];
    final name = body['name'];
    if (id is! String || id.isEmpty || symbol is! String || symbol.isEmpty) {
      return null;
    }
    final catalog = _catalog;
    if (catalog != null) {
      // CoinGecko 认为它就是已知币种（例如某链上的新部署）：合并到该币种。
      final known = catalog.byPriceId(id);
      if (known != null) return known;
    }
    final upper = symbol.toUpperCase();
    // 任何人都能发行同名代币。符号与内置币种相同但币种标识不同时加后缀，
    // 避免仿冒币被当成真币估值。
    final clash = catalog?.byId(upper) != null;
    return Asset(
      id: clash ? '$upper-${id.toUpperCase()}' : upper,
      symbol: upper,
      name: name is String && name.isNotEmpty ? name : upper,
      priceId: id,
    );
  }

  static final _safeSegment = RegExp(r'^[A-Za-z0-9]{20,64}$');

  /// 发请求并按原文解析 JSON（数字不经过 double）。
  ///
  /// [emptyOnStatus] 中的状态码返回 `Ok(null)`。
  Future<Result<Object?>> _getJson(
    String path,
    Map<String, String> query, {
    Set<int> emptyOnStatus = const {},
  }) async {
    final key = await _config.apiKey(providerId);
    final headers = <String, String>{
      if (key != null && key.trim().isNotEmpty) keyHeader: key.trim(),
    };
    final Response<String> response;
    try {
      response = await _limiter.run(
        () => _client.dio.get<String>(
          path,
          queryParameters: query,
          options: Options(headers: headers, responseType: ResponseType.plain),
        ),
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status != null && emptyOnStatus.contains(status)) {
        return const Ok(null);
      }
      return Err(mapHttpFailure(e));
    }

    final status = response.statusCode ?? 0;
    final host = response.requestOptions.uri.host;
    if (status < 200 || status > 299) return Err(mapHttpStatus(status, host));
    final text = response.data;
    if (text == null || text.trim().isEmpty) return const Ok(null);
    try {
      return Ok(parseJsonExact(text));
    } on FormatException {
      // 不带响应原文。
      return Err(UnknownFailure('响应不是合法 JSON host=$host'));
    }
  }
}

final class _CachedPrice {
  const _CachedPrice(this.price, this.fetchedAt);
  final Price price;
  final DateTime fetchedAt;
}

final class _CachedLookup {
  const _CachedLookup(this.asset, this.at);
  final Asset? asset;
  final DateTime at;
}
