import 'package:decimal/decimal.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:ow_net/ow_net.dart';

/// 创建 HTTP 客户端的函数。生产代码用默认的 [OwHttpClientFactory.create]，
/// 测试注入带假适配器的实现，不访问真实网络。
typedef OwHttpClientBuilder = OwHttpClient Function(OwHttpConfig config);

/// EVM 链的只读余额查询，数据服务默认 Alchemy（TECH_DESIGN 6.2）。
///
/// - 原生币：标准 JSON-RPC `eth_getBalance`；
/// - 代币：`alchemy_getTokenBalances`（分页）加 `alchemy_getTokenMetadata`（带内存缓存）；
/// - 用户配置了自定义节点（[DataSourceConfig.customEndpoint]）时只查原生币：
///   标准 JSON-RPC 无法发现代币。
///
/// 接口细节见 `docs/EXTERNAL_APIS.md` 的"Alchemy（EVM）"一节。
/// 日志与 [Failure.detail] 中不含完整地址和 API Key。
final class EvmChainAdapter implements ChainAdapter {
  EvmChainAdapter({
    required this.config,
    OwHttpClientBuilder? clientBuilder,
    RateLimiter? rateLimiter,
    this.metadataConcurrency = 4,
    this.maxTokenPages = 50,
    this.onLog,
  }) : _builder = clientBuilder ?? OwHttpClientFactory.create,
       _limiter =
           rateLimiter ??
           RateLimiter(maxRequests: 10, window: const Duration(seconds: 1));

  /// Alchemy 服务商标识，用于 [DataSourceConfig.apiKey]。
  static const providerId = 'alchemy';

  /// 链 id 到 Alchemy 主机名。未核对官方文档，见 EXTERNAL_APIS.md；
  /// 不在表中的链返回 [UnsupportedFailure]（自定义节点除外）。
  static const alchemyHosts = <String, String>{
    'ethereum': 'eth-mainnet.g.alchemy.com',
    'bsc': 'bnb-mainnet.g.alchemy.com',
    'arbitrum': 'arb-mainnet.g.alchemy.com',
    'optimism': 'opt-mainnet.g.alchemy.com',
    'base': 'base-mainnet.g.alchemy.com',
    'polygon': 'polygon-mainnet.g.alchemy.com',
  };

  /// 代币元数据请求的并发上限。
  final int metadataConcurrency;

  /// 代币分页的页数上限，防止服务端异常时无限循环。
  final int maxTokenPages;

  /// 用户的数据源配置：API Key 与自定义节点。
  final DataSourceConfig config;

  /// 传入才记录脱敏日志（见 ow_net）。
  final OwLogSink? onLog;

  final OwHttpClientBuilder _builder;
  final RateLimiter _limiter;

  final Map<String, OwHttpClient> _clients = {};
  final Map<String, _TokenMeta> _metaCache = {};
  int _nextId = 1;

  @override
  ChainFamily get family => ChainFamily.evm;

  @override
  Future<Result<List<RawHolding>>> fetchHoldings(
    String address,
    ChainInfo chain,
  ) async {
    final target = await _resolve(chain);
    if (target is Err<_Target>) return Err(target.failure);
    final t = (target as Ok<_Target>).value;

    final native = await _rpc(t, 'eth_getBalance', [address, 'latest']);
    if (native is Err<Object?>) return Err(native.failure);
    final nativeWei = _parseHex((native as Ok<Object?>).value);
    if (nativeWei == null) {
      return Err(UnknownFailure('eth_getBalance 返回值无效 chain=${chain.id}'));
    }

    final holdings = <RawHolding>[];
    if (nativeWei > BigInt.zero) {
      holdings.add(
        RawHolding(
          token: NativeToken(chain.id),
          amount: _scale(nativeWei, chain.nativeDecimals),
          symbolHint: chain.nativeSymbol,
          nameHint: chain.name,
        ),
      );
    }
    // 自定义节点：只查原生币。
    if (t.isCustom) return Ok(holdings);

    final balances = await _tokenBalances(t, address, chain);
    if (balances is Err<Map<String, BigInt>>) return Err(balances.failure);
    final raw = (balances as Ok<Map<String, BigInt>>).value;

    final metas = await _metadata(t, chain, raw.keys.toList());
    if (metas is Err<Map<String, _TokenMeta>>) return Err(metas.failure);
    final metaMap = (metas as Ok<Map<String, _TokenMeta>>).value;

    for (final entry in raw.entries) {
      final meta = metaMap[entry.key];
      // 元数据查不到或没有小数位时无法换算，跳过这个代币。
      if (meta == null || meta.decimals == null) continue;
      holdings.add(
        RawHolding(
          token: ContractToken(chain.id, entry.key),
          amount: _scale(entry.value, meta.decimals!),
          symbolHint: meta.symbol,
          nameHint: meta.name,
        ),
      );
    }
    return Ok(holdings);
  }

