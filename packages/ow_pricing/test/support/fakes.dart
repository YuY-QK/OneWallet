import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:ow_domain/ow_domain.dart';

/// 假适配器：不访问真实网络，记录请求，按处理函数返回响应或抛出异常。
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(String body, {int status = 200}) =>
    ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

/// 读取 test/fixtures 下的录制样本（测试在包根目录运行）。
String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

class FakeClock implements Clock {
  FakeClock(this.now);
  DateTime now;

  @override
  DateTime nowUtc() => now;
}

class FakeConfig implements DataSourceConfig {
  FakeConfig({this.key});
  String? key;

  @override
  Future<String?> apiKey(String providerId) async =>
      providerId == 'coingecko' ? key : null;

  @override
  Future<Uri?> customEndpoint(String chainId) async => null;
}

/// 从请求里取 `ids` 参数并按逗号拆开。
List<String> idsOf(RequestOptions o) =>
    (o.queryParameters['ids'] as String).split(',');

/// 把一段 JSON 文本拆成对象，供测试按需裁剪。
Map<String, Object?> decodeObject(String text) =>
    jsonDecode(text) as Map<String, Object?>;
