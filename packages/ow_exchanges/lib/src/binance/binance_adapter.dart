import 'package:decimal/decimal.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:ow_net/ow_net.dart';

import '../common/clock_sync.dart';
import '../common/exchange_client.dart';
import '../common/holdings.dart';
import '../common/response_judges.dart';
import '../common/signing.dart';
import 'binance_paths.dart';

/// Binance 的只读接入（M2-06）。接口细节与核对记录见 docs/EXTERNAL_APIS.md 的
/// "Binance" 一节。**只调用查询类接口**；路径全部登记在 [binanceReadOnlyPaths]。
///
/// 子账户对应：
/// - 现货 -> [ExchangeSubAccount.spot]；资金账户 -> funding；
/// - U 本位与币本位合约（账户权益）-> futures；全仓与逐仓杠杆（净资产）-> margin；
/// - 简单理财活期与定期 -> earn。
///
/// 杠杆与合约账户总是先尝试读取，不看 `apiRestrictions` 的开关（很多只读 Key
/// 也能读）。现货请求已成功（证明凭据有效）后，若这些接口返回鉴权类失败
/// （[UnauthorizedFailure]：-2015、HTTP 401 等，表示 Key 无权访问该产品），
/// 该子账户视为空，不让整体失败，并把产品名记入 [lastSkipped]。
/// 限频、网络、5xx、时间偏差校正后仍失败等其他失败仍使整体失败。
final class BinanceAdapter implements ExchangeAdapter {
  BinanceAdapter({
    required this.clock,
    ExchangeHttpClientBuilder? clientBuilder,
    RateLimiter? rateLimiter,
    this.spotHost = 'https://api.binance.com',
    this.usdmHost = 'https://fapi.binance.com',
    this.coinmHost = 'https://dapi.binance.com',
    this.onLog,
  }) : _builder = clientBuilder ?? OwHttpClientFactory.create,
       // 官方现货 IP 限额 6000 权重/分钟；理财持仓接口每次 150 权重。
       // 取保守一半：每分钟最多 20 次请求（最坏 3000 权重）。
       _limiter =
           rateLimiter ??
           RateLimiter(maxRequests: 20, window: const Duration(minutes: 1));

  /// 时间来源（注入）。请求时间戳 = 它 + 校正偏移。
  final Clock clock;

  /// 界面 P08 显示"未包含"的产品。
  static const notIncluded = <String>[
    '币安质押（ETH、SOL 等）',
    '自动投资',
    '双币投资',
    'Launchpool 与 Megadrop',
    '币安借贷（质押借币）',
    '期权',
    '组合保证金账户',
    '交易机器人',
    '跟单交易',
  ];

  List<String> _lastSkipped = const [];

  /// 上一次 [fetchHoldings] 中因 Key 无权限而被跳过的产品中文名（如"合约账户""杠杆账户"），
  /// 按首次跳过的顺序、不重复。P08 据此显示"未包含：…"，与静态的 [notIncluded] 合并展示。
  /// 每次调用 [fetchHoldings] 开始时清空；调用失败时内容无意义。
  List<String> get lastSkipped => List.unmodifiable(_lastSkipped);

  static const _recvWindow = '5000';
  static const _pageSize = 100;
  static const _maxPages = 50;

  /// 三个 API 主机，默认官方主机；测试可改。
  final String spotHost;
  final String usdmHost;
  final String coinmHost;
  final OwLogSink? onLog;

  final ExchangeHttpClientBuilder _builder;
  final RateLimiter _limiter;

  ExchangeClient? _spot;
  ExchangeClient? _usdm;
  ExchangeClient? _coinm;

  @override
  ExchangeId get id => ExchangeId.binance;

  @override
  bool get needsPassphrase => false;

  ExchangeClient _client(String host) {
    // 三个主机共用限速器与时间偏移；时间校正统一向现货主机取。
    final sync = _sync ??= ClockSync(
      clock: clock,
      fetchServerTime: _fetchServerTime,
    );
    return ExchangeClient(
      http: _builder(
        OwHttpConfig(
          baseUrl: host,
          extraSensitiveNames: exchangeSensitiveHeaderNames,
          onLog: onLog,
        ),
      ),
      limiter: _limiter,
      clock: sync,
      judge: judgeBinance,
    );
  }

  ClockSync? _sync;

  ExchangeClient get _spotClient => _spot ??= _client(spotHost);
  ExchangeClient get _usdmClient => _usdm ??= _client(usdmHost);
  ExchangeClient get _coinmClient => _coinm ??= _client(coinmHost);

  Future<Result<int>> _fetchServerTime() async {
    final r = await _spotClient.unsigned(
      const ExchangeCall(method: 'GET', path: BinancePaths.serverTime),
    );
    return switch (r) {
      Err<Object?>(:final failure) => Err(failure),
      Ok<Object?>(:final value) => () {
        final t = value is Map<String, Object?>
            ? parseAmount(value['serverTime'])
            : null;
        return t == null
            ? const Err<int>(UnknownFailure('serverTime 无效'))
            : Ok<int>(t.toBigInt().toInt());
      }(),
    };
  }

