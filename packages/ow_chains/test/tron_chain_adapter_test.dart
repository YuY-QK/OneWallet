import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:ow_chains/ow_chains.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:ow_net/ow_net.dart';
import 'package:test/test.dart';

import 'fake_adapter.dart';
import 'result_ext.dart';

// 账户样本 tron_account_doc.json 取自 TronGrid 官方文档的示例响应；
// trc20 余额与合约信息样本按文档示例的结构整理（TXYZ… 取自文档的 Nile 示例）；
// 其余为假数据。见 docs/EXTERNAL_APIS.md。
const owner = 'TUoHaVjx7n5xz8LwPRDckgFrDWhMhuSuJM'; // 文档示例地址
const fakeKey = 'test-key-0123456789abcdef-not-real';
const usdt = 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t';
const docToken = 'TXYZopYRdj2D9XRtbG411XZZ3kM5VkAeBf';
const noInfo = 'TNoInfoTokenFixture22222222222222222';
const bigToken = 'TBigTokenFixture1111111111111111111';

String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

class FakeConfig implements DataSourceConfig {
  FakeConfig({this.key, this.custom = const {}});
  final String? key;
  final Map<String, Uri> custom;

  @override
  Future<String?> apiKey(String providerId) async =>
      providerId == 'trongrid' ? key : null;

  @override
  Future<Uri?> customEndpoint(String chainId) async => custom[chainId];
}

RateLimiter fastLimiter() =>
    RateLimiter(maxRequests: 1000000, window: const Duration(seconds: 1));

ResponseBody defaultRoute(RequestOptions o, Map<String, Object?> body) {
  final p = o.uri.path;
  if (p == '/v1/accounts/$owner') {
    return jsonResponse(fixture('tron_account_doc.json'));
  }
  if (p == '/v1/accounts/$owner/trc20/balance') {
    return jsonResponse(
      fixture(
        o.uri.queryParameters.containsKey('fingerprint')
            ? 'tron_trc20_page2.json'
            : 'tron_trc20_page1.json',
      ),
    );
  }
  if (p == '/v1/trc20/info') {
    return jsonResponse(fixture('tron_trc20_info.json'));
  }
  return ResponseBody.fromString('{}', 404);
}

(TronChainAdapter, FakeAdapter) build({
  FakeConfig? config,
  Map<String, int> known = const {usdt: 6},
  ResponseBody Function(RequestOptions, Map<String, Object?>) route =
      defaultRoute,
  OwLogSink? onLog,
}) {
  final fake = FakeAdapter(route);
  final adapter = TronChainAdapter(
    config: config ?? FakeConfig(),
    knownDecimals: known,
    rateLimiter: fastLimiter(),
    onLog: onLog,
    clientBuilder: (c) => OwHttpClientFactory.create(c, adapter: fake),
  );
  return (adapter, fake);
}

/// 账户 + 空的 trc20 余额。
ResponseBody Function(RequestOptions, Map<String, Object?>) accountOnly(
  String accountFixture,
) => (o, b) {
  if (o.uri.path.endsWith('/trc20/balance')) {
    return jsonResponse('{"data":[],"success":true,"meta":{"page_size":0}}');
  }
  return jsonResponse(fixture(accountFixture));
};

