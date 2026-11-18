import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:ow_chains/ow_chains.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:ow_net/ow_net.dart';
import 'package:test/test.dart';

import 'fake_adapter.dart';
import 'result_ext.dart';

// 样本 btc_*.json（new_address、mempool_only、pending_spend 除外）取自 mempool.space
// 公共接口 2026-11-12 对公开地址的真实响应；p2pkh_doc 的地址是官方文档示例地址。
// 其余三个是按同样结构手工构造的边界样本，地址为明显的假数据。
const p2pkh = '1wiz18xYmhRX6xStj2b9t1rwWX4GKUgpv';
const p2sh = '3J98t1WpEZ73CNmQviecrnyiWrnqRhWNLy';
const bech32 = 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq';
const bech32m =
    'bc1p5d7rjq7g6rdk2yhzks9smlaqtedr4dekq08ge8ztwac72sfr9rusxg3297';
const bech32Big =
    'bc1qgdjqv0av3q56jvd82tkdjpy7gdp9ut8tlqmgrpmv24sq90ecnvqqjwvw97';
const newAddr = 'bc1qnewaddressfixture0000000000000000000000';
const mempoolOnly = 'bc1qmempoolonlyfixture000000000000000000000';
const pendingSpend = 'bc1qpendingspendfixture0000000000000000000';

String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

const addressFixtures = <String, String>{
  p2pkh: 'btc_p2pkh_doc.json',
  p2sh: 'btc_p2sh.json',
  bech32: 'btc_bech32.json',
  bech32m: 'btc_bech32m.json',
  bech32Big: 'btc_bech32_big.json',
  newAddr: 'btc_new_address.json',
  mempoolOnly: 'btc_mempool_only.json',
  pendingSpend: 'btc_pending_spend.json',
};

class FakeConfig implements DataSourceConfig {
  FakeConfig({this.custom = const {}});
  final Map<String, Uri> custom;

  @override
  Future<String?> apiKey(String providerId) async => null;

  @override
  Future<Uri?> customEndpoint(String chainId) async => custom[chainId];
}

RateLimiter fastLimiter() =>
    RateLimiter(maxRequests: 1000000, window: const Duration(seconds: 1));

/// 按路径末段（地址）返回样本；未知地址返回 400（与真实接口一致）。
ResponseBody defaultRoute(RequestOptions o, Map<String, Object?> body) {
  final name = addressFixtures[o.uri.pathSegments.last];
  if (name == null) {
    return ResponseBody.fromString('Invalid Bitcoin address', 400);
  }
  return jsonResponse(fixture(name));
}

(BitcoinChainAdapter, FakeAdapter) build({
  FakeConfig? config,
  ResponseBody Function(RequestOptions, Map<String, Object?>) route =
      defaultRoute,
  OwLogSink? onLog,
}) {
  final fake = FakeAdapter(route);
  final adapter = BitcoinChainAdapter(
    config: config ?? FakeConfig(),
    rateLimiter: fastLimiter(),
    onLog: onLog,
    clientBuilder: (c) => OwHttpClientFactory.create(c, adapter: fake),
  );
  return (adapter, fake);
}

