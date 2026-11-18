import 'package:ow_domain/ow_domain.dart';
import 'package:ow_net/ow_net.dart';

import 'chain_support.dart';
import 'evm_chain_adapter.dart' show OwHttpClientBuilder;
import 'tron_parsing.dart';

/// Tron 的只读余额查询，数据服务默认 TronGrid v1 API（TECH_DESIGN 6.2）。
///
/// - TRX：`GET /v1/accounts/{地址}`，**口径 = 可用余额 + Stake 2.0 质押 TRX**
///   （含委托给他人的部分与解锁等待中的部分，细则见 [parseTronAccount]）。
///   Stake 1.0 旧字段与未领取的投票奖励不计；
/// - TRC-20：`GET /v1/accounts/{地址}/trc20/balance`（分页，返回合约到余额串的映射，
///   不含 decimals）。decimals 先查构造时传入的 [knownDecimals]（装配层从内置映射表
///   传入，合约 Base58 地址 → 小数位），表里没有的合约再批量查
///   `GET /v1/trc20/info?contract_list=…`（只读，每批最多 20 个），同时取得符号与名称。
///   仍查不到 decimals 的代币跳过；
/// - 未激活的地址（`data` 为空）视为零 TRX，不是错误；
/// - [hasActivity]：账户已激活（`data` 非空）。
///
/// API Key 通过请求头 `TRON-PRO-API-KEY` 发送（`apiKey('trongrid')`，可缺省，
/// 但无 Key 时官方可能严格限频或拒绝）。**Key 只发给默认的 TronGrid 主机**，
/// 自定义节点（必须 https）不会收到它。
///
/// 接口细节见 `docs/EXTERNAL_APIS.md` 的"TronGrid（Tron）"一节。
/// 日志与 [Failure.detail] 中不含完整地址和 API Key。
final class TronChainAdapter implements ChainAdapter {
  TronChainAdapter({
    required this.config,
    this.knownDecimals = const {},
    OwHttpClientBuilder? clientBuilder,
    RateLimiter? rateLimiter,
    this.maxPages = 20,
    this.onLog,
  }) : _builder = clientBuilder ?? OwHttpClientFactory.create,
       _limiter =
           rateLimiter ??
           RateLimiter(maxRequests: 3, window: const Duration(seconds: 1));

  /// TronGrid 服务商标识，用于 [DataSourceConfig.apiKey]。
  static const providerId = 'trongrid';

  /// TronGrid 主网。
  static const defaultBaseUrl = 'https://api.trongrid.io';

  /// API Key 的请求头名。
  static const keyHeader = 'TRON-PRO-API-KEY';

  /// 已知 TRC-20 的 decimals（合约 Base58 地址 → 小数位）。
  final Map<String, int> knownDecimals;

  /// TRC-20 余额分页的页数上限（每页 200），防止服务端异常时无限循环。
  final int maxPages;

  /// 用户的数据源配置：TronGrid Key 与自定义节点。
  final DataSourceConfig config;

  /// 传入才记录脱敏日志（见 ow_net）。
  final OwLogSink? onLog;

  final OwHttpClientBuilder _builder;
  final RateLimiter _limiter;
  final Map<String, OwHttpClient> _clients = {};
  final Map<String, Trc20Info> _infoCache = {};

  @override
  ChainFamily get family => ChainFamily.tron;

  @override
  Future<Result<List<RawHolding>>> fetchHoldings(
    String address,
    ChainInfo chain,
  ) async {
    final target = await _resolve(address, chain);
    if (target is Err<_Target>) return Err(target.failure);
    final t = (target as Ok<_Target>).value;

    final acc = await _account(t, address);
    if (acc is Err<(TronAccountBalance, bool)>) return Err(acc.failure);
    final balance = (acc as Ok<(TronAccountBalance, bool)>).value.$1;

    final holdings = <RawHolding>[];
    if (balance.total > BigInt.zero) {
      holdings.add(
        RawHolding(
          token: NativeToken(chain.id),
          amount: scaleAmount(balance.total, chain.nativeDecimals),
          symbolHint: chain.nativeSymbol,
          nameHint: chain.name,
        ),
      );
    }

    // 未激活的地址理论上也可能持有 TRC-20，所以不跳过代币查询。
    final raw = await _trc20Balances(t, address);
    if (raw is Err<Map<String, BigInt>>) return Err(raw.failure);
    final balances = (raw as Ok<Map<String, BigInt>>).value;
    if (balances.isEmpty) return Ok(holdings);

    final infos = await _infos(
      t,
      balances.keys.where((c) => !knownDecimals.containsKey(c)).toList(),
    );
    if (infos is Err<Map<String, Trc20Info>>) return Err(infos.failure);
    final infoMap = (infos as Ok<Map<String, Trc20Info>>).value;

    for (final entry in balances.entries) {
      final known = knownDecimals[entry.key];
      final info = infoMap[entry.key];
      final decimals = known ?? info?.decimals;
      // 查不到 decimals 无法换算，跳过。
      if (decimals == null) continue;
      holdings.add(
        RawHolding(
          token: ContractToken(chain.id, entry.key),
          amount: scaleAmount(entry.value, decimals),
          symbolHint: known == null ? info?.symbol : null,
          nameHint: known == null ? info?.name : null,
        ),
      );
    }
    return Ok(holdings);
  }

