import 'package:dio/dio.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:ow_net/ow_net.dart';
import 'package:test/test.dart';

import 'fake_adapter.dart';

OwHttpClient _client(
  FakeAdapter adapter, {
  String baseUrl = 'https://api.example.com/v1',
  OwLogSink? onLog,
  Map<String, String> headers = const {},
  List<String> extraSensitive = const [],
}) => OwHttpClientFactory.create(
  OwHttpConfig(
    baseUrl: baseUrl,
    onLog: onLog,
    defaultHeaders: headers,
    extraSensitiveNames: extraSensitive,
  ),
  adapter: adapter,
);

void main() {
  group('工厂_配置', () {
    test('baseUrl为http_抛出ArgumentError', () {
      expect(
        () => OwHttpClientFactory.create(
          const OwHttpConfig(baseUrl: 'http://api.example.com'),
        ),
        throwsArgumentError,
      );
    });

    test('baseUrl无主机或无法解析_抛出ArgumentError', () {
      for (final bad in ['https://', 'ftp://x.com', 'api.example.com', '']) {
        expect(
          () => OwHttpClientFactory.create(OwHttpConfig(baseUrl: bad)),
          throwsArgumentError,
          reason: bad,
        );
      }
    });

    test('默认超时各15秒_并带上默认请求头', () async {
      final adapter = FakeAdapter((_) => jsonResponse('{}'));
      final client = _client(adapter, headers: {'Accept': 'application/json'});
      expect(client.dio.options.connectTimeout, const Duration(seconds: 15));
      expect(client.dio.options.receiveTimeout, const Duration(seconds: 15));
      await client.getJson('/ping');
      expect(adapter.requests.single.headers['Accept'], 'application/json');
      expect(
        adapter.requests.single.uri.toString(),
        'https://api.example.com/v1/ping',
      );
    });

    test('请求的绝对URL为http_返回失败且不发出请求', () async {
      final adapter = FakeAdapter((_) => jsonResponse('{}'));
      final result = await _client(adapter)
          .getJson('http://evil.example.org/x?token=abcdef123456');
      expect(adapter.requests, isEmpty);
      final failure = (result as Err<Object?>).failure;
      expect(failure, isA<UnknownFailure>());
      expect(failure.detail, contains('evil.example.org'));
      expect(failure.detail, isNot(contains('token')));
    });
  });

  group('重定向', () {
    test('跳转到http_不被跟随且按失败处理', () async {
      final adapter = FakeAdapter(
        (_) => redirectTo('http://insecure.example.org/next?sig=abc'),
      );
      final result = await _client(adapter).getJson('/a');
      expect(adapter.requests, hasLength(1));
      final failure = (result as Err<Object?>).failure;
      expect(failure.detail, contains('insecure.example.org'));
      expect(failure.detail, isNot(contains('sig')));
    });

    test('跳转到https_被跟随并返回最终结果', () async {
      final adapter = FakeAdapter(
        (o) => o.uri.path == '/v1/a'
            ? redirectTo('/v1/b?x=1', status: 301)
            : jsonResponse('{"ok":true}'),
      );
      final result = await _client(adapter).getJson('/a');
      expect(adapter.requests, hasLength(2));
      expect(
        adapter.requests[1].uri.toString(),
        'https://api.example.com/v1/b?x=1',
      );
      expect(result.valueOrNull, {'ok': true});
    });

    test('跨主机跳转_剥离敏感请求头但保留普通头', () async {
      final adapter = FakeAdapter(
        (o) => o.uri.host == 'api.example.com'
            ? redirectTo('https://cdn.example.net/data')
            : jsonResponse('[]'),
      );
      final client = _client(
        adapter,
        headers: {
          'X-MBX-APIKEY': 'abcdefgh12345678',
          'Accept': 'application/json',
        },
        extraSensitive: ['X-MBX-APIKEY'],
      );
      await client.getJson('/a', headers: {'Authorization': 'Bearer zzzzzzzz'});
      final second = adapter.requests[1];
      expect(second.uri.host, 'cdn.example.net');
      expect(
        second.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('x-mbx-apikey')),
      );
      expect(
        second.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('authorization')),
      );
      expect(second.headers['Accept'], 'application/json');
    });

    test('重定向次数过多_返回失败', () async {
      final adapter = FakeAdapter((_) => redirectTo('/v1/loop'));
      final result = await _client(adapter).getJson('/loop');
      expect(result, isA<Err<Object?>>());
      expect(adapter.requests.length, lessThanOrEqualTo(7));
    });
  });

  group('日志拦截器', () {
    test('未传日志回调_不启用', () async {
      final adapter = FakeAdapter((_) => jsonResponse('{}'));
      final client = _client(adapter);
      final withLog = _client(adapter, onLog: (_) {});
      expect(
        client.dio.interceptors.length,
        withLog.dio.interceptors.length - 1,
      );
      expect((await client.getJson('/x')).isOk, isTrue);
    });

    test('敏感请求头_查询参数_请求体_日志中不含完整值', () async {
      const apiKey = 'AKIAIOSFODNN7EXAMPLE';
      const signature = 'c0ffee1234567890deadbeef';
      const secret = 'wJalrXUtnFEMI-K7MDENG-bPxRfiCY';
      const token = 'tok_live_1234567890';
      const bodySecret = 'body-secret-value-xyz';
      final lines = <String>[];
      final adapter = FakeAdapter(
        (_) => jsonResponse('{"balance":"response-body-marker"}'),
      );
      final client = _client(
        adapter,
        onLog: lines.add,
        extraSensitive: ['X-Custom-Id'],
        headers: {'OK-ACCESS-KEY': apiKey},
      );
      await client.postJson(
        '/account',
        body: {'apiSecret': bodySecret, 'note': 'request-body-marker'},
        queryParameters: {
          'signature': signature,
          'timestamp': '1700000000',
          'access_token': token,
        },
        headers: {
          'X-MBX-APIKEY': apiKey,
          'X-Secret': secret,
          'Authorization': 'Bearer $secret',
          'X-Custom-Id': 'custom-id-123456',
        },
      );

      final log = lines.join('\n');
      expect(lines, isNotEmpty);
      expect(log, contains('POST api.example.com/v1/account'));
      expect(log, contains('200'));
      expect(log, contains('ms'));
      // 完整值都不得出现
      for (final secretValue in [
        apiKey,
        signature,
        secret,
        token,
        'custom-id-123456',
      ]) {
        expect(log, isNot(contains(secretValue)), reason: secretValue);
      }
      // API Key 保留前 4 位；签名、Secret、Authorization 完全替换
      expect(log, contains('X-MBX-APIKEY: AKIA***'));
      expect(log, contains('OK-ACCESS-KEY: AKIA***'));
      expect(log, contains('X-Custom-Id: cust***'));
      expect(log, contains('access_token=tok_***'));
      expect(log, contains('signature=***'));
      expect(log, contains('X-Secret: ***'));
      expect(log, contains('Authorization: ***'));
      // 不敏感的参数保持原样
      expect(log, contains('timestamp=1700000000'));
      // 不记录请求体与响应体
      expect(log, isNot(contains(bodySecret)));
      expect(log, isNot(contains('request-body-marker')));
      expect(log, isNot(contains('response-body-marker')));
    });

    test('名称匹配不区分大小写', () {
      final r = Redactor();
      expect(r.redactValue('API-KEY', 'abcdefghijkl'), 'abcd***');
      expect(r.redactValue('X-SiGn', 'abcdefghijkl'), '***');
      expect(r.redactValue('PassPhrase', 'abcdefghijkl'), '***');
      expect(r.redactValue('Accept', 'application/json'), 'application/json');
    });

    test('敏感值过短_完全替换而不是露出前4位', () {
      expect(Redactor().redactValue('apikey', 'abcd1'), '***');
    });

    test('失败请求_日志只含状态码或错误类型_不含响应体', () async {
      final lines = <String>[];
      final adapter = FakeAdapter(
        (_) => jsonResponse('{"msg":"error-body-marker"}', status: 500),
      );
      await _client(
        adapter,
        onLog: lines.add,
      ).getJson('/x?apikey=abcdefghijkl');
      final log = lines.join('\n');
      expect(log, contains('500'));
      expect(log, isNot(contains('error-body-marker')));
      expect(log, isNot(contains('abcdefghijkl')));
    });

    test('跳转的每一跳都记录且均已脱敏', () async {
      final lines = <String>[];
      final adapter = FakeAdapter(
        (o) => o.uri.path == '/v1/a'
            ? redirectTo('/v1/b?token=abcdefghijkl')
            : jsonResponse('{}'),
      );
      await _client(adapter, onLog: lines.add).getJson('/a');
      final log = lines.join('\n');
      expect(lines, hasLength(2));
      expect(log, contains('302'));
      expect(log, isNot(contains('abcdefghijkl')));
    });
  });

  group('便捷方法', () {
    test('getJson_成功解析JSON', () async {
      final adapter = FakeAdapter((_) => jsonResponse('{"a":[1,2]}'));
      final result = await _client(adapter).getJson('/x');
      expect(result.valueOrNull, {
        'a': [1, 2],
      });
    });

    test('postJson_发送JSON请求体', () async {
      final adapter = FakeAdapter((_) => jsonResponse('{"ok":1}'));
      final result = await _client(adapter).postJson('/x', body: {'k': 'v'});
      expect(adapter.bodies.single, '{"k":"v"}');
      expect(adapter.requests.single.method, 'POST');
      expect(result.isOk, isTrue);
    });

    test('空响应体_返回Ok(null)', () async {
      final adapter = FakeAdapter((_) => jsonResponse('', status: 204));
      final result = await _client(adapter).getJson('/x');
      expect(result, isA<Ok<Object?>>());
      expect(result.valueOrNull, isNull);
    });

    test('响应不是JSON_返回UnknownFailure且不含原文', () async {
      final adapter = FakeAdapter((_) => jsonResponse('<html>body-marker'));
      final failure =
          ((await _client(adapter).getJson('/x')) as Err<Object?>).failure;
      expect(failure, isA<UnknownFailure>());
      expect(failure.detail, isNot(contains('body-marker')));
    });

    test('429_RateLimited', () async {
      final adapter = FakeAdapter((_) => jsonResponse('{}', status: 429));
      final result = await _client(adapter).getJson('/x');
      expect((result as Err<Object?>).failure, isA<RateLimitedFailure>());
    });

    test('底层连接错误_NetworkFailure', () async {
      final adapter = FakeAdapter(
        (o) => throw DioException.connectionError(
          requestOptions: o,
          reason: 'refused',
        ),
      );
      final result = await _client(adapter).getJson('/x');
      expect((result as Err<Object?>).failure, isA<NetworkFailure>());
    });
  });
}
