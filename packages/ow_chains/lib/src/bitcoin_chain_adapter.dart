import 'package:ow_domain/ow_domain.dart';
import 'package:ow_net/ow_net.dart';

import 'chain_support.dart';
import 'evm_chain_adapter.dart' show OwHttpClientBuilder;

/// Bitcoin 的只读余额查询，数据服务默认 mempool.space 的 Esplora 兼容 REST 接口
/// （无需 Key，TECH_DESIGN 6.2）。
///
/// - 一次 `GET /api/address/{地址}` 同时给出余额统计与交易计数；
///   P2PKH（1…）、P2SH（3…）、bech32（bc1q…）、bech32m（bc1p…）都走同一接口；
/// - **余额口径：只计已确认**，即 `chain_stats.funded_txo_sum − spent_txo_sum`
///   （单位聪，换算为 BTC，8 位小数）。内存池里的未确认部分（`mempool_stats`）
///   不计入：未确认的收入可能被替换或丢弃，未确认的支出也可能不被打包，
///   看板只展示链上已落定的数量；
/// - [hasActivity]：已确认与未确认的交易计数之和非零；
/// - 用户配置了自定义实例（[DataSourceConfig.customEndpoint]，必须 https）时改用它，
///   路径前缀保留（如 `https://host/mempool` → `/mempool/api/address/…`）。
///
/// 接口细节见 `docs/EXTERNAL_APIS.md` 的"mempool.space（Bitcoin）"一节。
/// 日志与 [Failure.detail] 中不含完整地址。
final class BitcoinChainAdapter implements ChainAdapter {
  BitcoinChainAdapter({
    required this.config,
    OwHttpClientBuilder? clientBuilder,
    RateLimiter? rateLimiter,
    this.onLog,
  }) : _builder = clientBuilder ?? OwHttpClientFactory.create,
       _limiter =
           rateLimiter ??
           RateLimiter(maxRequests: 2, window: const Duration(seconds: 1));

  /// 默认数据服务的根地址。
  static const defaultBaseUrl = 'https://mempool.space';

  /// 用户的数据源配置：此处只用到自定义实例。
  final DataSourceConfig config;

  /// 传入才记录脱敏日志（见 ow_net）。
  final OwLogSink? onLog;

  final OwHttpClientBuilder _builder;
  final RateLimiter _limiter;
  final Map<String, OwHttpClient> _clients = {};

  @override
  ChainFamily get family => ChainFamily.bitcoin;

  @override
  Future<Result<List<RawHolding>>> fetchHoldings(
    String address,
    ChainInfo chain,
  ) async {
    final stats = await _fetchStats(address, chain);
    if (stats is Err<_AddressStats>) return Err(stats.failure);
    final s = (stats as Ok<_AddressStats>).value;
    final sats = s.confirmedFunded - s.confirmedSpent;
    if (sats < 0) {
      return const Err(UnknownFailure('已确认的支出大于收入，响应无效'));
    }
    if (sats == 0) return const Ok([]);
    return Ok([
      RawHolding(
        token: NativeToken(chain.id),
        amount: scaleAmount(BigInt.from(sats), chain.nativeDecimals),
        symbolHint: chain.nativeSymbol,
        nameHint: chain.name,
      ),
    ]);
  }

  @override
  Future<Result<bool>> hasActivity(String address, ChainInfo chain) async {
    final stats = await _fetchStats(address, chain);
    if (stats is Err<_AddressStats>) return Err(stats.failure);
    final s = (stats as Ok<_AddressStats>).value;
    return Ok(s.confirmedTxCount + s.mempoolTxCount > 0);
  }

  Future<Result<_AddressStats>> _fetchStats(
    String address,
    ChainInfo chain,
  ) async {
    if (chain.family != ChainFamily.bitcoin) {
      return Err(
        UnsupportedFailure.notIntegrated('非 Bitcoin 链 chain=${chain.id}'),
      );
    }
    if (!isPathSafeAddress(address)) {
      return const Err(ValidationFailure('地址包含非法字符'));
    }
    final custom = await config.customEndpoint(chain.id);
    var base = defaultBaseUrl;
    var prefix = '';
    if (custom != null) {
      final bad = validateCustomEndpoint(custom, chain.id);
      if (bad != null) return Err(bad);
      base = custom.origin;
      prefix = trimTrailingSlash(custom.path);
    }

    final OwHttpClient client;
    try {
      client = _clients.putIfAbsent(
        base,
        () => _builder(
          OwHttpConfig(
            baseUrl: base,
            defaultHeaders: const {'Accept': 'application/json'},
            onLog: onLog,
          ),
        ),
      );
    } on ArgumentError {
      return const Err(ValidationFailure('请求地址无效'));
    }
    final res = await _limiter.run(
      () => client.getJson('$prefix/api/address/$address'),
    );
    if (res is Err<Object?>) return Err(res.failure);
    return _parse((res as Ok<Object?>).value);
  }

  /// 解析 Esplora 的地址统计。任何必需字段缺失或不是整数都视为响应无效。
  Result<_AddressStats> _parse(Object? body) {
    if (body is! Map<String, Object?>) {
      return const Err(UnknownFailure('地址响应结构无效'));
    }
    final chainStats = body['chain_stats'];
    final mempoolStats = body['mempool_stats'];
    if (chainStats is! Map<String, Object?> ||
        mempoolStats is! Map<String, Object?>) {
      return const Err(UnknownFailure('地址响应缺少统计字段'));
    }
    final funded = chainStats['funded_txo_sum'];
    final spent = chainStats['spent_txo_sum'];
    final confirmedTx = chainStats['tx_count'];
    final mempoolTx = mempoolStats['tx_count'];
    if (funded is! int ||
        spent is! int ||
        confirmedTx is! int ||
        mempoolTx is! int ||
        funded < 0 ||
        spent < 0) {
      return const Err(UnknownFailure('地址统计字段无效'));
    }
    return Ok(_AddressStats(funded, spent, confirmedTx, mempoolTx));
  }
}

final class _AddressStats {
  const _AddressStats(
    this.confirmedFunded,
    this.confirmedSpent,
    this.confirmedTxCount,
    this.mempoolTxCount,
  );
  final int confirmedFunded;
  final int confirmedSpent;
  final int confirmedTxCount;
  final int mempoolTxCount;
}
