import 'package:dio/dio.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:ow_net/ow_net.dart';

import 'clock_sync.dart';
import 'error_mapping.dart';
import 'exact_json.dart';
import 'response_judges.dart';

/// 创建 HTTP 客户端的函数。生产代码用默认的 [OwHttpClientFactory.create]，
/// 测试注入带假适配器的实现，不访问真实网络。
typedef ExchangeHttpClientBuilder = OwHttpClient Function(OwHttpConfig config);

/// 一次只读请求。`query` 是已经编码好的查询串（不含 `?`），签名与发送共用同一份。
final class ExchangeCall {
  const ExchangeCall({
    required this.method,
    required this.path,
    this.query = '',
    this.headers = const {},
    this.body,
    this.emptyCodes = const {},
  });

  /// `GET` 或 `POST`（个别交易所的查询接口用 POST，仍是只读）。
  final String method;
  final String path;
  final String query;
  final Map<String, String> headers;

  /// 请求体原文；签名用的就是这一份字符串。本应用的查询请求都没有请求体。
  final String? body;

  /// 命中则视为"该账户类型未开通"，响应判定为 `Ok(null)`。
  final Set<String> emptyCodes;
}

/// 按时间戳（毫秒）构造一次请求。重试时会用校正后的时间戳重新调用。
typedef CallBuilder = ExchangeCall Function(int timestampMs);

/// 一家交易所某个主机的客户端：限速、时间校正重试、响应判定。
///
/// 一家交易所可能有多个主机（Binance 的现货、合约），它们共用同一个
/// [RateLimiter] 与同一个 [ClockSync]。
final class ExchangeClient {
  ExchangeClient({
    required this.http,
    required this.limiter,
    required this.clock,
    required this.judge,
  });

  final OwHttpClient http;

  /// 每家交易所一个，该家的所有主机共用。
  final RateLimiter limiter;
  final ClockSync clock;
  final ResponseJudge judge;

  /// 发送需要签名的请求。遇到时间戳偏差时，向服务器取时间校正偏移后重试一次；
  /// 仍失败返回 [ClockSkewFailure]。
  Future<Result<Object?>> signed(CallBuilder build) async {
    final first = await _attempt(build);
    if (first is! Err<Object?> || !isClockSkew(first.failure)) return first;

    final sync = await clock.resync();
    // 取不到服务器时间时无法校正，保持"时间偏差"这个原始结论。
    if (sync is Err<int>) return first;

    // 只重试一次；再次偏差时第二次的结果就是 ClockSkewFailure。
    return _attempt(build);
  }

  /// 发送不需要签名的公开请求（如服务器时间）。不做时间校正重试。
  Future<Result<Object?>> unsigned(ExchangeCall call) =>
      limiter.run(() => _send(call));

  Future<Result<Object?>> _attempt(CallBuilder build) =>
      limiter.run(() => _send(build(clock.nowMs())));

  Future<Result<Object?>> _send(ExchangeCall call) async {
    final target = call.query.isEmpty
        ? call.path
        : '${call.path}?${call.query}';
    final Response<String> response;
    try {
      response = await http.dio.request<String>(
        target,
        data: call.body,
        options: Options(
          method: call.method,
          headers: call.headers,
          contentType: call.body == null ? null : Headers.jsonContentType,
          responseType: ResponseType.plain,
          // 交易所的业务错误常常伴随 HTTP 4xx，响应体里才有错误码，
          // 所以这里放行所有状态码，由判定函数处理。
          validateStatus: (_) => true,
        ),
      );
    } on DioException catch (e) {
      return Err(mapHttpFailure(e));
    }

    final status = response.statusCode ?? 0;
    final host = response.requestOptions.uri.host;
    final text = response.data;
    Object? body;
    if (text != null && text.trim().isNotEmpty) {
      try {
        body = parseJsonExact(text);
      } on FormatException {
        body = null; // 不带原文：响应体可能含敏感内容。
      }
    }
    return judge(status, body, host, call.emptyCodes);
  }
}