  @override
  Future<Result<bool>> hasActivity(String address, ChainInfo chain) async {
    final target = await _resolve(address, chain);
    if (target is Err<_Target>) return Err(target.failure);
    final acc = await _account((target as Ok<_Target>).value, address);
    if (acc is Err<(TronAccountBalance, bool)>) return Err(acc.failure);
    return Ok((acc as Ok<(TronAccountBalance, bool)>).value.$2);
  }

  // ---- 请求 ----

  Future<Result<(TronAccountBalance, bool)>> _account(
    _Target t,
    String address,
  ) async {
    final res = await _get(t, '/v1/accounts/$address');
    if (res is Err<Object?>) return Err(res.failure);
    final parsed = parseTronAccount((res as Ok<Object?>).value);
    if (parsed == null) return const Err(UnknownFailure('账户响应结构无效'));
    return Ok(parsed);
  }

  Future<Result<Map<String, BigInt>>> _trc20Balances(
    _Target t,
    String address,
  ) async {
    final out = <String, BigInt>{};
    String? fingerprint;
    for (var page = 0; page < maxPages; page++) {
      final res = await _get(t, '/v1/accounts/$address/trc20/balance', {
        'limit': 200,
        'fingerprint': ?fingerprint,
      });
      if (res is Err<Object?>) return Err(res.failure);
      final next = parseTrc20Page((res as Ok<Object?>).value, out);
      if (next == null) return const Err(UnknownFailure('TRC-20 余额响应结构无效'));
      if (next.isEmpty) return Ok(out);
      fingerprint = next;
    }
    return const Err(UnknownFailure('TRC-20 分页超过上限'));
  }

  /// 批量查合约信息（每批最多 20 个，带内存缓存）。单批的普通错误
  /// （[UnknownFailure]）只跳过该批；限频、凭据、网络、服务故障整体失败。
  Future<Result<Map<String, Trc20Info>>> _infos(
    _Target t,
    List<String> contracts,
  ) async {
    final out = <String, Trc20Info>{};
    final missing = <String>[];
    for (final c in contracts) {
      final cached = _infoCache[c];
      if (cached != null) {
        out[c] = cached;
      } else {
        missing.add(c);
      }
    }
    for (var i = 0; i < missing.length; i += 20) {
      final batch = missing.skip(i).take(20).toList();
      final res = await _get(t, '/v1/trc20/info', {
        'contract_list': batch.join(','),
      });
      if (res is Err<Object?>) {
        if (res.failure is UnknownFailure || res.failure is ValidationFailure) {
          continue;
        }
        return Err(res.failure);
      }
      final parsed = parseTrc20Info((res as Ok<Object?>).value);
      if (parsed == null) continue;
      _infoCache.addAll(parsed);
      out.addAll(parsed);
    }
    return Ok(out);
  }

  Future<Result<Object?>> _get(
    _Target t,
    String path, [
    Map<String, Object?>? query,
  ]) async {
    final Result<Object?> res;
    try {
      res = await _limiter.run(
        () => _client(t).getJson('${t.prefix}$path', queryParameters: query),
      );
    } on ArgumentError {
      return const Err(ValidationFailure('请求地址无效'));
    }
    if (res is Err<Object?>) return res;
    final body = (res as Ok<Object?>).value;
    // 官方文档：错误体形如 {"success": false, "error": "...", "statusCode": 429}。
    if (body is Map<String, Object?> && body['success'] == false) {
      final status = body['statusCode'];
      final detail = 'TronGrid error statusCode=$status';
      if (status == 429) return Err(RateLimitedFailure(detail));
      if (status == 401 || status == 403) {
        return Err(UnauthorizedFailure(detail));
      }
      if (status is int && status >= 500) {
        return Err(ServiceDownFailure(detail));
      }
      if (status == 400) {
        return Err(ValidationFailure(detail));
      }
      return Err(UnknownFailure(detail));
    }
    return res;
  }

  // ---- 目标解析 ----

  Future<Result<_Target>> _resolve(String address, ChainInfo chain) async {
    if (chain.family != ChainFamily.tron) {
      return Err(
        UnsupportedFailure.notIntegrated('非 Tron 链 chain=${chain.id}'),
      );
    }
    if (!isPathSafeAddress(address)) {
      return const Err(ValidationFailure('地址包含非法字符'));
    }
    final custom = await config.customEndpoint(chain.id);
    if (custom != null) {
      final bad = validateCustomEndpoint(custom, chain.id);
      if (bad != null) return Err(bad);
      return Ok(_Target(custom.origin, trimTrailingSlash(custom.path), null));
    }
    final key = await config.apiKey(providerId);
    return Ok(
      _Target(defaultBaseUrl, '', key == null || key.isEmpty ? null : key),
    );
  }

  OwHttpClient _client(_Target t) => _clients.putIfAbsent(
    '${t.baseUrl}|${t.key ?? ''}',
    () => _builder(
      OwHttpConfig(
        baseUrl: t.baseUrl,
        defaultHeaders: {'Accept': 'application/json', keyHeader: ?t.key},
        onLog: onLog,
      ),
    ),
  );
}

final class _Target {
  const _Target(this.baseUrl, this.prefix, this.key);
  final String baseUrl;

  /// 自定义节点的路径前缀，默认为空。
  final String prefix;

  /// 只在默认 TronGrid 主机上使用。
  final String? key;
}
