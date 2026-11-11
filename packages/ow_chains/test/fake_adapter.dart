import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// 测试用的假适配器：不访问真实网络，按处理函数返回响应，并记录请求。
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  /// 参数：请求选项与解码后的 JSON 请求体。
  final ResponseBody Function(RequestOptions options, Map<String, Object?> body)
  handler;

  /// 实际到达适配器的请求。
  final List<RequestOptions> requests = [];

  /// 与 [requests] 一一对应的 JSON 请求体。
  final List<Map<String, Object?>> bodies = [];

  /// 到达适配器的 JSON-RPC 方法名。
  List<String> get methods => [for (final b in bodies) b['method']! as String];

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
    final text = utf8.decode(buffer.toBytes());
    final body = text.isEmpty
        ? <String, Object?>{}
        : (jsonDecode(text) as Map<String, Object?>);
    bodies.add(body);
    return handler(options, body);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(String body, {int status = 200}) =>
    ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

ResponseBody rpcResult(Object? result) =>
    jsonResponse(jsonEncode({'jsonrpc': '2.0', 'id': 1, 'result': result}));

ResponseBody rpcError(int code, String message) => jsonResponse(
  jsonEncode({
    'jsonrpc': '2.0',
    'id': 1,
    'error': {'code': code, 'message': message},
  }),
);
