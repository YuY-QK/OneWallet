import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// 测试用的假适配器：不访问真实网络，按处理函数返回响应或抛出异常，并记录请求。
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;

  /// 实际到达适配器的请求。
  final List<RequestOptions> requests = [];

  /// 与 [requests] 一一对应的请求体文本。
  final List<String> bodies = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final buffer = BytesBuilder();
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        buffer.add(chunk);
      }
    }
    bodies.add(utf8.decode(buffer.toBytes()));
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(
  String body, {
  int status = 200,
  Map<String, List<String>> headers = const {},
}) => ResponseBody.fromString(
  body,
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
    ...headers,
  },
);

ResponseBody redirectTo(String location, {int status = 302}) =>
    ResponseBody.fromString(
      '',
      status,
      headers: {
        'location': [location],
      },
    );
