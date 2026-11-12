import 'package:decimal/decimal.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:ow_net/ow_net.dart';

import '../common/clock_sync.dart';
import '../common/exchange_client.dart';
import '../common/holdings.dart';
import '../common/response_judges.dart';
import '../common/signing.dart';
import 'okx_paths.dart';

/// OKX 的只读接入（M2-07）。接口细节与核对记录见 docs/EXTERNAL_APIS.md 的
/// "OKX" 一节。**只调用查询类接口**；路径全部登记在 [okxReadOnlyPaths]。
///
/// 子账户对应：
/// - 交易账户（统一账户，含合约保证金）-> [ExchangeSubAccount.spot]；
/// - 资金账户 -> funding；
/// - 余币宝与链上赚币（进行中订单的本金）-> earn。
///
/// 交易账户与资金账户失败则整体失败。理财两个接口若返回鉴权类失败
/// （[UnauthorizedFailure]，表示 Key 无权访问或未开通），视为空，并把产品名记入
/// [lastSkipped]；限频、网络、5xx、时间偏差校正后仍失败等其他失败仍使整体失败。
///
/// OKX 的 Key 同时需要 Passphrase；没有 Passphrase 的凭据直接返回
/// [UnauthorizedFailure]，不发请求。
final class OkxAdapter implements ExchangeAdapter {
  OkxAdapter({
    required this.clock,
    ExchangeHttpClientBuilder? clientBuilder,
    RateLimiter? rateLimiter,
    this.host = 'https://openapi.okx.com',
    this.onLog,
  }) : _builder = clientBuilder ?? OwHttpClientFactory.create,
       // OKX 的限额按接口分别计算：account/config 为每 2 秒 5 次，是最严的一个；
       // 取其一半并向下取整为每 2 秒 2 次，所有接口共用这一个限速器。
       _limiter =
           rateLimiter ??
           RateLimiter(maxRequests: 2, window: const Duration(seconds: 2));

  /// 时间来源（注入）。请求时间戳 = 它 + 校正偏移。
  final Clock clock;

  /// REST 主机。默认是全球站 `openapi.okx.com`；美区、欧区用户须改用其他域名，
  /// 本版本未提供切换（见 docs/EXTERNAL_APIS.md）。
  final String host;
  final OwLogSink? onLog;

  /// 界面 P08 显示"未包含"的产品。
  static const notIncluded = <String>[
    '策略交易（网格与机器人）',
    '跟单交易',
    '双币投资',
    '灵活借贷（借币与抵押）',
    'USDG 稳定收益与 OKUSD（余额与交易、资金账户是否重复计入未能核对）',
    '期权',
    '子账户（只读取本 Key 所属账户的余额）',
  ];

  /// 产品名称：Key 无权访问时跳过的理财产品，供 [lastSkipped] 使用。
  static const _savingsName = '余币宝';
  static const _stakingName = '链上赚币';

  List<String> _lastSkipped = const [];

  /// 上一次 [fetchHoldings] 中因 Key 无权限或未开通而被跳过的产品中文名，
  /// 按首次跳过的顺序、不重复。P08 据此显示"未包含：…"，与静态的 [notIncluded] 合并展示。
  /// 每次调用 [fetchHoldings] 开始时清空；调用失败时内容无意义。
  List<String> get lastSkipped => List.unmodifiable(_lastSkipped);

  final ExchangeHttpClientBuilder _builder;
  final RateLimiter _limiter;

  ClockSync? _sync;
  ExchangeClient? _client;

  @override
  ExchangeId get id => ExchangeId.okx;

  @override
  bool get needsPassphrase => true;

  ClockSync get _clockSync =>
      _sync ??= ClockSync(clock: clock, fetchServerTime: _fetchServerTime);

  ExchangeClient get _http => _client ??= ExchangeClient(
    http: _builder(
      OwHttpConfig(
        baseUrl: host,
        extraSensitiveNames: exchangeSensitiveHeaderNames,
        onLog: onLog,
      ),
    ),
    limiter: _limiter,
    clock: _clockSync,
    judge: judgeOkx,
  );

