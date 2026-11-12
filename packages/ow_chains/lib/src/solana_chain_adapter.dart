import 'package:ow_domain/ow_domain.dart';
import 'package:ow_net/ow_net.dart';

import 'chain_support.dart';
import 'evm_chain_adapter.dart' show OwHttpClientBuilder;
import 'solana_parsing.dart';

/// Solana 的只读余额查询，标准 JSON-RPC（TECH_DESIGN 6.2）。
///
/// - 原生币：`getBalance`（lamports，9 位小数）；
/// - 代币：`getTokenAccountsByOwner`（`jsonParsed` 编码）分别按 Token Program
///   与 Token-2022 Program 各查一次；同一 mint 的多个代币账户**合并求和**；
///   数量取返回中的 `amount` 字符串与 `decimals` 做整数换算，不用 `uiAmount`（浮点）；
/// - **NFT 过滤**：合并后 `decimals == 0` 且数量恰为 1 的 mint 视为 NFT，不返回；
/// - 代币的 `symbolHint`、`nameHint` 留空：RPC 不返回元数据，由币种目录与价格源识别；
/// - [hasActivity]：余额非零，或 `getSignaturesForAddress`（limit 1）非空。
///
/// 端点优先级：[DataSourceConfig.customEndpoint]（必须 https，其查询串原样保留，
/// 其中的参数名一律按敏感信息脱敏）> 配置了 `helius` 的 API Key 时用 Helius 的
/// RPC（Key 放查询参数 `api-key`）> 官方公共 RPC（无需 Key，限制较严）。
///
/// 接口细节见 `docs/EXTERNAL_APIS.md` 的"Solana RPC（Helius 与公共节点）"一节。
/// 日志与 [Failure.detail] 中不含完整地址和 API Key。
final class SolanaChainAdapter implements ChainAdapter {
  SolanaChainAdapter({
    required this.config,
    OwHttpClientBuilder? clientBuilder,
    RateLimiter? rateLimiter,
    this.onLog,
  }) : _builder = clientBuilder ?? OwHttpClientFactory.create,
       _limiter =
           rateLimiter ??
           RateLimiter(maxRequests: 5, window: const Duration(seconds: 1));

  /// Helius 服务商标识，用于 [DataSourceConfig.apiKey]。
  static const providerId = 'helius';

  /// 官方公共 RPC。主机名来自既有知识，solana.com 文档当时无法访问，**未能核对**。
  static const publicRpcUrl = 'https://api.mainnet-beta.solana.com';

  /// Helius 主网 RPC（文档：`https://mainnet.helius-rpc.com/?api-key=<Key>`）。
  static const heliusRpcUrl = 'https://mainnet.helius-rpc.com';

  /// Token Program（SPL Token）。
  static const tokenProgramId = 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA';

  /// Token-2022 Program。
  static const token2022ProgramId =
      'TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb';

  /// 用户的数据源配置：Helius Key 与自定义节点。
  final DataSourceConfig config;

  /// 传入才记录脱敏日志（见 ow_net）。
  final OwLogSink? onLog;

  final OwHttpClientBuilder _builder;
  final RateLimiter _limiter;
  final Map<String, OwHttpClient> _clients = {};
  int _nextId = 1;

  @override
  ChainFamily get family => ChainFamily.solana;

  @override
  Future<Result<List<RawHolding>>> fetchHoldings(
    String address,
    ChainInfo chain,
  ) async {
    final target = await _resolve(address, chain);
    if (target is Err<_Target>) return Err(target.failure);
    final t = (target as Ok<_Target>).value;

    final balance = await _lamports(t, address);
    if (balance is Err<BigInt>) return Err(balance.failure);
    final lamports = (balance as Ok<BigInt>).value;

    final holdings = <RawHolding>[];
    if (lamports > BigInt.zero) {
      holdings.add(
        RawHolding(
          token: NativeToken(chain.id),
          amount: scaleAmount(lamports, chain.nativeDecimals),
          symbolHint: chain.nativeSymbol,
          nameHint: chain.name,
        ),
      );
    }

    final byMint = <String, MintBalance>{};
    for (final program in const [tokenProgramId, token2022ProgramId]) {
      final res = await _rpc(t, 'getTokenAccountsByOwner', [
        address,
        {'programId': program},
        {'encoding': 'jsonParsed', 'commitment': 'finalized'},
      ]);
      if (res is Err<Object?>) return Err(res.failure);
      final parsed = parseTokenAccounts((res as Ok<Object?>).value, byMint);
      if (!parsed) {
        return const Err(UnknownFailure('getTokenAccountsByOwner 响应结构无效'));
      }
    }

    for (final entry in byMint.entries) {
      final b = entry.value;
      if (b.amount == BigInt.zero) continue;
      if (isLikelyNft(b)) continue;
      holdings.add(
        RawHolding(
          token: ContractToken(chain.id, entry.key),
          amount: scaleAmount(b.amount, b.decimals),
        ),
      );
    }
    return Ok(holdings);
  }