  /// 构造一次带签名的请求：参数 + recvWindow + timestamp，再追加 signature。
  CallBuilder _signed(
    String method,
    String path,
    ExchangeCredentials c, {
    Map<String, String> params = const {},
    Set<String> emptyCodes = const {},
  }) => (timestampMs) {
    final query = buildQuery({
      ...params,
      'recvWindow': _recvWindow,
      'timestamp': '$timestampMs',
    });
    final signature = binanceSignature(secret: c.apiSecret, payload: query);
    return ExchangeCall(
      method: method,
      path: path,
      query: '$query&signature=$signature',
      headers: {binanceKeyHeader: headerValue(c.apiKey)},
      emptyCodes: emptyCodes,
    );
  };

  // ------------------------------------------------------------- 权限

  Future<Result<_Restrictions>> _restrictions(ExchangeCredentials c) async {
    final r = await _spotClient.signed(
      _signed('GET', BinancePaths.apiRestrictions, c),
    );
    return switch (r) {
      Err<Object?>(:final failure) => Err(failure),
      Ok<Object?>(:final value) when value is Map<String, Object?> => Ok(
        _Restrictions(value),
      ),
      Ok<Object?>() => const Err(UnknownFailure('apiRestrictions 返回值无效')),
    };
  }

  @override
  Future<Result<CredentialCheck>> verify(ExchangeCredentials c) async {
    final r = await _restrictions(c);
    return r.map((x) => CredentialCheck(permission: x.permission));
  }

  // ------------------------------------------------------------- 余额

  @override
  Future<Result<List<(ExchangeSubAccount, RawHolding)>>> fetchHoldings(
    ExchangeCredentials c,
  ) async {
    final acc = HoldingsAccumulator(ExchangeId.binance);

    final skipped = <String>{};
    _lastSkipped = const [];

    // 鉴权类失败时跳过该产品并记录；调用时现货已成功，凭据本身有效。
    Future<Failure?> Function() optional(
      String name,
      Future<Failure?> Function() step,
    ) => () async {
      final failure = await step();
      if (failure is UnauthorizedFailure) {
        skipped.add(name);
        return null;
      }
      return failure;
    };

    // 每个步骤返回 null 表示成功，否则是失败；任何一步失败整体失败。
    // 现货在最前：它成功才能证明凭据有效。
    final steps = <Future<Failure?> Function()>[
      () => _spotBalances(c, acc),
      () => _fundingBalances(c, acc),
      optional('杠杆账户', () => _crossMargin(c, acc)),
      optional('杠杆账户', () => _isolatedMargin(c, acc)),
      optional(
        '合约账户',
        () => _futures(_usdmClient, BinancePaths.usdmBalance, c, acc),
      ),
      optional(
        '合约账户',
        () => _futures(_coinmClient, BinancePaths.coinmBalance, c, acc),
      ),
      () => _earn(c, BinancePaths.flexiblePosition, 'totalAmount', acc),
      () => _earn(c, BinancePaths.lockedPosition, 'amount', acc),
    ];
    for (final step in steps) {
      final failure = await step();
      if (failure != null) return Err(failure);
    }
    _lastSkipped = skipped.toList();
    return Ok(acc.build());
  }

  Future<Failure?> _spotBalances(
    ExchangeCredentials c,
    HoldingsAccumulator acc,
  ) async {
    final r = await _spotClient.signed(
      _signed('GET', BinancePaths.spotAccount, c),
    );
    if (r is Err<Object?>) return r.failure;
    final body = (r as Ok<Object?>).value;
    final balances = body is Map<String, Object?> ? body['balances'] : null;
    if (balances is! List<Object?>) return const UnknownFailure('现货余额格式无效');
    // 总量 = 可用 + 冻结（挂单占用）。
    return _addRows(acc, ExchangeSubAccount.spot, balances, 'asset', const [
      'free',
      'locked',
    ]);
  }

  Future<Failure?> _fundingBalances(
    ExchangeCredentials c,
    HoldingsAccumulator acc,
  ) async {
    final r = await _spotClient.signed(
      _signed('POST', BinancePaths.fundingAssets, c),
    );
    if (r is Err<Object?>) return r.failure;
    final body = (r as Ok<Object?>).value;
    if (body is! List<Object?>) return const UnknownFailure('资金账户格式无效');
    return _addRows(acc, ExchangeSubAccount.funding, body, 'asset', const [
      'free',
      'locked',
      'freeze',
      'withdrawing',
    ]);
  }

  /// 全仓杠杆：净资产 `netAsset`（可用 + 冻结 - 借款 - 利息）。
  /// `-3003` 表示未开通杠杆账户（官方 SAPI 错误码表未能核对，见 EXTERNAL_APIS）。
  Future<Failure?> _crossMargin(
    ExchangeCredentials c,
    HoldingsAccumulator acc,
  ) async {
    final r = await _spotClient.signed(
      _signed('GET', BinancePaths.crossMargin, c, emptyCodes: {'-3003'}),
    );
    if (r is Err<Object?>) return r.failure;
    final body = (r as Ok<Object?>).value;
    if (body == null) return null;
    final assets = body is Map<String, Object?> ? body['userAssets'] : null;
    if (assets is! List<Object?>) return const UnknownFailure('全仓杠杆格式无效');
    return _addRows(acc, ExchangeSubAccount.margin, assets, 'asset', const [
      'netAsset',
    ]);
  }