  Future<Result<int>> _fetchServerTime() async {
    final r = await _http.unsigned(
      const ExchangeCall(method: 'GET', path: OkxPaths.publicTime),
    );
    return switch (r) {
      Err<Object?>(:final failure) => Err(failure),
      Ok<Object?>(:final value) => () {
        final row = value is List<Object?> && value.isNotEmpty
            ? value.first
            : null;
        final ts = row is Map<String, Object?> ? parseAmount(row['ts']) : null;
        return ts == null
            ? const Err<int>(UnknownFailure('OKX 服务器时间无效'))
            : Ok<int>(ts.toBigInt().toInt());
      }(),
    };
  }

  /// 构造一次带签名的请求。签名串 = 时间戳 + 方法 + 请求路径（含查询串）+ 空请求体。
  /// 时间戳为 ISO 8601（毫秒），由注入的时钟（含校正）生成。
  CallBuilder _signed(
    String method,
    String path,
    ExchangeCredentials c,
    Sensitive passphrase,
  ) => (timestampMs) {
    final timestamp = okxTimestamp(
      DateTime.fromMillisecondsSinceEpoch(timestampMs, isUtc: true),
    );
    final preHash = okxPreHash(
      timestamp: timestamp,
      method: method,
      requestPath: path,
    );
    return ExchangeCall(
      method: method,
      path: path,
      headers: {
        okxKeyHeader: headerValue(c.apiKey),
        okxSignHeader: okxSignature(secret: c.apiSecret, preHash: preHash),
        okxTimestampHeader: timestamp,
        okxPassphraseHeader: headerValue(passphrase),
      },
    );
  };

  // ------------------------------------------------------------- 权限

  @override
  Future<Result<CredentialCheck>> verify(ExchangeCredentials c) async {
    final passphrase = c.passphrase;
    if (passphrase == null) {
      return const Err(UnauthorizedFailure('缺少 Passphrase'));
    }
    final r = await _http.signed(
      _signed('GET', OkxPaths.accountConfig, c, passphrase),
    );
    return switch (r) {
      Err<Object?>(:final failure) => Err(failure),
      Ok<Object?>(:final value) => Ok(
        CredentialCheck(permission: permissionFrom(_firstRow(value)?['perm'])),
      ),
    };
  }

  /// 把 `perm`（如 `read_only,trade,withdraw`）映射为 [KeyPermission]。
  /// 能提现优先于能交易；字段缺失或无法识别时返回 [KeyPermission.unknown]。
  static KeyPermission permissionFrom(Object? perm) {
    if (perm is! String) return KeyPermission.unknown;
    final tokens = {for (final t in perm.split(',')) t.trim()};
    if (tokens.contains('withdraw')) return KeyPermission.canWithdraw;
    if (tokens.contains('trade')) return KeyPermission.canTrade;
    if (tokens.contains('read_only')) return KeyPermission.readOnly;
    return KeyPermission.unknown;
  }

  /// `data` 的第一行（OKX 的单对象响应也是列表）；不是列表或为空返回 null。
  static Map<String, Object?>? _firstRow(Object? data) {
    if (data is! List<Object?> || data.isEmpty) return null;
    final row = data.first;
    return row is Map<String, Object?> ? row : null;
  }

  // ------------------------------------------------------------- 余额

  @override
  Future<Result<List<(ExchangeSubAccount, RawHolding)>>> fetchHoldings(
    ExchangeCredentials c,
  ) async {
    final passphrase = c.passphrase;
    if (passphrase == null) {
      return const Err(UnauthorizedFailure('缺少 Passphrase'));
    }
    final acc = HoldingsAccumulator(ExchangeId.okx);

    final skipped = <String>{};
    _lastSkipped = const [];

    // 鉴权类失败时跳过该产品并记录；调用时交易账户已成功，凭据本身有效。
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

    // 每个步骤返回 null 表示成功，否则是失败；必需步骤失败则整体失败。
    // 交易账户在最前：它成功才能证明凭据有效。
    final steps = <Future<Failure?> Function()>[
      () => _tradingBalances(c, passphrase, acc),
      () => _fundingBalances(c, passphrase, acc),
      optional(_savingsName, () => _savings(c, passphrase, acc)),
      optional(_stakingName, () => _staking(c, passphrase, acc)),
    ];
    for (final step in steps) {
      final failure = await step();
      if (failure != null) return Err(failure);
    }
    _lastSkipped = skipped.toList();
    return Ok(acc.build());
  }