  @override
  Future<Result<bool>> hasActivity(String address, ChainInfo chain) async {
    final target = await _resolve(address, chain);
    if (target is Err<_Target>) return Err(target.failure);
    final t = (target as Ok<_Target>).value;

    final balance = await _lamports(t, address);
    if (balance is Err<BigInt>) return Err(balance.failure);
    if ((balance as Ok<BigInt>).value > BigInt.zero) return const Ok(true);

    final sigs = await _rpc(t, 'getSignaturesForAddress', [
      address,
      {'limit': 1, 'commitment': 'finalized'},
    ]);
    if (sigs is Err<Object?>) return Err(sigs.failure);
    final list = (sigs as Ok<Object?>).value;
    if (list is! List<Object?>) {
      return const Err(UnknownFailure('getSignaturesForAddress 响应结构无效'));
    }
    return Ok(list.isNotEmpty);
  }

  Future<Result<BigInt>> _lamports(_Target t, String address) async {
    final res = await _rpc(t, 'getBalance', [
      address,
      {'commitment': 'finalized'},
    ]);
    if (res is Err<Object?>) return Err(res.failure);
    final value = parseBalanceResult((res as Ok<Object?>).value);
    if (value == null) return const Err(UnknownFailure('getBalance 返回值无效'));
    return Ok(value);
  }

  // ---- 目标解析 ----

  Future<Result<_Target>> _resolve(String address, ChainInfo chain) async {
    if (chain.family != ChainFamily.solana) {
      return Err(
        UnsupportedFailure.notIntegrated('非 Solana 链 chain=${chain.id}'),
      );
    }
    if (!isPathSafeAddress(address)) {
      return const Err(ValidationFailure('地址包含非法字符'));
    }
    final custom = await config.customEndpoint(chain.id);
    if (custom != null) {
      final bad = validateCustomEndpoint(custom, chain.id);
      if (bad != null) return Err(bad);
      return Ok(
        _Target(
          custom.origin,
          custom.path.isEmpty ? '/' : custom.path,
          custom.queryParametersAll.map((k, v) => MapEntry(k, v.join(','))),
          sensitiveNames: custom.queryParameters.keys.toList(),
        ),
      );
    }
    final key = await config.apiKey(providerId);
    if (key != null && key.isNotEmpty) {
      return Ok(_Target(heliusRpcUrl, '/', {'api-key': key}));
    }
    return const Ok(_Target(publicRpcUrl, '/', {}));
  }

  OwHttpClient _client(_Target t) => _clients.putIfAbsent(
    t.baseUrl,
    () => _builder(
      OwHttpConfig(
        baseUrl: t.baseUrl,
        defaultHeaders: const {'Accept': 'application/json'},
        extraSensitiveNames: t.sensitiveNames,
        onLog: onLog,
      ),
    ),
  );

  // ---- JSON-RPC ----

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
          queryParameters: t.query.isEmpty ? null : t.query,
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
  ///
  /// - -32005：Helius 文档的限频形式（`Too many requests`）；Solana 节点自身用
  ///   -32005 表示 `Node is unhealthy`。两者靠 message 区分（只读取、不保存）：
  ///   含 `too many` 或 `rate` 为限频，否则按服务故障；
  /// - 429 / 401 / 403 同 EVM 适配器的处理；-32601 方法不存在；
  /// - -32602 参数无效（如非法公钥）→ [ValidationFailure]；
  /// - -32603 与其余 -32000..-32099 → 服务故障。
  Failure _mapRpcError(Object error, String method) {
    final map = error is Map<String, Object?> ? error : null;
    final code = map?['code'];
    final message = map?['message'];
    final detail = 'JSON-RPC error method=$method code=$code';
    if (code == 429) return RateLimitedFailure(detail);
    if (code == 401 || code == 403) return UnauthorizedFailure(detail);
    if (code == -32601) return UnsupportedFailure.notIntegrated(detail);
    if (code == -32602) return ValidationFailure(detail);
    if (code == -32005 && message is String) {
      final m = message.toLowerCase();
      if (m.contains('too many') || m.contains('rate')) {
        return RateLimitedFailure(detail);
      }
    }
    if (code is int && (code == -32603 || (code <= -32000 && code >= -32099))) {
      return ServiceDownFailure(detail);
    }
    return UnknownFailure(detail);
  }
}

final class _Target {
  const _Target(
    this.baseUrl,
    this.path,
    this.query, {
    this.sensitiveNames = const ['api-key'],
  });
  final String baseUrl;
  final String path;
  final Map<String, Object?> query;

  /// 额外按敏感信息脱敏的查询参数名。
  final List<String> sensitiveNames;
}