void main() {
  final btc = Chains.byId('bitcoin');

  group('fetchHoldings', () {
    test('四种地址类型_余额均按已确认的收入减支出换算为BTC', () async {
      final (adapter, _) = build();
      final expected = {
        p2pkh: '0.00089058', // 15007688098 - 15007599040 聪
        bech32: '0.1820913', // 18223423 - 14293 聪
        bech32m: '0.00265092',
      };
      for (final e in expected.entries) {
        final list = (await adapter.fetchHoldings(e.key, btc)).valueOrNull!;
        expect(list.length, 1, reason: e.key);
        expect(list.single.token, const NativeToken('bitcoin'));
        expect(list.single.amount, Decimal.parse(e.value), reason: e.key);
        expect(list.single.symbolHint, 'BTC');
        expect(list.single.nameHint, 'Bitcoin');
      }
    });

    test('余额为零_收支相等返回空列表', () async {
      final (adapter, _) = build();
      final r = await adapter.fetchHoldings(p2sh, btc);
      expect(r.valueOrNull, isEmpty);
    });

    test('新地址_全零统计返回空列表而不是错误', () async {
      final (adapter, _) = build();
      final r = await adapter.fetchHoldings(newAddr, btc);
      expect(r.valueOrNull, isEmpty);
    });

    test('大数精度_十五万多枚BTC精确到聪', () async {
      final (adapter, _) = build();
      final list = (await adapter.fetchHoldings(bech32Big, btc)).valueOrNull!;
      // 533475984314971 - 517774975978040 = 15701008336931 聪
      expect(list.single.amount, Decimal.parse('157010.08336931'));
      expect(list.single.amount.toString(), '157010.08336931');
    });

    test('未确认部分不计入_只有内存池收入时视为零余额', () async {
      final (adapter, _) = build();
      final r = await adapter.fetchHoldings(mempoolOnly, btc);
      expect(r.valueOrNull, isEmpty);
    });

    test('未确认的支出不扣减_仍按已确认余额', () async {
      final (adapter, _) = build();
      final list = (await adapter.fetchHoldings(
        pendingSpend,
        btc,
      )).valueOrNull!;
      // 已确认：300000 - 100000 = 200000 聪；内存池里 200000 的支出不扣。
      expect(list.single.amount, Decimal.parse('0.002'));
    });

    test('请求_默认主机路径与方法正确且使用HTTPS', () async {
      final (adapter, fake) = build();
      await adapter.fetchHoldings(p2pkh, btc);
      expect(fake.requests, hasLength(1));
      final r = fake.requests.single;
      expect(r.method, 'GET');
      expect(r.uri.scheme, 'https');
      expect(r.uri.host, 'mempool.space');
      expect(r.uri.path, '/api/address/$p2pkh');
      expect(r.uri.hasQuery, isFalse);
    });

    test('自定义实例_使用配置的主机并保留路径前缀', () async {
      final (adapter, fake) = build(
        config: FakeConfig(
          custom: {'bitcoin': Uri.parse('https://my.node.example/mempool/')},
        ),
      );
      final r = await adapter.fetchHoldings(p2pkh, btc);
      expect(r.valueOrNull!.single.amount, Decimal.parse('0.00089058'));
      expect(fake.requests.single.uri.host, 'my.node.example');
      expect(fake.requests.single.uri.path, '/mempool/api/address/$p2pkh');
    });

    test('自定义实例_非https被拒绝且不发请求', () async {
      final (adapter, fake) = build(
        config: FakeConfig(
          custom: {'bitcoin': Uri.parse('http://my.node.example')},
        ),
      );
      final r = await adapter.fetchHoldings(p2pkh, btc);
      expect(r.failureOrNull, isA<ValidationFailure>());
      expect(fake.requests, isEmpty);
    });

    test('地址含路径字符_被拒绝且不发请求', () async {
      final (adapter, fake) = build();
      for (final bad in ['../x', 'a/b', 'a?b=1', '', 'a b']) {
        final r = await adapter.fetchHoldings(bad, btc);
        expect(r.failureOrNull, isA<ValidationFailure>(), reason: bad);
      }
      expect(fake.requests, isEmpty);
    });

    test('非Bitcoin链_返回不支持', () async {
      final (adapter, _) = build();
      final r = await adapter.fetchHoldings(p2pkh, Chains.byId('ethereum'));
      expect(r.failureOrNull, isA<UnsupportedFailure>());
    });
  });

  group('hasActivity', () {
    test('交易计数非零_有活动_即使余额为零', () async {
      final (adapter, _) = build();
      expect((await adapter.hasActivity(p2sh, btc)).valueOrNull, isTrue);
    });

    test('只有内存池交易_也算有活动', () async {
      final (adapter, _) = build();
      expect((await adapter.hasActivity(mempoolOnly, btc)).valueOrNull, isTrue);
    });

    test('全零统计_无活动', () async {
      final (adapter, _) = build();
      expect((await adapter.hasActivity(newAddr, btc)).valueOrNull, isFalse);
    });
  });

  group('错误映射', () {
    test('HTTP429_限频', () async {
      final (adapter, _) = build(
        route: (o, b) => ResponseBody.fromString('Too Many Requests', 429),
      );
      final r = await adapter.fetchHoldings(p2pkh, btc);
      expect(r.failureOrNull, isA<RateLimitedFailure>());
    });

    test('HTTP5xx_服务故障', () async {
      for (final status in [500, 502, 503]) {
        final (adapter, _) = build(
          route: (o, b) => ResponseBody.fromString('oops', status),
        );
        final r = await adapter.hasActivity(p2pkh, btc);
        expect(r.failureOrNull, isA<ServiceDownFailure>(), reason: '$status');
      }
    });

    test('HTTP400_地址无效的业务错误_不含地址', () async {
      // 真实接口对非法地址返回 400 与纯文本 "Invalid Bitcoin address"。
      final (adapter, _) = build();
      final r = await adapter.fetchHoldings('bc1qinvalid', btc);
      final f = r.failureOrNull!;
      expect(f, isA<ValidationFailure>());
      expect(f.detail, isNot(contains('bc1qinvalid')));
    });

    test('响应不是JSON_未知错误', () async {
      final (adapter, _) = build(
        route: (o, b) => jsonResponse('<html>not json</html>'),
      );
      final r = await adapter.fetchHoldings(p2pkh, btc);
      expect(r.failureOrNull, isA<UnknownFailure>());
    });

    test('响应缺少统计字段_未知错误', () async {
      for (final body in [
        '[]',
        '{}',
        '{"chain_stats":{"funded_txo_sum":1}}',
        '{"chain_stats":{"funded_txo_sum":"1","spent_txo_sum":0,"tx_count":1},'
            '"mempool_stats":{"tx_count":0}}',
      ]) {
        final (adapter, _) = build(route: (o, b) => jsonResponse(body));
        final r = await adapter.fetchHoldings(p2pkh, btc);
        expect(r.failureOrNull, isA<UnknownFailure>(), reason: body);
      }
    });

    test('支出大于收入_视为响应无效', () async {
      final (adapter, _) = build(
        route: (o, b) => jsonResponse(
          '{"chain_stats":{"funded_txo_sum":1,"spent_txo_sum":2,"tx_count":1},'
          '"mempool_stats":{"tx_count":0}}',
        ),
      );
      final r = await adapter.fetchHoldings(p2pkh, btc);
      expect(r.failureOrNull, isA<UnknownFailure>());
    });
  });

  test('日志_不含完整地址', () async {
    final lines = <String>[];
    final (adapter, _) = build(onLog: lines.add);
    await adapter.fetchHoldings(p2pkh, btc);
    expect(lines, isNotEmpty);
    expect(lines.join('\n'), isNot(contains(p2pkh)));
    expect(lines.join('\n'), contains('mempool.space'));
  });
}
