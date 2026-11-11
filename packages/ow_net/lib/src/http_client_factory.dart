import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:ow_domain/ow_domain.dart';

import 'failure_mapper.dart';
import 'interceptors.dart';
import 'redaction.dart';

export 'interceptors.dart' show OwLogSink;

/// 一个服务商的 HTTP 客户端配置。
class OwHttpConfig {
  const OwHttpConfig({
    required this.baseUrl,
    this.connectTimeout = const Duration(seconds: 15),
    this.receiveTimeout = const Duration(seconds: 15),
    this.defaultHeaders = const {},
    this.extraSensitiveNames = const [],
    this.onLog,
  });

  /// 必须是 https 地址，否则创建客户端时抛出 [ArgumentError]。
  final String baseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Map<String, String> defaultHeaders;

  /// 日志脱敏时额外视为敏感的名称，如 `X-MBX-APIKEY`、`OK-ACCESS-KEY`。
  final List<String> extraSensitiveNames;

  /// 传入才启用日志拦截器；收到的每行都已脱敏，且不含请求体与响应体。
  final OwLogSink? onLog;
}

/// 按 [OwHttpConfig] 创建只允许 HTTPS 的客户端。
abstract final class OwHttpClientFactory {
  /// [baseUrl] 不是合法的 https 地址时抛出 [ArgumentError]（属于程序缺陷）。
  ///
  /// [adapter] 仅供测试注入假适配器，生产代码不传。
  static OwHttpClient create(
    OwHttpConfig config, {
    HttpClientAdapter? adapter,
  }) {
    final base = Uri.tryParse(config.baseUrl);
    if (base == null || base.scheme != 'https' || base.host.isEmpty) {
      throw ArgumentError.value(base?.host ?? '', 'baseUrl', '只允许 https 地址');
    }

    final dio = Dio(
      BaseOptions(
        baseUrl: config.baseUrl,
        connectTimeout: config.connectTimeout,
        receiveTimeout: config.receiveTimeout,
        headers: Map<String, dynamic>.of(config.defaultHeaders),
        // 重定向由 HttpsOnlyInterceptor 逐跳检查，底层不自动跟随。
        followRedirects: false,
        validateStatus: (status) => status != null && status < 400,
        responseType: ResponseType.plain,
      ),
    );
    if (adapter != null) dio.httpClientAdapter = adapter;

    final redactor = Redactor(extraSensitiveNames: config.extraSensitiveNames);
    final sink = config.onLog;
    // 日志在前：先记录 3xx 这一跳，再由后面的拦截器处理重定向。
    if (sink != null) {
      dio.interceptors.add(
        RedactingLogInterceptor(sink: sink, redactor: redactor),
      );
    }
    dio.interceptors.add(HttpsOnlyInterceptor(dio: dio, redactor: redactor));
    return OwHttpClient._(dio);
  }
}

/// 包装 [Dio] 的客户端，提供返回 [Result] 的便捷方法。
class OwHttpClient {
  OwHttpClient._(this.dio);

  /// 底层 dio，需要更细控制时使用；拦截器已装好。
  final Dio dio;

  /// GET 并把响应体按 JSON 解析。
  ///
  /// 失败（网络、非 2xx、非 https、响应不是合法 JSON）以 [Err] 返回，不抛异常。
  /// 空响应体返回 `Ok(null)`。
  Future<Result<Object?>> getJson(
    String path, {
    Map<String, Object?>? queryParameters,
    Map<String, String>? headers,
  }) => _send('GET', path, queryParameters: queryParameters, headers: headers);

  /// POST [body]（经 JSON 编码）并把响应体按 JSON 解析。失败语义同 [getJson]。
  Future<Result<Object?>> postJson(
    String path, {
    Object? body,
    Map<String, Object?>? queryParameters,
    Map<String, String>? headers,
  }) => _send(
    'POST',
    path,
    body: body,
    queryParameters: queryParameters,
    headers: headers,
  );

  Future<Result<Object?>> _send(
    String method,
    String path, {
    Object? body,
    Map<String, Object?>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final Response<String> response;
    try {
      response = await dio.request<String>(
        path,
        data: body == null ? null : jsonEncode(body),
        queryParameters: queryParameters,
        options: Options(
          method: method,
          headers: headers,
          contentType: body == null ? null : Headers.jsonContentType,
          responseType: ResponseType.plain,
        ),
      );
    } on DioException catch (e) {
      return Err(mapHttpFailure(e));
    }

    final host = response.requestOptions.uri.host;
    final status = response.statusCode ?? 0;
    if (status < 200 || status > 299) {
      return Err(mapHttpStatus(status, host));
    }
    final text = response.data;
    if (text == null || text.trim().isEmpty) return const Ok(null);
    try {
      return Ok(jsonDecode(text));
    } on FormatException {
      // 不带原文：响应体可能含敏感内容。
      return Err(UnknownFailure('响应不是合法 JSON host=$host'));
    }
  }
}
