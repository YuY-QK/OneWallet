import 'package:ow_domain/ow_domain.dart';
import 'package:ow_net/ow_net.dart';

// 各家业务错误码到 [Failure] 的映射。
//
// 约定（任务 M2-05）：
// - Key 无效、签名错误、权限不足 -> [UnauthorizedFailure]
// - Key 过期或已被删除 -> [KeyExpiredFailure]
// - IP 不在白名单 -> [UnauthorizedFailure]，detail 末尾标 `ip`
// - 限频 -> [RateLimitedFailure]
// - 时间戳偏差 -> [ClockSkewFailure]
// - 系统维护、服务端故障 -> [ServiceDownFailure]
// - 其余 -> [UnknownFailure]
//
// detail 只放错误码（形如 `code=-1021`），绝不放服务端返回的 message 原文、
// Key 或签名。错误码的出处见 docs/EXTERNAL_APIS.md 各交易所一节。

String _detail(String code, [String? mark]) =>
    mark == null ? 'code=$code' : 'code=$code $mark';

/// 该失败是否属于"时间戳偏差"，是则值得校正时间后重试一次。
bool isClockSkew(Failure failure) => failure is ClockSkewFailure;

/// Binance 的业务错误码（响应体 `code` 字段，负整数）。
Failure mapBinanceError(String code) {
  switch (code) {
    case '-1021':
      return ClockSkewFailure(_detail(code));
    case '-1003':
      return RateLimitedFailure(_detail(code));
    // -1002 未授权；-1022 签名无效；-2014 Key 格式无效；
    // -2015 "Invalid API-key, IP, or permissions for action"：官方把 Key 无效、
    // IP 不在白名单、权限不足合并成一个码，无法区分。
    case '-1002':
    case '-1022':
    case '-2014':
    case '-2015':
      return UnauthorizedFailure(_detail(code));
    case '-1000':
    case '-1001':
    case '-1006':
    case '-1007':
    case '-1008':
    case '-1016':
      return ServiceDownFailure(_detail(code));
  }
  return UnknownFailure(_detail(code));
}

/// Binance 在没有业务错误码时的 HTTP 状态映射：418（IP 被封）、429、
/// 403（WAF 规则，文档称可能是限频或安全拦截）都按限频处理。
Failure mapBinanceHttp(int status, String host) {
  if (status == 418 || status == 429 || status == 403) {
    return RateLimitedFailure('HTTP $status host=$host');
  }
  return mapHttpStatus(status, host);
}

/// OKX 的业务错误码（响应体 `code` 字段，字符串）。
Failure mapOkxError(String code) {
  switch (code) {
    case '50102':
      return ClockSkewFailure(_detail(code));
    case '50011':
    case '50013':
      return RateLimitedFailure(_detail(code));
    // 50110：IP 不在白名单；50121：该 IP 不允许访问服务。
    case '50110':
    case '50121':
      return UnauthorizedFailure(_detail(code, 'ip'));
    // 50111 Key 无效；50113 签名无效；50105 Passphrase 错误；50114 授权无效；
    // 50101 Key 与环境不匹配；50100 API 被冻结；50120 Key 无此接口权限；
    // 50103/50104/50106/50107 缺少必需的请求头。
    case '50111':
    case '50113':
    case '50105':
    case '50114':
    case '50101':
    case '50100':
    case '50120':
    case '50103':
    case '50104':
    case '50106':
    case '50107':
      return UnauthorizedFailure(_detail(code));
    case '50119':
      return KeyExpiredFailure(_detail(code));
    // 50001 服务暂不可用；50004 接口超时；50005 接口已下线或不可用。
    case '50001':
    case '50004':
    case '50005':
      return ServiceDownFailure(_detail(code));
  }
  return UnknownFailure(_detail(code));
}

/// Bybit 的业务错误码（响应体 `retCode`，整数）。
Failure mapBybitError(String code) {
  switch (code) {
    case '10002':
      return ClockSkewFailure(_detail(code));
    // 10006 访问过多；10018 IP 限频；10429 系统级频率保护。
    case '10006':
    case '10018':
    case '10429':
      return RateLimitedFailure(_detail(code));
    case '10010':
      return UnauthorizedFailure(_detail(code, 'ip'));
    // 10003 Key 无效；10004 签名错误；10005 权限不足；10007 认证失败。
    case '10003':
    case '10004':
    case '10005':
    case '10007':
      return UnauthorizedFailure(_detail(code));
    case '33004':
      return KeyExpiredFailure(_detail(code));
    // 10000 超时；10016 服务端错误或重启中；10019 交易服务重启中。
    case '10000':
    case '10016':
    case '10019':
      return ServiceDownFailure(_detail(code));
  }
  return UnknownFailure(_detail(code));
}

/// Bybit 无业务错误码时的 HTTP 状态映射：403 是 IP 限频（文档：访问过于频繁，
/// 需暂停至少 10 分钟），429 同为限频。
Failure mapBybitHttp(int status, String host) {
  if (status == 403 || status == 429) {
    return RateLimitedFailure('HTTP $status host=$host');
  }
  return mapHttpStatus(status, host);
}

/// Bitget 的业务错误码（响应体 `code`，字符串）。
Failure mapBitgetError(String code) {
  switch (code) {
    case '40008':
      return ClockSkewFailure(_detail(code));
    case '429':
      return RateLimitedFailure(_detail(code));
    // 40018 IP 无效；40038 当前 IP 不在 Key 的白名单。
    case '40018':
    case '40038':
      return UnauthorizedFailure(_detail(code, 'ip'));
    // 40006 Key 无效；40009 签名错误；40012 Key 或口令错误；40036 口令错误；
    // 40014/40025 权限不足；40001/40002/40003/40011 缺少必需的请求头。
    case '40006':
    case '40009':
    case '40012':
    case '40036':
    case '40014':
    case '40025':
    case '40001':
    case '40002':
    case '40003':
    case '40011':
      return UnauthorizedFailure(_detail(code));
    case '40037':
      return KeyExpiredFailure(_detail(code));
    // 40015 系统异常；40200 服务升级中；40725 下游服务返回错误。
    case '40015':
    case '40200':
    case '40725':
      return ServiceDownFailure(_detail(code));
  }
  return UnknownFailure(_detail(code));
}
