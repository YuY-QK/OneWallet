import 'package:decimal/decimal.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:ow_net/ow_net.dart';

import '../common/clock_sync.dart';
import '../common/exchange_client.dart';
import '../common/holdings.dart';
import '../common/response_judges.dart';
import '../common/signing.dart';
import 'bybit_paths.dart';

/// Bybit 的只读接入（M2-08）。接口细节与核对记录见 docs/EXTERNAL_APIS.md 的
/// "Bybit" 一节。**只调用查询类接口**；路径全部登记在 [bybitReadOnlyPaths]。
///
/// 子账户对应：
/// - 统一交易账户（UNIFIED）-> [ExchangeSubAccount.spot]，数量 = `walletBalance - spotBorrow`；
///   合约仓位与未实现盈亏不另行拆出（同一币种余额池）；
/// - 资金账户（FUND）-> funding，数量 = `walletBalance`；
/// - 灵活储蓄、链上赚币、定期理财 -> earn，数量 = 持仓 `amount`。
///
/// 统一账户与资金账户失败则整体失败。理财接口若返回鉴权类失败
/// （[UnauthorizedFailure]，如 10005 权限不足），视为空，并把产品名记入 [lastSkipped]；
/// 限频、网络、5xx、时间偏差校正后仍失败等其他失败仍使整体失败。
final class BybitAdapter implements ExchangeAdapter {
  BybitAdapter({
    required this.clock,
    ExchangeHttpClientBuilder? clientBuilder,
    RateLimiter? rateLimiter,
    this.host = 'https://api.bybit.com',
    this.onLog,
  }) : _builder = clientBuilder ?? OwHttpClientFactory.create,
       // Bybit 的限额按 UID 每秒计：查询资金余额为 5 次/秒，是本适配器最严的接口；
       // 取其一半并向下取整为每秒 2 次，所有接口共用这一个限速器。
       _limiter =
           rateLimiter ??
           RateLimiter(maxRequests: 2, window: const Duration(seconds: 1));

  /// 时间来源（注入）。请求时间戳 = 它 + 校正偏移。
  final Clock clock;

  /// REST 主机。默认是主站 `api.bybit.com`；其他地区的域名（如 `api.bybit.eu`）本版本未提供切换。
  final String host;
  final OwLogSink? onLog;

  /// 请求接收窗口（毫秒），与官方默认值一致。
  static const _recvWindowMs = 5000;

  /// 界面 P08 显示"未包含"的产品。
  static const notIncluded = <String>[
    '双币理财（Dual Asset）',
    '借贷（借币与质押借贷）',
    'Launchpool 与 Spot-X 项目',
    'Bybit 卡与 RWA 等其他理财产品',
    '子账户（只读取本 Key 所属账户的余额）',
  ];

  /// 理财产品名称：Key 无权访问或未开通时跳过，供 [lastSkipped] 使用。
  static const _flexibleName = '灵活储蓄与链上赚币';
  static const _fixedName = '定期理财';

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
  ExchangeId get id => ExchangeId.bybit;

