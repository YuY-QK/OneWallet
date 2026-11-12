import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:ow_domain/ow_domain.dart';

import 'sensitive_text.dart';

// 四家交易所的请求签名。全部是纯函数：同样的输入得到同样的输出，便于用官方示例验证。
// 只使用 `package:crypto` 的 HMAC-SHA256，不自己实现任何密码学算法。
// 密钥只在 [Sensitive.use] 回调里读取，不转存为长期持有的字符串。
//
// 各家算法的出处与核对记录见 docs/EXTERNAL_APIS.md。

/// HMAC-SHA256，输出小写十六进制。
String hmacSha256Hex(Sensitive secret, String message) => secret.use(
  (key) => Hmac(sha256, key).convert(utf8.encode(message)).toString(),
);

/// HMAC-SHA256，输出 Base64（标准字母表，带填充）。
String hmacSha256Base64(Sensitive secret, String message) => secret.use(
  (key) => base64Encode(Hmac(sha256, key).convert(utf8.encode(message)).bytes),
);

/// 把参数按给定顺序拼成查询串（`a=1&b=2`），键和值做百分号编码。
///
/// 签名与实际发出的查询串必须逐字符一致，所以两处都用本函数生成。
/// 不排序：Binance、Bybit 按发送顺序签名，Bitget 的文档也未要求排序。
String buildQuery(Map<String, String> params) => [
  for (final e in params.entries)
    '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
].join('&');

// ---------------------------------------------------------------- Binance

/// Binance：待签名串是"查询串 + 请求体"（无分隔符），HMAC-SHA256，十六进制。
///
/// 签名作为 `signature` 参数追加在查询串末尾；Key 放在请求头 [binanceKeyHeader]。
/// 本应用的 Binance 请求参数全部放在查询串里，请求体为空。
String binanceSignature({required Sensitive secret, required String payload}) =>
    hmacSha256Hex(secret, payload);

/// Binance 的 API Key 请求头名。
const binanceKeyHeader = 'X-MBX-APIKEY';

// -------------------------------------------------------------------- OKX

/// OKX 的时间戳：ISO 8601 UTC，毫秒精度，如 `2020-12-08T09:08:57.715Z`。
String okxTimestamp(DateTime time) {
  final utc = time.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  final ms = utc.millisecond.toString().padLeft(3, '0');
  return '${utc.year.toString().padLeft(4, '0')}-${two(utc.month)}-'
      '${two(utc.day)}T${two(utc.hour)}:${two(utc.minute)}:'
      '${two(utc.second)}.${ms}Z';
}

/// OKX 待签名串：`timestamp + method + requestPath + body`。
///
/// [requestPath] 含查询串（GET 的参数算在路径里），[method] 大写。
String okxPreHash({
  required String timestamp,
  required String method,
  required String requestPath,
  String body = '',
}) => '$timestamp${method.toUpperCase()}$requestPath$body';

/// OKX 签名：对 [okxPreHash] 做 HMAC-SHA256，再 Base64。
String okxSignature({required Sensitive secret, required String preHash}) =>
    hmacSha256Base64(secret, preHash);

const okxKeyHeader = 'OK-ACCESS-KEY';
const okxSignHeader = 'OK-ACCESS-SIGN';
const okxTimestampHeader = 'OK-ACCESS-TIMESTAMP';
const okxPassphraseHeader = 'OK-ACCESS-PASSPHRASE';

// ------------------------------------------------------------------ Bybit

/// Bybit 待签名串：`timestamp + apiKey + recvWindow + queryString`（GET）
/// 或 `... + jsonBodyString`（POST）。
String bybitPreHash({
  required String timestamp,
  required String apiKey,
  required String recvWindow,
  required String payload,
}) => '$timestamp$apiKey$recvWindow$payload';

/// Bybit 签名：HMAC-SHA256，小写十六进制。API Key 也参与待签名串，
/// 只在本函数内读取。
String bybitSignature({
  required Sensitive apiKey,
  required Sensitive secret,
  required int timestampMs,
  required int recvWindowMs,
  required String payload,
}) => hmacSha256Hex(
  secret,
  apiKey.use(
    (key) => bybitPreHash(
      timestamp: '$timestampMs',
      apiKey: utf8.decode(key, allowMalformed: true),
      recvWindow: '$recvWindowMs',
      payload: payload,
    ),
  ),
);

const bybitKeyHeader = 'X-BAPI-API-KEY';
const bybitSignHeader = 'X-BAPI-SIGN';
const bybitTimestampHeader = 'X-BAPI-TIMESTAMP';
const bybitRecvWindowHeader = 'X-BAPI-RECV-WINDOW';

// ----------------------------------------------------------------- Bitget

/// Bitget 待签名串：`timestamp + METHOD + requestPath [+ "?" + queryString] + body`。
///
/// 查询串为空时不加问号。
String bitgetPreHash({
  required String timestamp,
  required String method,
  required String requestPath,
  String queryString = '',
  String body = '',
}) =>
    '$timestamp${method.toUpperCase()}$requestPath'
    '${queryString.isEmpty ? '' : '?$queryString'}$body';

/// Bitget 签名：对 [bitgetPreHash] 做 HMAC-SHA256，再 Base64。
String bitgetSignature({required Sensitive secret, required String preHash}) =>
    hmacSha256Base64(secret, preHash);

const bitgetKeyHeader = 'ACCESS-KEY';
const bitgetSignHeader = 'ACCESS-SIGN';
const bitgetTimestampHeader = 'ACCESS-TIMESTAMP';
const bitgetPassphraseHeader = 'ACCESS-PASSPHRASE';

/// 四家交易所 API Key 相关请求头的名称，供 ow_net 日志脱敏
/// （`OwHttpConfig.extraSensitiveNames`）使用。
///
/// 名称里含 `key`、`sign`、`passphrase` 的 ow_net 本来就会脱敏；这里显式列出，
/// 避免日后改规则时漏掉。
const exchangeSensitiveHeaderNames = <String>[
  binanceKeyHeader,
  okxKeyHeader,
  okxPassphraseHeader,
  bybitKeyHeader,
  bitgetKeyHeader,
  bitgetPassphraseHeader,
];

/// 读取 [Sensitive] 为请求头的值；见 [sensitiveText] 的约定。
String headerValue(Sensitive value) => sensitiveText(value);