  /// 统一账户的各币种：`details[]` 中的 `availBal + frozenBal`（可用 + 冻结）。
  /// 合约保证金与未实现盈亏不并入这里（以币种可用与冻结为准，不用 `eq`，
  /// 因为 `eq` 含合约浮动盈亏）。
  Future<Failure?> _tradingBalances(
    ExchangeCredentials c,
    Sensitive passphrase,
    HoldingsAccumulator acc,
  ) async {
    final r = await _http.signed(
      _signed('GET', OkxPaths.accountBalance, c, passphrase),
    );
    if (r is Err<Object?>) return r.failure;
    final data = (r as Ok<Object?>).value;
    if (data is! List<Object?>) return const UnknownFailure('交易账户余额格式无效');
    final details = <Object?>[];
    for (final account in data) {
      if (account is! Map<String, Object?>) continue;
      final d = account['details'];
      if (d is List<Object?>) details.addAll(d);
    }
    return _addRows(acc, ExchangeSubAccount.spot, details, 'ccy', const [
      'availBal',
      'frozenBal',
    ]);
  }

  /// 资金账户：`availBal + frozenBal`。接口只返回余额大于 0 的币种。
  Future<Failure?> _fundingBalances(
    ExchangeCredentials c,
    Sensitive passphrase,
    HoldingsAccumulator acc,
  ) async {
    final r = await _http.signed(
      _signed('GET', OkxPaths.fundingBalances, c, passphrase),
    );
    if (r is Err<Object?>) return r.failure;
    final rows = (r as Ok<Object?>).value;
    if (rows is! List<Object?>) return const UnknownFailure('资金账户格式无效');
    return _addRows(acc, ExchangeSubAccount.funding, rows, 'ccy', const [
      'availBal',
      'frozenBal',
    ]);
  }

  /// 余币宝：`amt` 为该币种的持有金额（文档中 `amt = loanAmt + pendingAmt`）。
  Future<Failure?> _savings(
    ExchangeCredentials c,
    Sensitive passphrase,
    HoldingsAccumulator acc,
  ) async {
    final r = await _http.signed(
      _signed('GET', OkxPaths.savingsBalance, c, passphrase),
    );
    if (r is Err<Object?>) return r.failure;
    final rows = (r as Ok<Object?>).value;
    if (rows is! List<Object?>) return const UnknownFailure('余币宝格式无效');
    return _addRows(acc, ExchangeSubAccount.earn, rows, 'ccy', const ['amt']);
  }

  /// 链上赚币：进行中订单的 `investData[]`（投入本金的币种与数量）。
  /// 不计 `earningData` 中的收益，收益未计入总量（见 docs/EXTERNAL_APIS.md）。
  Future<Failure?> _staking(
    ExchangeCredentials c,
    Sensitive passphrase,
    HoldingsAccumulator acc,
  ) async {
    final r = await _http.signed(
      _signed('GET', OkxPaths.stakingActiveOrders, c, passphrase),
    );
    if (r is Err<Object?>) return r.failure;
    final orders = (r as Ok<Object?>).value;
    if (orders is! List<Object?>) return const UnknownFailure('链上赚币格式无效');
    for (final order in orders) {
      if (order is! Map<String, Object?>) continue;
      final invest = order['investData'];
      if (invest is! List<Object?>) continue;
      final failure = _addRows(
        acc,
        ExchangeSubAccount.earn,
        invest,
        'ccy',
        const ['amt'],
      );
      if (failure != null) return failure;
    }
    return null;
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

  /// 返回空列表。OKX 的充值地址接口 `GET /api/v5/asset/deposit-address` 每次只查一个
  /// 币种，且文档未说明该币种尚无地址时是否会新建；"只读、不新建"的约束下不调用。
  /// 详见 docs/EXTERNAL_APIS.md。
  @override
  Future<Result<List<DepositAddress>>> fetchDepositAddresses(
    ExchangeCredentials c,
  ) async => const Ok([]);
}