  @override
  bool get needsPassphrase => false;

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
    judge: judgeBybit,
  );

  /// 服务器时间取 `result.timeNano`（纳秒），换算为毫秒。
  Future<Result<int>> _fetchServerTime() async {
    final r = await _http.unsigned(
      const ExchangeCall(method: 'GET', path: BybitPaths.serverTime),
    );
    return switch (r) {
      Err<Object?>(:final failure) => Err(failure),
      Ok<Object?>(:final value) => () {
        final nano = value is Map<String, Object?>
            ? parseAmount(value['timeNano'])
            : null;
        return nano == null
            ? const Err<int>(UnknownFailure('Bybit 服务器时间无效'))
            : Ok<int>((nano.toBigInt() ~/ BigInt.from(1000000)).toInt());
      }(),
    };
  }

  /// 构造一次带签名的 GET 请求。签名串 = 时间戳 + API Key + 接收窗口 + 查询串。
  /// 查询串由 [buildQuery] 生成，签名与发送共用同一份字符串。
  CallBuilder _signed(
    String path,
    ExchangeCredentials c, [
    Map<String, String> params = const {},
  ]) => (timestampMs) {
    final query = buildQuery(params);
    final signature = bybitSignature(
      apiKey: c.apiKey,
      secret: c.apiSecret,
      timestampMs: timestampMs,
      recvWindowMs: _recvWindowMs,
      payload: query,
    );
    return ExchangeCall(
      method: 'GET',
      path: path,
      query: query,
      headers: {
        bybitKeyHeader: headerValue(c.apiKey),
        bybitSignHeader: signature,
        bybitTimestampHeader: '$timestampMs',
        bybitRecvWindowHeader: '$_recvWindowMs',
      },
    );
  };

  // ------------------------------------------------------------- 权限

  @override
  Future<Result<CredentialCheck>> verify(ExchangeCredentials c) async {
    final r = await _http.signed(_signed(BybitPaths.apiKeyInfo, c));
    return switch (r) {
      Err<Object?>(:final failure) => Err(failure),
      Ok<Object?>(:final value) when value is Map<String, Object?> => Ok(
        CredentialCheck(permission: permissionFrom(value)),
      ),
      Ok<Object?>() => const Err(UnknownFailure('Bybit 权限返回值无效')),
    };
  }

  /// 由 `query-api` 的结果判断权限：
  /// 能提现（`permissions.Wallet` 含 `Withdraw`）优先；否则 `readOnly` 为 0（读写）
  /// 视为能交易；`readOnly` 为 1 视为只读；其余或字段缺失返回 unknown。
  static KeyPermission permissionFrom(Map<String, Object?> result) {
    final perms = result['permissions'];
    if (perms is Map<String, Object?>) {
      final wallet = perms['Wallet'];
      if (wallet is List<Object?> && wallet.contains('Withdraw')) {
        return KeyPermission.canWithdraw;
      }
    }
    final readOnly = parseAmount(result['readOnly']);
    if (readOnly == Decimal.zero) return KeyPermission.canTrade;
    if (readOnly == Decimal.one) return KeyPermission.readOnly;
    return KeyPermission.unknown;
  }

  // ------------------------------------------------------------- 余额

  @override
  Future<Result<List<(ExchangeSubAccount, RawHolding)>>> fetchHoldings(
    ExchangeCredentials c,
  ) async {
    final acc = HoldingsAccumulator(ExchangeId.bybit);

    final skipped = <String>{};
    _lastSkipped = const [];

    // 鉴权类失败时跳过该产品并记录；调用时统一账户已成功，凭据本身有效。
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
    // 统一账户在最前：它成功才能证明凭据有效。
    final steps = <Future<Failure?> Function()>[
      () => _unifiedBalances(c, acc),
      () => _fundBalances(c, acc),
      optional(_flexibleName, () => _flexibleAndOnChain(c, acc)),
      optional(_fixedName, () => _fixedTerm(c, acc)),
    ];
    for (final step in steps) {
      final failure = await step();
      if (failure != null) return Err(failure);
    }
    _lastSkipped = skipped.toList();
    return Ok(acc.build());
  }

  /// 统一账户：每个币种 `walletBalance - spotBorrow`。
  /// `walletBalance` 按文档的权益公式（`equity = walletBalance - spotBorrow + ...`）
  /// 含挂单占用的部分（`locked`），所以不再另加 `locked`。合约未实现盈亏不计入。
  Future<Failure?> _unifiedBalances(
    ExchangeCredentials c,
    HoldingsAccumulator acc,
  ) async {
    final r = await _http.signed(
      _signed(BybitPaths.walletBalance, c, {'accountType': 'UNIFIED'}),
    );
    if (r is Err<Object?>) return r.failure;
    final body = (r as Ok<Object?>).value;
    final list = body is Map<String, Object?> ? body['list'] : null;
    if (list is! List<Object?>) return const UnknownFailure('统一账户格式无效');
    for (final account in list) {
      if (account is! Map<String, Object?>) continue;
      final coins = account['coin'];
      if (coins is! List<Object?>) continue;
      for (final row in coins) {
        if (row is! Map<String, Object?>) continue;
        final symbol = row['coin'];
        if (symbol is! String) continue;
        final wallet = amountOrZero(row['walletBalance']);
        final borrow = amountOrZero(row['spotBorrow']);
        if (wallet == null || borrow == null) {
          return const UnknownFailure('金额格式无效');
        }
        acc.add(ExchangeSubAccount.spot, symbol, wallet - borrow);
      }
    }
    return null;
  }

  /// 资金账户：数量取 `walletBalance`（总量；`transferBalance` 是其中可划转的部分，不另加）。
  /// 不请求 `withBonus`，奖励金不计入。
  Future<Failure?> _fundBalances(
    ExchangeCredentials c,
    HoldingsAccumulator acc,
  ) async {
    final r = await _http.signed(
      _signed(BybitPaths.fundBalance, c, {'accountType': 'FUND'}),
    );
    if (r is Err<Object?>) return r.failure;
    final body = (r as Ok<Object?>).value;
    final rows = body is Map<String, Object?> ? body['balance'] : null;
    if (rows is! List<Object?>) return const UnknownFailure('资金账户格式无效');
    return _addRows(acc, ExchangeSubAccount.funding, rows, 'coin', const [
      'walletBalance',
    ]);
  }

  /// 灵活储蓄与链上赚币：两次请求，分别取 `amount`。
  Future<Failure?> _flexibleAndOnChain(
    ExchangeCredentials c,
    HoldingsAccumulator acc,
  ) async {
    for (final category in const ['FlexibleSaving', 'OnChain']) {
      final failure = await _earnList(c, acc, BybitPaths.earnPosition, {
        'category': category,
      });
      if (failure != null) return failure;
    }
    return null;
  }

  /// 定期理财。
  Future<Failure?> _fixedTerm(ExchangeCredentials c, HoldingsAccumulator acc) =>
      _earnList(c, acc, BybitPaths.fixedTermPosition, const {});

  Future<Failure?> _earnList(
    ExchangeCredentials c,
    HoldingsAccumulator acc,
    String path,
    Map<String, String> params,
  ) async {
    final r = await _http.signed(_signed(path, c, params));
    if (r is Err<Object?>) return r.failure;
    final body = (r as Ok<Object?>).value;
    final rows = body is Map<String, Object?> ? body['list'] : null;
    if (rows is! List<Object?>) return const UnknownFailure('理财持仓格式无效');
    return _addRows(acc, ExchangeSubAccount.earn, rows, 'coin', const [
      'amount',
    ]);
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

  /// 返回空列表。Bybit 的充值地址接口按币种与链分别查询，且文档未说明地址不存在时
  /// 是否会新建；"只读、不新建"的约束下不调用。详见 docs/EXTERNAL_APIS.md。
  @override
  Future<Result<List<DepositAddress>>> fetchDepositAddresses(
    ExchangeCredentials c,
  ) async => const Ok([]);
}
