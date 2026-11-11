import 'package:dio/dio.dart';

import 'failure_mapper.dart';
import 'redaction.dart';

/// 日志回调。收到的每一行都已脱敏，可以直接交给统一的 Logger。
typedef OwLogSink = void Function(String line);

const _startKey = 'ow_net.start';
const _redirectKey = 'ow_net.redirects';

/// 脱敏日志拦截器：只记录方法、主机与路径、状态码、耗时，以及脱敏后的请求头与查询参数。
///
/// **不记录请求体与响应体**；失败时也不记录异常文本（其中可能带 URL）。
class RedactingLogInterceptor extends Interceptor {
  RedactingLogInterceptor({
    required this.sink,
    required this.redactor,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final OwLogSink sink;
  final Redactor redactor;
  final DateTime Function() _now;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startKey] = _now();
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    sink(_line(response.requestOptions, '${response.statusCode}'));
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final status = err.response?.statusCode;
    final outcome = status != null ? '$status' : 'ERR ${err.type.name}';
    sink(_line(err.requestOptions, outcome));
    handler.next(err);
  }

  String _line(RequestOptions options, String outcome) {
    final uri = options.uri;
    final start = options.extra[_startKey];
    final elapsed = start is DateTime
        ? '${_now().difference(start).inMilliseconds}ms'
        : '-';
    final query = redactor.formatQuery(uri.queryParametersAll);
    final headers = redactor.formatHeaders(options.headers);
    return '${options.method} ${uri.host}${uri.path}'
        '${query.isEmpty ? '' : '?$query'} headers=$headers '
        '-> $outcome $elapsed';
  }
}

/// 只允许 HTTPS：拒绝非 https 的请求，并手动处理重定向。
///
/// 底层适配器不自动跟随重定向（由 [BaseOptions.followRedirects] 关闭）；
/// 本拦截器对 301/302/303/307/308 逐跳检查：目标不是 https 则失败，
/// 是 https 才继续。跨主机跳转时剥离敏感请求头，避免把 Key 发给别的主机。
class HttpsOnlyInterceptor extends Interceptor {
  HttpsOnlyInterceptor({
    required this.dio,
    required this.redactor,
    this.maxRedirects = 5,
  });

  final Dio dio;
  final Redactor redactor;
  final int maxRedirects;

  static const _redirectStatuses = {301, 302, 303, 307, 308};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final uri = options.uri;
    if (uri.scheme != 'https') {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          error: InsecureUrlException(uri.host),
        ),
        true,
      );
      return;
    }
    handler.next(options);
  }

  @override
  Future<void> onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    final status = response.statusCode;
    final location = response.headers.value('location');
    if (status == null ||
        !_redirectStatuses.contains(status) ||
        location == null) {
      handler.next(response);
      return;
    }

    final origin = response.requestOptions;
    final hops = (origin.extra[_redirectKey] as int? ?? 0) + 1;
    if (hops > maxRedirects) {
      handler.reject(
        DioException(
          requestOptions: origin,
          response: response,
          type: DioExceptionType.badResponse,
          message: '重定向次数过多',
        ),
      );
      return;
    }

    final target = origin.uri.resolve(location);
    if (target.scheme != 'https') {
      handler.reject(
        DioException(
          requestOptions: origin,
          type: DioExceptionType.unknown,
          error: InsecureUrlException(target.host),
        ),
      );
      return;
    }

    // 303 一律改为 GET；其余保持方法与请求体。
    final toGet = status == 303;
    final crossHost = target.host != origin.uri.host;
    final headers = Map<String, dynamic>.of(origin.headers);
    if (crossHost) {
      headers.removeWhere((name, _) => redactor.isSensitive(name));
    }
    final next = origin.copyWith(
      path: target.removeFragment().toString(),
      queryParameters: <String, dynamic>{},
      method: toGet ? 'GET' : origin.method,
      data: toGet ? null : origin.data,
      headers: headers,
      extra: {...origin.extra, _redirectKey: hops},
    );
    try {
      handler.resolve(await dio.fetch<dynamic>(next));
    } on DioException catch (e) {
      handler.reject(e);
    }
  }
}