void main() {
  final tron = Chains.byId('tron');
  RawHolding find(List<RawHolding> l, TokenRef t) =>
      l.firstWhere((h) => h.token == t);

  group('fetchHoldings', () {
    test('正常_TRX加多页TRC-20_数量按小数位换算', () async {
      final (adapter, fake) = build();
      final list = (await adapter.fetchHoldings(owner, tron)).valueOrNull!;

      expect(list.first.token, const NativeToken('tron'));
      expect(list.first.amount, Decimal.one); // 1000000 sun
      expect(list.first.symbolHint, 'TRX');

      // 内置表中的 USDT：1500000 / 10^6
      final u = find(list, const ContractToken('tron', usdt));
      expect(u.amount, Decimal.parse('1.5'));
      expect(u.symbolHint, isNull); // 已知合约不取符号提示
      // 文档示例：4999997900 / 10^6 = 4999.9979，符号与名称取自合约信息
      final d = find(list, const ContractToken('tron', docToken));
      expect(d.amount, Decimal.parse('4999.9979'));
      expect(d.symbolHint, 'USDT');
      expect(d.nameHint, 'Tether USD');
      // 第二页的大数：18 位小数
      final big = find(list, const ContractToken('tron', bigToken));
      expect(big.amount.toString(), '123.456789123456789012');
      // 余额为 0 的合约、查不到 decimals 的合约不出现
      expect(list.length, 4);
      expect(
        list.any((h) => h.token == const ContractToken('tron', noInfo)),
        isFalse,
      );

      // 分页：第二次带 fingerprint；合约信息只查不在内置表里的合约。
      final balanceReqs = fake.requests
          .where((r) => r.uri.path.endsWith('/trc20/balance'))
          .toList();
      expect(balanceReqs.length, 2);
      expect(balanceReqs[0].uri.queryParameters, {'limit': '200'});
      expect(
        balanceReqs[1].uri.queryParameters['fingerprint'],
        'fixture-fingerprint-0002',
      );
      final infoReq = fake.requests.singleWhere(
        (r) => r.uri.path == '/v1/trc20/info',
      );
      final asked = infoReq.uri.queryParameters['contract_list']!.split(',');
      expect(asked, isNot(contains(usdt)));
      expect(asked.toSet(), {docToken, noInfo, bigToken});
    });

    test('请求_主机路径与方法正确且使用HTTPS', () async {
      final (adapter, fake) = build();
      await adapter.fetchHoldings(owner, tron);
      final first = fake.requests.first;
      expect(first.method, 'GET');
      expect(first.uri.scheme, 'https');
      expect(first.uri.host, 'api.trongrid.io');
      expect(first.uri.path, '/v1/accounts/$owner');
    });

    test('knownDecimals覆盖全部合约_不查合约信息', () async {
      final (adapter, fake) = build(
        known: {usdt: 6, docToken: 6, noInfo: 2, bigToken: 18},
      );
      final list = (await adapter.fetchHoldings(owner, tron)).valueOrNull!;
      expect(list.length, 5);
      expect(
        find(list, const ContractToken('tron', noInfo)).amount,
        Decimal.parse('0.42'),
      );
      expect(fake.requests.any((r) => r.uri.path == '/v1/trc20/info'), isFalse);
    });

    test('合约信息有内存缓存_第二次同步不再查询', () async {
      final (adapter, fake) = build();
      await adapter.fetchHoldings(owner, tron);
      await adapter.fetchHoldings(owner, tron);
      final infoReqs = fake.requests.where(
        (r) => r.uri.path == '/v1/trc20/info',
      );
      // 第一次：1 次（noInfo 查不到，不进缓存，所以第二次仍会查它）
      expect(infoReqs.length, 2);
      expect(infoReqs.last.uri.queryParameters['contract_list'], noInfo);
    });

    test('质押口径_计入Stake2.0的质押_委托_解锁中_不计旧版与奖励', () async {
      final (adapter, _) = build(
        route: accountOnly('tron_account_staked.json'),
      );
      final list = (await adapter.fetchHoldings(owner, tron)).valueOrNull!;
      // 可用 5 + frozenV2 100 + 20 + 委托 3 + 4 + 解锁中 7 = 139 TRX
      // （不含 allowance 999 与 Stake 1.0 的 frozen 888）
      expect(list.single.amount, Decimal.parse('139'));
    });

    test('frozenV2条目省略amount_按0处理', () async {
      final (adapter, _) = build(route: accountOnly('tron_account_doc.json'));
      final list = (await adapter.fetchHoldings(owner, tron)).valueOrNull!;
      expect(list.single.amount, Decimal.one);
    });

    test('未激活地址_data为空视为零余额而不是错误', () async {
      final (adapter, _) = build(
        route: accountOnly('tron_account_inactive.json'),
      );
      final r = await adapter.fetchHoldings(owner, tron);
      expect(r.valueOrNull, isEmpty);
    });

    test('缺少balance字段_按0处理', () async {
      final (adapter, _) = build(
        route: (o, b) => o.uri.path.endsWith('/trc20/balance')
            ? jsonResponse('{"data":[],"success":true}')
            : jsonResponse('{"data":[{"address":"41x"}],"success":true}'),
      );
      expect((await adapter.fetchHoldings(owner, tron)).valueOrNull, isEmpty);
    });
  });

  group('密钥与端点', () {
    test('配置了Key_默认主机带TRON-PRO-API-KEY请求头', () async {
      final (adapter, fake) = build(config: FakeConfig(key: fakeKey));
      await adapter.fetchHoldings(owner, tron);
      for (final r in fake.requests) {
        expect(r.headers['TRON-PRO-API-KEY'], fakeKey);
        expect(r.uri.queryParameters.values, isNot(contains(fakeKey)));
      }
    });

    test('无Key_可用且不带该请求头', () async {
      final (adapter, fake) = build();
      final r = await adapter.fetchHoldings(owner, tron);
      expect(r.valueOrNull, isNotEmpty);
      expect(
        fake.requests.first.headers.containsKey('TRON-PRO-API-KEY'),
        isFalse,
      );
    });

    test('自定义节点_使用它且不发送Key', () async {
      final (adapter, fake) = build(
        config: FakeConfig(
          key: fakeKey,
          custom: {'tron': Uri.parse('https://tron.custom.example/grid/')},
        ),
      );
      await adapter.fetchHoldings(owner, tron);
      final first = fake.requests.first;
      expect(first.uri.host, 'tron.custom.example');
      expect(first.uri.path, '/grid/v1/accounts/$owner');
      for (final r in fake.requests) {
        expect(r.headers.containsKey('TRON-PRO-API-KEY'), isFalse);
      }
    });

    test('自定义节点非https_被拒绝且不发请求', () async {
      final (adapter, fake) = build(
        config: FakeConfig(custom: {'tron': Uri.parse('http://x.example')}),
      );
      final r = await adapter.fetchHoldings(owner, tron);
      expect(r.failureOrNull, isA<ValidationFailure>());
      expect(fake.requests, isEmpty);
    });

    test('日志_Key只保留前4位且不含完整地址', () async {
      final lines = <String>[];
      final (adapter, _) = build(
        config: FakeConfig(key: fakeKey),
        onLog: lines.add,
      );
      await adapter.fetchHoldings(owner, tron);
      final text = lines.join('\n');
      expect(text, isNot(contains(fakeKey)));
      expect(text, isNot(contains(owner)));
      expect(text, contains('test***'));
    });

    test('地址含路径字符_被拒绝且不发请求', () async {
      final (adapter, fake) = build();
      final r = await adapter.fetchHoldings('../x', tron);
      expect(r.failureOrNull, isA<ValidationFailure>());
      expect(fake.requests, isEmpty);
    });

    test('非Tron链_返回不支持', () async {
      final (adapter, _) = build();
      final r = await adapter.fetchHoldings(owner, Chains.byId('bitcoin'));
      expect(r.failureOrNull, isA<UnsupportedFailure>());
    });
  });

  group('hasActivity', () {
    test('账户已激活_有活动', () async {
      final (adapter, fake) = build();
      expect((await adapter.hasActivity(owner, tron)).valueOrNull, isTrue);
      expect(fake.requests.length, 1);
    });

    test('未激活_无活动', () async {
      final (adapter, _) = build(
        route: accountOnly('tron_account_inactive.json'),
      );
      expect((await adapter.hasActivity(owner, tron)).valueOrNull, isFalse);
    });
  });

  group('错误映射', () {
    test('HTTP429_限频', () async {
      final (adapter, _) = build(
        route: (o, b) => ResponseBody.fromString(
          '{"success":false,"error":"The key exceeds the frequency limit","statusCode":429}',
          429,
        ),
      );
      expect(
        (await adapter.fetchHoldings(owner, tron)).failureOrNull,
        isA<RateLimitedFailure>(),
      );
    });

    test('HTTP403_按凭据问题处理', () async {
      final (adapter, _) = build(
        route: (o, b) => ResponseBody.fromString('{}', 403),
      );
      expect(
        (await adapter.hasActivity(owner, tron)).failureOrNull,
        isA<UnauthorizedFailure>(),
      );
    });

    test('HTTP5xx_服务故障', () async {
      final (adapter, _) = build(
        route: (o, b) => ResponseBody.fromString('oops', 502),
      );
      expect(
        (await adapter.fetchHoldings(owner, tron)).failureOrNull,
        isA<ServiceDownFailure>(),
      );
    });

    test('HTTP400_地址无效的业务错误_不含地址', () async {
      final (adapter, _) = build(
        route: (o, b) => ResponseBody.fromString(
          '{"success":false,"error":"A valid account address is required.","statusCode":400}',
          400,
        ),
      );
      final f = (await adapter.fetchHoldings(owner, tron)).failureOrNull!;
      expect(f, isA<ValidationFailure>());
      expect(f.detail, isNot(contains(owner)));
    });

    test('200但success为false_按statusCode映射', () async {
      for (final (code, type) in <(int, Type)>[
        (429, RateLimitedFailure),
        (403, UnauthorizedFailure),
        (503, ServiceDownFailure),
        (400, ValidationFailure),
      ]) {
        final (adapter, _) = build(
          route: (o, b) =>
              jsonResponse('{"success":false,"error":"x","statusCode":$code}'),
        );
        final f = (await adapter.hasActivity(owner, tron)).failureOrNull!;
        expect(f.runtimeType, type, reason: '$code');
      }
    });

    test('响应结构无效_未知错误', () async {
      for (final body in ['[]', '{}', '{"data":"x"}', '{"data":[1]}']) {
        final (adapter, _) = build(route: (o, b) => jsonResponse(body));
        expect(
          (await adapter.fetchHoldings(owner, tron)).failureOrNull,
          isA<UnknownFailure>(),
          reason: body,
        );
      }
    });

    test('TRC-20余额响应结构无效_未知错误', () async {
      final (adapter, _) = build(
        route: (o, b) => o.uri.path.endsWith('/trc20/balance')
            ? jsonResponse('{"data":"oops"}')
            : defaultRoute(o, b),
      );
      expect(
        (await adapter.fetchHoldings(owner, tron)).failureOrNull,
        isA<UnknownFailure>(),
      );
    });

    test('合约信息接口限频_整体失败', () async {
      final (adapter, _) = build(
        route: (o, b) => o.uri.path == '/v1/trc20/info'
            ? ResponseBody.fromString('{}', 429)
            : defaultRoute(o, b),
      );
      expect(
        (await adapter.fetchHoldings(owner, tron)).failureOrNull,
        isA<RateLimitedFailure>(),
      );
    });

    test('合约信息接口普通错误_只跳过未知decimals的代币', () async {
      final (adapter, _) = build(
        route: (o, b) => o.uri.path == '/v1/trc20/info'
            ? ResponseBody.fromString('{}', 400)
            : defaultRoute(o, b),
      );
      final list = (await adapter.fetchHoldings(owner, tron)).valueOrNull!;
      // TRX 与内置表中的 USDT 保留
      expect(list.length, 2);
    });

    test('分页超过上限_未知错误', () async {
      final fake = FakeAdapter(
        (o, b) => o.uri.path.endsWith('/trc20/balance')
            ? jsonResponse(
                '{"data":[],"success":true,"meta":{"fingerprint":"again"}}',
              )
            : jsonResponse(fixture('tron_account_doc.json')),
      );
      final adapter = TronChainAdapter(
        config: FakeConfig(),
        maxPages: 3,
        rateLimiter: fastLimiter(),
        clientBuilder: (c) => OwHttpClientFactory.create(c, adapter: fake),
      );
      expect(
        (await adapter.fetchHoldings(owner, tron)).failureOrNull,
        isA<UnknownFailure>(),
      );
    });
  });
}