  @override
  Future<Result<bool>> hasActivity(String address, ChainInfo chain) async {
    final target = await _resolve(chain);
    if (target is Err<_Target>) return Err(target.failure);
    final t = (target as Ok<_Target>).value;

    final balance = await _rpc(t, 'eth_getBalance', [address, 'latest']);
    if (balance is Err<Object?>) return Err(balance.failure);
    final wei = _parseHex((balance as Ok<Object?>).value);
    if (wei == null) {
      return Err(UnknownFailure('eth_getBalance 返回值无效 chain=${chain.id}'));
    }
    if (wei > BigInt.zero) return const Ok(true);

    final count = await _rpc(t, 'eth_getTransactionCount', [address, 'latest']);
    if (count is Err<Object?>) return Err(count.failure);
    final n = _parseHex((count as Ok<Object?>).value);
    if (n == null) {
      return Err(
        UnknownFailure('eth_getTransactionCount 返回值无效 chain=${chain.id}'),
      );
    }
    return Ok(n > BigInt.zero);
  }

  // ---- 目标解析 ----

  Future<Result<_Target>> _resolve(ChainInfo chain) async {
    if (chain.family != ChainFamily.evm) {
      return Err(UnsupportedFailure('非 EVM 链 chain=${chain.id}'));
    }
    final custom = await config.customEndpoint(chain.id);
    if (custom != null) {
      if (custom.scheme != 'https' || custom.host.isEmpty) {
        return Err(ValidationFailure('自定义节点必须是 https chain=${chain.id}'));
      }
      final path = custom.hasQuery
          ? '${custom.path}?${custom.query}'
          : custom.path;
      return Ok(_Target(custom.origin, path, isCustom: true));
    }
    final host = alchemyHosts[chain.id];
    if (host == null) {
      return Err(UnsupportedFailure('Alchemy 不支持该链 chain=${chain.id}'));
    }
    final key = await config.apiKey(providerId);
    if (key == null || key.isEmpty) {
      return const Err(UnauthorizedFailure('missing api key'));
    }
    return Ok(_Target('https://$host', '/v2/$key', isCustom: false));
  }

  OwHttpClient _client(_Target t) => _clients.putIfAbsent(
    t.baseUrl,
    () => _builder(
      OwHttpConfig(
        baseUrl: t.baseUrl,
        defaultHeaders: const {'Accept': 'application/json'},
        onLog: onLog,
      ),
    ),
  );

  // ---- JSON-RPC ----

  /// 发一次 JSON-RPC 并返回 `result`；`error` 对象映射为 [Failure]。
  Future<Result<Object?>> _rpc(
    _Target t,
    String method,
    List<Object?> params,
  ) async {
    final Result<Object?> res;
    try {
      res = await _limiter.run(
        () => _client(t).postJson(
          t.path,
          body: {
            'jsonrpc': '2.0',
            'id': _nextId++,
            'method': method,
            'params': params,
          },
        ),
      );
    } on ArgumentError {
      return const Err(ValidationFailure('请求地址无效'));
    }
    if (res is Err<Object?>) return res;
    final body = (res as Ok<Object?>).value;
    if (body is! Map<String, Object?>) {
      return Err(UnknownFailure('JSON-RPC 响应结构无效 method=$method'));
    }
    final error = body['error'];
    if (error != null) return Err(_mapRpcError(error, method));
    if (!body.containsKey('result')) {
      return Err(UnknownFailure('JSON-RPC 响应缺少 result method=$method'));
    }
    return Ok(body['result']);
  }

  /// 把 JSON-RPC 的 error 对象映射为 [Failure]。`detail` 只含方法名和错误码，
  /// 不含 message（可能回显地址或 Key）。
  Failure _mapRpcError(Object error, String method) {
    final code = error is Map<String, Object?> ? error['code'] : null;
    final detail = 'JSON-RPC error method=$method code=$code';
    if (code == 429 || code == -32005) return RateLimitedFailure(detail);
    if (code == 401 || code == 403) return UnauthorizedFailure(detail);
    if (code == -32601) return UnsupportedFailure(detail);
    if (code is int && (code == -32603 || (code <= -32000 && code >= -32099))) {
      return ServiceDownFailure(detail);
    }
    return UnknownFailure(detail);
  }

