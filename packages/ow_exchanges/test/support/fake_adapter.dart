import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:ow_net/ow_net.dart';

/// 测试用的假适配器：不访问真实网络，按处理函数返回响应，并记录请求。
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  /// 参数：请求选项与请求体原文（没有请求体为空串）。
  final ResponseBody Function(RequestOptions options, String body) handler;

  final List<RequestOptions> requests = [];

  /// 到达适配器的请求路径（不含查询串）。
  List<String> get paths => [for (final r in requests) r.uri.path];

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
    return handler(options, utf8.decode(buffer.toBytes()));
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

/// 读取 test/fixtures 下的样本。测试在包根目录运行（`dart test`）。
String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

/// 固定时间的时钟。
class FixedClock implements Clock {
  FixedClock(this.now);
  DateTime now;

  @override
  DateTime nowUtc() => now;
}

/// 测试用凭据：值是明显的假数据。
ExchangeCredentials fakeCredentials({String? passphrase}) =>
    ExchangeCredentials(
      apiKey: Sensitive(Uint8List.fromList(utf8.encode('TESTKEY'))),
      apiSecret: Sensitive(Uint8List.fromList(utf8.encode('TESTSECRET'))),
      passphrase: passphrase == null
          ? null
          : Sensitive(Uint8List.fromList(utf8.encode(passphrase))),
    );

/// 不真正等待的限速器，测试里避免被限速拖慢。
RateLimiter testLimiter() =>
    RateLimiter(maxRequests: 1000, window: const Duration(seconds: 1));
