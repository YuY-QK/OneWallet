import 'dart:io' show HandshakeException, SocketException, TlsException;

import 'package:dio/dio.dart';
import 'package:ow_domain/ow_domain.dart';

/// 请求的 URL 不是 https 时（含不安全的重定向）抛出，由 [mapHttpFailure] 转为失败。
class InsecureUrlException implements Exception {
  /// 只保存主机名，避免把查询串带进异常信息。
  const InsecureUrlException(this.host);
  final String host;

  @override
  String toString() => 'InsecureUrlException(host=$host)';
}

/// 把 HTTP 状态码映射为 [Failure]；2xx 不应传入。
///
/// 400 → [ValidationFailure]；429 → [RateLimitedFailure]；
/// 401、403 → [UnauthorizedFailure]；5xx → [ServiceDownFailure]；其余 → [UnknownFailure]。
/// `detail` 只含状态码和主机。
Failure mapHttpStatus(int status, String host) {
  final detail = 'HTTP $status host=$host';
  if (status == 400) return ValidationFailure(detail);
  if (status == 429) return RateLimitedFailure(detail);
  if (status == 401 || status == 403) return UnauthorizedFailure(detail);
  if (status >= 500 && status <= 599) return ServiceDownFailure(detail);
  return UnknownFailure(detail);
}

/// 把 dio 的异常（或其他请求期间的异常）映射为统一的 [Failure]。
///
/// 连接失败与超时 → [NetworkFailure]，其余按状态码走 [mapHttpStatus]。
/// `detail` 中不放 URL 查询串、请求头或响应体，也不放原始异常文本。
Failure mapHttpFailure(Object error) {
  if (error is InsecureUrlException) {
    return UnknownFailure('拒绝非 HTTPS 请求 host=${error.host}');
  }
  if (error is! DioException) return const UnknownFailure('未知异常');

  final host = error.requestOptions.uri.host;
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return NetworkFailure('超时 host=$host');
    case DioExceptionType.connectionError:
      return NetworkFailure('连接失败 host=$host');
    case DioExceptionType.badCertificate:
      return NetworkFailure('证书无效 host=$host');
    case DioExceptionType.cancel:
      return UnknownFailure('请求已取消 host=$host');
    case DioExceptionType.badResponse:
      final status = error.response?.statusCode;
      if (status == null) return UnknownFailure('无状态码 host=$host');
      return mapHttpStatus(status, host);
    case DioExceptionType.unknown:
      final inner = error.error;
      if (inner is InsecureUrlException) return mapHttpFailure(inner);
      if (inner is SocketException ||
          inner is HandshakeException ||
          inner is TlsException) {
        return NetworkFailure('连接失败 host=$host');
      }
      return UnknownFailure('未知错误 host=$host');
  }
}
