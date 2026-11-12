import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:ow_exchanges/ow_exchanges.dart';
import 'package:ow_net/ow_net.dart';
import 'package:test/test.dart';

import '../support/fake_adapter.dart';

void main() {
  group('时间校正与重试一次', () {
    late FakeAdapter fake;
    late ExchangeClient client;
    late FixedClock clock;
    var serverTimeCalls = 0;

    ExchangeClient build(ResponseBody Function(RequestOptions, String) h) {
      fake = FakeAdapter(h);
      clock = FixedClock(DateTime.utc(2026, 1, 1));
      serverTimeCalls = 0;
      final http = OwHttpClientFactory.create(
        const OwHttpConfig(baseUrl: 'https://test.example'),
        adapter: fake,
      );
      late ClockSync sync;
      sync = ClockSync(
        clock: clock,
        fetchServerTime: () async {
          serverTimeCalls++;
          // 服务器比设备快 60 秒。
          return Ok(clock.nowUtc().millisecondsSinceEpoch + 60000);
        },
      );
      return client = ExchangeClient(
        http: http,
        limiter: testLimiter(),
        clock: sync,
        judge: judgeBinance,
      );
    }

    CallBuilder builder() =>
        (ts) => ExchangeCall(method: 'GET', path: '/x', query: 'timestamp=$ts');

    test('偏差后校正偏移并重试成功', () async {
      final base = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;
      build((o, b) {
        final ts = int.parse(o.uri.queryParameters['timestamp']!);
        return ts < base + 30000
            ? jsonResponse('{"code":-1021,"msg":"x"}', status: 400)
            : jsonResponse('{"ok":true}');
      });
      final r = await client.signed(builder());
      expect(r, isA<Ok<Object?>>());
      expect(fake.requests, hasLength(2));
      expect(serverTimeCalls, 1);
    });

    test('校正后仍偏差返回 ClockSkewFailure，且只重试一次', () async {
      build((o, b) => jsonResponse('{"code":-1021,"msg":"x"}', status: 400));
      final r = await client.signed(builder());
      expect((r as Err<Object?>).failure, isA<ClockSkewFailure>());
      expect(fake.requests, hasLength(2));
    });

    test('取不到服务器时间时保持 ClockSkewFailure，不重试', () async {
      fake = FakeAdapter(
        (o, b) => jsonResponse('{"code":-1021,"msg":"x"}', status: 400),
      );
      final sync = ClockSync(
        clock: FixedClock(DateTime.utc(2026)),
        fetchServerTime: () async => const Err(NetworkFailure('超时')),
      );
      final c = ExchangeClient(
        http: OwHttpClientFactory.create(
          const OwHttpConfig(baseUrl: 'https://test.example'),
          adapter: fake,
        ),
        limiter: testLimiter(),
        clock: sync,
        judge: judgeBinance,
      );
      final r = await c.signed(builder());
      expect((r as Err<Object?>).failure, isA<ClockSkewFailure>());
      expect(fake.requests, hasLength(1));
    });

    test('非偏差类错误不重试', () async {
      build((o, b) => jsonResponse('{"code":-2015,"msg":"x"}', status: 401));
      final r = await client.signed(builder());
      expect((r as Err<Object?>).failure, isA<UnauthorizedFailure>());
      expect(fake.requests, hasLength(1));
    });

    test('失败的 detail 只含错误码，不含服务端 message', () async {
      build(
        (o, b) =>
            jsonResponse('{"code":-2015,"msg":"SECRET-ECHO"}', status: 401),
      );
      final r = await client.signed(builder());
      expect((r as Err<Object?>).failure.detail, 'code=-2015');
    });
  });

  group('响应判定', () {
    test('OKX：code 非 0 映射，IP 白名单标 ip', () {
      final r = judgeOkx(200, {'code': '50110'}, 'h', const {});
      final f = (r as Err<Object?>).failure;
      expect(f, isA<UnauthorizedFailure>());
      expect(f.detail, contains('ip'));
    });

    test('OKX：成功取 data；未开通码视为空', () {
      expect(
        (judgeOkx(
          200,
          {'code': '0', 'data': <Object?>[]},
          'h',
          const {},
        ) as Ok<Object?>).value,
        isEmpty,
      );
      expect(
        (judgeOkx(
          200,
          {'code': '58002'},
          'h',
          const {'58002'},
        ) as Ok<Object?>).value,
        isNull,
      );
    });

    test('Bybit / Bitget 成功与限频', () {
      expect(
        (judgeBybit(
          200,
          {'retCode': const JsonNumber('0'), 'result': 1},
          'h',
          {},
        ) as Ok<Object?>).value,
        1,
      );
      expect(
        (judgeBybit(403, null, 'h', {}) as Err<Object?>).failure,
        isA<RateLimitedFailure>(),
      );
      expect(
        (judgeBitget(
          200,
          {'code': '00000', 'data': 2},
          'h',
          {},
        ) as Ok<Object?>).value,
        2,
      );
      expect(
        (judgeBitget(429, null, 'h', {}) as Err<Object?>).failure,
        isA<RateLimitedFailure>(),
      );
    });
  });

  group('错误码映射', () {
    test('各类别', () {
      expect(mapBinanceError('-1021'), isA<ClockSkewFailure>());
      expect(mapBinanceError('-1003'), isA<RateLimitedFailure>());
      expect(mapBinanceError('-1022'), isA<UnauthorizedFailure>());
      expect(mapBinanceError('-1016'), isA<ServiceDownFailure>());
      expect(mapBinanceError('-9999'), isA<UnknownFailure>());
      expect(mapOkxError('50102'), isA<ClockSkewFailure>());
      expect(mapOkxError('50119'), isA<KeyExpiredFailure>());
      expect(mapBybitError('33004'), isA<KeyExpiredFailure>());
      expect(mapBitgetError('40037'), isA<KeyExpiredFailure>());
      expect(mapBitgetError('40038').detail, contains('ip'));
    });

    test('Binance HTTP 状态：403/418/429 为限频', () {
      for (final s in [403, 418, 429]) {
        expect(mapBinanceHttp(s, 'h'), isA<RateLimitedFailure>());
      }
      expect(mapBinanceHttp(503, 'h'), isA<ServiceDownFailure>());
    });
  });

  group('持仓累加与精度', () {
    test('同币种求和、零值丢弃、负数保留、符号大写', () {
      final acc = HoldingsAccumulator(ExchangeId.binance)
        ..add(ExchangeSubAccount.spot, 'btc', Decimal.parse('0.1'))
        ..add(ExchangeSubAccount.spot, 'BTC', Decimal.parse('0.2'))
        ..add(ExchangeSubAccount.spot, 'ETH', Decimal.zero)
        ..add(ExchangeSubAccount.margin, 'USDT', Decimal.parse('-1'));
      final out = acc.build();
      expect(out, hasLength(2));
      expect(out[0].$2.amount, Decimal.parse('0.3'));
      expect(out[0].$2.token, const ExchangeToken(ExchangeId.binance, 'BTC'));
      expect(out[1].$2.amount, Decimal.parse('-1'));
    });

    test('JSON 数字保留原文精度', () {
      final v =
          parseJsonExact('{"a":0.1234567890123456789}')!
              as Map<String, Object?>;
      expect(parseAmount(v['a']), Decimal.parse('0.1234567890123456789'));
    });

    test('空串按 0，非法数字为 null', () {
      expect(amountOrZero(''), Decimal.zero);
      expect(amountOrZero(null), Decimal.zero);
      expect(amountOrZero('abc'), isNull);
    });

    test('白名单断言辅助', () {
      expect(pathsOutsideAllowlist(['/a', '/b', '/b'], {'/a'}), ['/b']);
    });
  });
}