  // ---- 代币余额 ----

  /// 全部非零 ERC-20 余额（合约地址小写 → 原始整数），自动翻页。
  Future<Result<Map<String, BigInt>>> _tokenBalances(
    _Target t,
    String address,
    ChainInfo chain,
  ) async {
    final result = <String, BigInt>{};
    String? pageKey;
    for (var page = 0; page < maxTokenPages; page++) {
      final res = await _rpc(t, 'alchemy_getTokenBalances', [
        address,
        'erc20',
        {'maxCount': 100, 'pageKey': ?pageKey},
      ]);
      if (res is Err<Object?>) return Err(res.failure);
      final body = (res as Ok<Object?>).value;
      final list = body is Map<String, Object?> ? body['tokenBalances'] : null;
      if (list is! List<Object?>) {
        return Err(UnknownFailure('代币余额响应结构无效 chain=${chain.id}'));
      }
      for (final item in list) {
        if (item is! Map<String, Object?>) continue;
        final contract = item['contractAddress'];
        // 单个代币带 error 时（如合约不规范）忽略该代币。
        if (contract is! String || item['error'] != null) continue;
        final amount = _parseHex(item['tokenBalance']);
        if (amount == null || amount == BigInt.zero) continue;
        result[contract.toLowerCase()] = amount;
      }
      final next = (body as Map<String, Object?>)['pageKey'];
      if (next is! String || next.isEmpty) return Ok(result);
      pageKey = next;
    }
    return Err(UnknownFailure('代币分页超过上限 chain=${chain.id}'));
  }

  // ---- 代币元数据 ----

  Future<Result<Map<String, _TokenMeta>>> _metadata(
    _Target t,
    ChainInfo chain,
    List<String> contracts,
  ) async {
    final out = <String, _TokenMeta>{};
    final missing = <String>[];
    for (final c in contracts) {
      final cached = _metaCache['${chain.id}:$c'];
      if (cached != null) {
        out[c] = cached;
      } else {
        missing.add(c);
      }
    }
    for (var i = 0; i < missing.length; i += metadataConcurrency) {
      final batch = missing.skip(i).take(metadataConcurrency).toList();
      final results = await Future.wait(
        batch.map((c) => _rpc(t, 'alchemy_getTokenMetadata', [c])),
      );
      for (var j = 0; j < batch.length; j++) {
        final r = results[j];
        if (r is Err<Object?>) {
          // 单个代币的普通错误只跳过它；限频、凭据、网络、服务故障整体失败。
          if (r.failure is UnknownFailure) continue;
          return Err(r.failure);
        }
        final meta = _parseMeta((r as Ok<Object?>).value);
        _metaCache['${chain.id}:${batch[j]}'] = meta;
        out[batch[j]] = meta;
      }
    }
    return Ok(out);
  }

  _TokenMeta _parseMeta(Object? value) {
    if (value is! Map<String, Object?>) {
      return const _TokenMeta(null, null, null);
    }
    final d = value['decimals'];
    String? text(Object? v) => v is String && v.trim().isNotEmpty ? v : null;
    return _TokenMeta(
      d is int && d >= 0 && d <= 77 ? d : null,
      text(value['symbol']),
      text(value['name']),
    );
  }

  // ---- 数值 ----

  /// 解析 `0x` 开头的十六进制整数；无效返回 null。`0x` 视为 0。
  static BigInt? _parseHex(Object? v) {
    if (v is! String || !v.startsWith('0x')) return null;
    final digits = v.substring(2);
    if (digits.isEmpty) return BigInt.zero;
    return BigInt.tryParse(digits, radix: 16);
  }

  /// 整数最小单位换算为以币为单位的 [Decimal]，精确无舍入。
  static Decimal _scale(BigInt raw, int decimals) =>
      Decimal.fromBigInt(raw).shift(-decimals);
}

final class _Target {
  const _Target(this.baseUrl, this.path, {required this.isCustom});
  final String baseUrl;
  final String path;
  final bool isCustom;
}

final class _TokenMeta {
  const _TokenMeta(this.decimals, this.symbol, this.name);
  final int? decimals;
  final String? symbol;
  final String? name;
}
