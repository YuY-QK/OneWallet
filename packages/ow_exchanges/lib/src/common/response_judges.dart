import 'package:ow_domain/ow_domain.dart';
import 'package:ow_net/ow_net.dart';

import 'error_mapping.dart';
import 'exact_json.dart';

/// 判定一次响应：成功返回业务数据，失败返回 [Failure]。
///
/// - [status]：HTTP 状态码；
/// - [body]：按 [parseJsonExact] 解析的响应体（数字是 [JsonNumber]），不是合法 JSON 时为 null；
/// - [emptyCodes]：调用方声明的"该账户类型未开通"类业务码，命中时返回 `Ok(null)`，
///   由调用方当作空结果。
typedef ResponseJudge = Result<Object?> Function(
  int status,
  Object? body,
  String host,
  Set<String> emptyCodes,
);

/// 把 JSON 里的码（数字或字符串）统一成字符串；缺失或类型不对返回 null。
String? _codeText(Object? value) => switch (value) {
  JsonNumber(:final text) => text,
  String() => value,
  int() => '$value',
  _ => null,
};

bool _isSuccessStatus(int status) => status >= 200 && status <= 299;

/// Binance：成功时 HTTP 2xx，响应体就是业务数据（没有统一的外层包装）；
/// 失败时 HTTP 4xx 且响应体为 `{"code": -1021, "msg": "..."}`。
Result<Object?> judgeBinance(
  int status,
  Object? body,
  String host,
  Set<String> emptyCodes,
) {
  if (_isSuccessStatus(status)) {
    if (body == null) return const Err(UnknownFailure('响应不是合法 JSON'));
    return Ok(body);
  }
  final code = body is Map<String, Object?> ? _codeText(body['code']) : null;
  if (code != null) {
    if (emptyCodes.contains(code)) return const Ok(null);
    // 418/429 即使带业务码也以限频为准。
    if (status == 418 || status == 429) {
      return Err(mapBinanceHttp(status, host));
    }
    return Err(mapBinanceError(code));
  }
  return Err(mapBinanceHttp(status, host));
}

/// OKX：`{"code": "0", "msg": "", "data": [...]}`，错误时 `code` 非 "0"。
/// HTTP 状态不一定反映业务结果（很多错误是 HTTP 200），以 `code` 为准。
Result<Object?> judgeOkx(
  int status,
  Object? body,
  String host,
  Set<String> emptyCodes,
) {
  final code = body is Map<String, Object?> ? _codeText(body['code']) : null;
  if (code == null) {
    if (_isSuccessStatus(status)) {
      return const Err(UnknownFailure('响应缺少 code 字段'));
    }
    return Err(mapHttpStatus(status, host));
  }
  if (code == '0') return Ok((body as Map<String, Object?>)['data']);
  if (emptyCodes.contains(code)) return const Ok(null);
  return Err(mapOkxError(code));
}

/// Bybit：`{"retCode": 0, "retMsg": "OK", "result": {...}}`。
Result<Object?> judgeBybit(
  int status,
  Object? body,
  String host,
  Set<String> emptyCodes,
) {
  final code = body is Map<String, Object?> ? _codeText(body['retCode']) : null;
  if (code == null) {
    if (_isSuccessStatus(status)) {
      return const Err(UnknownFailure('响应缺少 retCode 字段'));
    }
    return Err(mapBybitHttp(status, host));
  }
  if (code == '0') return Ok((body as Map<String, Object?>)['result']);
  if (emptyCodes.contains(code)) return const Ok(null);
  return Err(mapBybitError(code));
}

/// Bitget：`{"code": "00000", "msg": "success", "data": ...}`。
Result<Object?> judgeBitget(
  int status,
  Object? body,
  String host,
  Set<String> emptyCodes,
) {
  final code = body is Map<String, Object?> ? _codeText(body['code']) : null;
  if (code == null) {
    if (status == 429) return Err(mapBitgetError('429'));
    if (_isSuccessStatus(status)) {
      return const Err(UnknownFailure('响应缺少 code 字段'));
    }
    return Err(mapHttpStatus(status, host));
  }
  if (code == '00000') return Ok((body as Map<String, Object?>)['data']);
  if (emptyCodes.contains(code)) return const Ok(null);
  return Err(mapBitgetError(code));
}