  Future<Failure?> _isolatedMargin(
    ExchangeCredentials c,
    HoldingsAccumulator acc,
  ) async {
    final r = await _spotClient.signed(
      _signed('GET', BinancePaths.isolatedMargin, c, emptyCodes: {'-3003'}),
    );
    if (r is Err<Object?>) return r.failure;
    final body = (r as Ok<Object?>).value;
    if (body == null) return null;
    final pairs = body is Map<String, Object?> ? body['assets'] : null;
    if (pairs is! List<Object?>) return const UnknownFailure('逐仓杠杆格式无效');
    for (final pair in pairs) {
      if (pair is! Map<String, Object?>) continue;
      for (final side in const ['baseAsset', 'quoteAsset']) {
        final leg = pair[side];
        if (leg is! Map<String, Object?>) continue;
        final failure = _addRows(
          acc,
          ExchangeSubAccount.margin,
          [leg],
          'asset',
          const ['netAsset'],
        );
        if (failure != null) return failure;
      }
    }
    return null;
  }

  /// 合约账户权益 = 钱包余额 `balance` + 全仓未实现盈亏 `crossUnPnl`，
  /// 以结算币种计，不展开持仓（R12）。
  Future<Failure?> _futures(
    ExchangeClient client,
    String path,
    ExchangeCredentials c,
    HoldingsAccumulator acc,
  ) async {
    final r = await client.signed(_signed('GET', path, c));
    if (r is Err<Object?>) return r.failure;
    final body = (r as Ok<Object?>).value;
    if (body is! List<Object?>) return const UnknownFailure('合约余额格式无效');
    return _addRows(acc, ExchangeSubAccount.futures, body, 'asset', const [
      'balance',
      'crossUnPnl',
    ]);
  }

  /// 理财持仓，分页读到最后一页。
  Future<Failure?> _earn(
    ExchangeCredentials c,
    String path,
    String amountField,
    HoldingsAccumulator acc,
  ) async {
    for (var page = 1; page <= _maxPages; page++) {
      final r = await _spotClient.signed(
        _signed(
          'GET',
          path,
          c,
          params: {'current': '$page', 'size': '$_pageSize'},
        ),
      );
      if (r is Err<Object?>) return r.failure;
      final body = (r as Ok<Object?>).value;
      final rows = body is Map<String, Object?> ? body['rows'] : null;
      if (rows is! List<Object?>) return const UnknownFailure('理财持仓格式无效');
      final failure = _addRows(acc, ExchangeSubAccount.earn, rows, 'asset', [
        amountField,
      ]);
      if (failure != null) return failure;
      if (rows.length < _pageSize) return null;
    }
    // 页数超过上限仍未读完：宁可失败也不少算。
    return const UnknownFailure('理财持仓分页超过上限');
  }

  /// 把 [rows] 中每一行的 [fields] 求和后记入 [sub]。数字无法解析视为格式错误。
  Failure? _addRows(
    HoldingsAccumulator acc,
    ExchangeSubAccount sub,
    List<Object?> rows,
    String symbolField,
    List<String> fields,
  ) {
    for (final row in rows) {
      if (row is! Map<String, Object?>) continue;
      final symbol = row[symbolField];
      if (symbol is! String) continue;
      var total = Decimal.zero;
      for (final f in fields) {
        final v = amountOrZero(row[f]);
        if (v == null) return const UnknownFailure('金额格式无效');
        total += v;
      }
      acc.add(sub, symbol, total);
    }
    return null;
  }

  // ------------------------------------------------------------- 充值地址

  /// 返回空列表。Binance 的充值地址接口按币种、按网络逐个查询，响应里不带网络名，
  /// 且文档未说明地址不存在时是否会新建；"只读、不新建"的约束下不调用。
  /// 详见 docs/EXTERNAL_APIS.md。
  @override
  Future<Result<List<DepositAddress>>> fetchDepositAddresses(
    ExchangeCredentials c,
  ) async => const Ok([]);
}

/// `apiRestrictions` 的返回，只保留用到的开关。
final class _Restrictions {
  _Restrictions(Map<String, Object?> json)
    : enableWithdrawals = json['enableWithdrawals'] == true,
      _writes = [
        json['enableSpotAndMarginTrading'],
        json['enableMargin'],
        json['enableFutures'],
        json['enableVanillaOptions'],
        json['enablePortfolioMarginTrading'],
        json['enableInternalTransfer'],
        json['permitsUniversalTransfer'],
      ];

  final bool enableWithdrawals;
  final List<Object?> _writes;

  /// 能提现优先于能交易；其余任何写类权限都算带交易权限。
  KeyPermission get permission {
    if (enableWithdrawals) return KeyPermission.canWithdraw;
    if (_writes.any((v) => v == true)) return KeyPermission.canTrade;
    return KeyPermission.readOnly;
  }
}
