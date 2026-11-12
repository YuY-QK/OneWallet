import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:ow_chains/ow_chains.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:ow_net/ow_net.dart';
import 'package:test/test.dart';

import 'fake_adapter.dart';

// 地址与数值均为明显的假数据；响应结构取自 Alchemy 官方文档示例的形态，
// 其中文档未能在线核对的部分见 docs/EXTERNAL_APIS.md。
const owner = '0x1111111111111111111111111111111111111111';
const fakeKey = 'test-key-0123456789abcdef-not-real';
const c1 = '0xaaaa000000000000000000000000000000000001';
const c3 = '0xaaaa000000000000000000000000000000000003';
const c4 = '0xaaaa000000000000000000000000000000000004';
const c6 = '0xaaaa000000000000000000000000000000000006';

String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

final metadataFixture =
    jsonDecode(fixture('token_metadata.json')) as Map<String, Object?>;

class FakeConfig implements DataSourceConfig {
  FakeConfig({this.key = fakeKey, this.custom = const {}});

  final String? key;
  final Map<String, Uri> custom;

  @override
  Future<String?> apiKey(String providerId) async =>
      providerId == 'alchemy' ? key : null;

  @override
  Future<Uri?> customEndpoint(String chainId) async => custom[chainId];
}

/// 不限速的限速器，让测试不依赖真实时间。
RateLimiter fastLimiter() =>
    RateLimiter(maxRequests: 1000000, window: const Duration(seconds: 1));

/// 默认路由：余额 1 ETH，带两页代币。
ResponseBody defaultRoute(RequestOptions o, Map<String, Object?> body) {
  final params = body['params']! as List<Object?>;
  switch (body['method']) {
    case 'eth_getBalance':
      return rpcResult('0x0de0b6b3a7640000');
    case 'eth_getTransactionCount':
      return rpcResult('0x3');
    case 'alchemy_getTokenBalances':
      final opts = params[2]! as Map<String, Object?>;
      return jsonResponse(
        fixture(
          opts['pageKey'] == null
              ? 'token_balances_page1.json'
              : 'token_balances_page2.json',
        ),
      );
    case 'alchemy_getTokenMetadata':
      final m = metadataFixture[params[0]];
      return m == null ? rpcResult(null) : jsonResponse(jsonEncode(m));
  }
  return rpcError(-32601, 'method not found');
}

(EvmChainAdapter, FakeAdapter) build({
  FakeConfig? config,
  ResponseBody Function(RequestOptions, Map<String, Object?>) route =
      defaultRoute,
}) {
  final fake = FakeAdapter(route);
  final adapter = EvmChainAdapter(
    config: config ?? FakeConfig(),
    rateLimiter: fastLimiter(),
    clientBuilder: (c) => OwHttpClientFactory.create(c, adapter: fake),
  );
  return (adapter, fake);
}

void main() {
  final eth = Chains.byId('ethereum');

  group('fetchHoldings', () {
    test('正常_原生币加多页代币_数量按小数位换算', () async {
      final (adapter, fake) = build();
      final r = await adapter.fetchHoldings(owner, eth);
      final list = r.valueOrNull!;

      expect(list.first.token, const NativeToken('ethereum'));
      expect(list.first.amount, Decimal.one);
      expect(list.first.symbolHint, 'ETH');

      final byToken = {for (final h in list) h.token: h};
      // 6 位小数：0x16e360 = 1500000
      expect(
        byToken[const ContractToken('ethereum', c1)]!.amount,
        Decimal.parse('1.5'),
      );
      expect(byToken[const ContractToken('ethereum', c1)]!.symbolHint, 'FUSD');
      expect(
        byToken[const ContractToken('ethereum', c1)]!.nameHint,
        'Fake Dollar',
      );
      // 零余额与带 error 的代币不出现；大写合约地址已规范化为小写。
      expect(list.length, 5);
      // 分页：两次 getTokenBalances，第二次带 pageKey。
      final pages = [
        for (var i = 0; i < fake.bodies.length; i++)
          if (fake.bodies[i]['method'] == 'alchemy_getTokenBalances')
            (fake.bodies[i]['params']! as List<Object?>)[2]!
                as Map<String, Object?>,
      ];
      expect(pages.length, 2);
      expect(pages[0].containsKey('pageKey'), isFalse);
      expect(pages[1]['pageKey'], 'fake-page-key-0002');
    });

    test('请求_主机路径与方法正确且使用HTTPS', () async {
      final (adapter, fake) = build();
      await adapter.fetchHoldings(owner, eth);
      final first = fake.requests.first;
      expect(first.uri.scheme, 'https');
      expect(first.uri.host, 'eth-mainnet.g.alchemy.com');
      expect(first.uri.path, '/v2/$fakeKey');
      expect(first.method, 'POST');
      expect(fake.bodies.first['jsonrpc'], '2.0');
      expect(fake.bodies.first['method'], 'eth_getBalance');
      expect(fake.bodies.first['params'], [owner, 'latest']);
    });

    test('零余额_返回空列表', () async {
      final (adapter, _) = build(
        route: (o, b) => switch (b['method']) {
          'eth_getBalance' => rpcResult('0x0'),
          'alchemy_getTokenBalances' => rpcResult({
            'address': owner,
            'tokenBalances': <Object?>[],
          }),
          _ => rpcError(-32601, 'x'),
        },
      );
      final r = await adapter.fetchHoldings(owner, eth);
      expect(r.valueOrNull, isEmpty);
    });

    test('官方文档示例响应_无error字段与完整元数据可解析', () async {
      // 响应取自 Alchemy 官方文档 alchemy_getTokenBalances / getTokenMetadata
      // 的示例：条目不含 error 字段；元数据含 logo。
      final (adapter, fake) = build(
        route: (o, b) => switch (b['method']) {
          'eth_getBalance' => rpcResult('0x0'),
          'alchemy_getTokenBalances' => jsonResponse(
            fixture('doc_token_balances.json'),
          ),
          'alchemy_getTokenMetadata' => jsonResponse(
            fixture('doc_token_metadata.json'),
          ),
          _ => rpcError(-32601, 'x'),
        },
      );
      final r = await adapter.fetchHoldings(owner, eth);
      final h = r.valueOrNull!.single;
      expect(
        h.token,
        const ContractToken(
          'ethereum',
          '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
        ),
      );
      // 0x3c005f81ab00 = 65972300000000，按 6 位小数精确换算
      expect(h.amount, Decimal.parse('65972300'));
      expect(h.symbolHint, 'USDC');
      expect(h.nameHint, 'USD Coin');
      expect(fake.bodies.last['params'], [
        '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
      ]);
    });

    test('十六进制大数_超过2的64次方时精确换算', () async {
      final (adapter, _) = build(
        route: (o, b) => switch (b['method']) {
          // 0x56bc75e2d63100000 = 100 * 10^18
          'eth_getBalance' => rpcResult('0x56bc75e2d63100000'),
          'alchemy_getTokenBalances' => rpcResult({
            'address': owner,
            'tokenBalances': [
              // 2^64 + 5，18 位小数
              {
                'contractAddress': c3,
                'tokenBalance': '0x10000000000000005',
                'error': null,
              },
            ],
          }),
          'alchemy_getTokenMetadata' => jsonResponse(
            jsonEncode(metadataFixture[c3]),
          ),
          _ => rpcError(-32601, 'x'),
        },
      );
      final list = (await adapter.fetchHoldings(owner, eth)).valueOrNull!;
      expect(list[0].amount, Decimal.fromInt(100));
      // 18446744073709551621 / 10^18
      expect(list[1].amount, Decimal.parse('18.446744073709551621'));
    });

    test('小数位为0与18', () async {
      final (adapter, _) = build();
      final list = (await adapter.fetchHoldings(owner, eth)).valueOrNull!;
      final byToken = {for (final h in list) h.token: h.amount};
      // 10^30 / 10^18
      expect(
        byToken[const ContractToken('ethereum', c3)],
        Decimal.parse('1000000000000'),
      );
      expect(byToken[const ContractToken('ethereum', c4)], Decimal.fromInt(7));
    });

    test('元数据缺失_symbol为null时仍返回持仓', () async {
      final (adapter, _) = build();
      final list = (await adapter.fetchHoldings(owner, eth)).valueOrNull!;
      final h = list.firstWhere(
        (h) => h.token == const ContractToken('ethereum', c6),
      );
      expect(h.amount, Decimal.one);
      expect(h.symbolHint, isNull);
      expect(h.nameHint, isNull);
    });

    test('元数据_同一合约只查一次', () async {
      final (adapter, fake) = build();
      await adapter.fetchHoldings(owner, eth);
      final first = fake.methods
          .where((m) => m == 'alchemy_getTokenMetadata')
          .length;
      expect(first, 4); // c1、c3、c4、c6
      await adapter.fetchHoldings(owner, eth);
      final second = fake.methods
          .where((m) => m == 'alchemy_getTokenMetadata')
          .length;
      expect(second, first);
    });

    test('大量代币_元数据并发不超过上限', () async {
      var inFlight = 0;
      var peak = 0;
      final tokens = [
        for (var i = 0; i < 30; i++)
          {
            'contractAddress': '0xbbbb${i.toRadixString(16).padLeft(36, '0')}',
            'tokenBalance': '0x1',
            'error': null,
          },
      ];
      final fake = FakeAdapter((o, b) {
        switch (b['method']) {
          case 'eth_getBalance':
            return rpcResult('0x0');
          case 'alchemy_getTokenBalances':
            return rpcResult({'address': owner, 'tokenBalances': tokens});
          default:
            return rpcResult({
              'decimals': 0,
              'name': 'n',
              'symbol': 's',
              'logo': null,
            });
        }
      });
      // 用包装适配器统计并发。
      final counting = _CountingAdapter(
        fake,
        onStart: () {
          inFlight++;
          if (inFlight > peak) peak = inFlight;
        },
        onEnd: () => inFlight--,
      );
      final adapter = EvmChainAdapter(
        config: FakeConfig(),
        rateLimiter: fastLimiter(),
        metadataConcurrency: 4,
        clientBuilder: (c) => OwHttpClientFactory.create(c, adapter: counting),
      );
      final list = (await adapter.fetchHoldings(owner, eth)).valueOrNull!;
      expect(list.length, 30);
      expect(peak, lessThanOrEqualTo(4));
      expect(peak, greaterThan(1));
    });

    test('走限速器_每个请求都经过RateLimiter', () async {
      var runs = 0;
      final limiter = _CountingLimiter(() => runs++);
      final fake = FakeAdapter(defaultRoute);
      final adapter = EvmChainAdapter(
        config: FakeConfig(),
        rateLimiter: limiter,
        clientBuilder: (c) => OwHttpClientFactory.create(c, adapter: fake),
      );
      await adapter.fetchHoldings(owner, eth);
      expect(runs, fake.requests.length);
      expect(runs, greaterThan(3));
    });

    test('其他EVM链_使用各自主机', () async {
      final (adapter, fake) = build();
      for (final id in ['bsc', 'arbitrum', 'optimism', 'base', 'polygon']) {
        await adapter.fetchHoldings(owner, Chains.byId(id));
      }
      final hosts = fake.requests.map((r) => r.uri.host).toSet();
      expect(hosts, {
        'bnb-mainnet.g.alchemy.com',
        'arb-mainnet.g.alchemy.com',
        'opt-mainnet.g.alchemy.com',
        'base-mainnet.g.alchemy.com',
        'polygon-mainnet.g.alchemy.com',
      });
    });
  });

  group('失败映射', () {
    test('缺少Key_返回UnauthorizedFailure且不发请求', () async {
      final (adapter, fake) = build(config: FakeConfig(key: null));
      final r = await adapter.fetchHoldings(owner, eth);
      final f = (r as Err<List<RawHolding>>).failure;
      expect(f, isA<UnauthorizedFailure>());
      expect(f.detail, 'missing api key');
      expect(fake.requests, isEmpty);
      expect(
        ((await adapter.hasActivity(owner, eth)) as Err<bool>).failure,
        isA<UnauthorizedFailure>(),
      );
    });

    test('HTTP429_映射为RateLimitedFailure', () async {
      final (adapter, _) = build(
        route: (o, b) => jsonResponse('{}', status: 429),
      );
      final r = await adapter.fetchHoldings(owner, eth);
      expect((r as Err<List<RawHolding>>).failure, isA<RateLimitedFailure>());
    });

    test('JSON-RPC限频错误码_映射为RateLimitedFailure', () async {
      final (adapter, _) = build(
        route: (o, b) =>
            rpcError(429, 'Your app has exceeded its compute units'),
      );
      final r = await adapter.fetchHoldings(owner, eth);
      expect((r as Err<List<RawHolding>>).failure, isA<RateLimitedFailure>());
    });

    test('JSON-RPC错误对象_映射为合适的Failure且detail不含message', () async {
      Future<Failure> failureFor(int code) async {
        final (adapter, _) = build(
          route: (o, b) => rpcError(code, 'secret-ish message $fakeKey'),
        );
        final r = await adapter.fetchHoldings(owner, eth);
        return (r as Err<List<RawHolding>>).failure;
      }

      expect(await failureFor(-32601), isA<UnsupportedFailure>());
      expect(await failureFor(-32603), isA<ServiceDownFailure>());
      expect(await failureFor(-32000), isA<ServiceDownFailure>());
      expect(await failureFor(-32602), isA<UnknownFailure>());
      // 官方错误参考：-32000..-32099 均为服务端错误，-32005 没有限频含义。
      expect(await failureFor(-32005), isA<ServiceDownFailure>());
      expect(await failureFor(403), isA<UnauthorizedFailure>());
      final f = await failureFor(-32602);
      expect(f.detail, isNot(contains(fakeKey)));
      expect(f.detail, contains('-32602'));
    });

    test('HTTP401_映射为UnauthorizedFailure', () async {
      final (adapter, _) = build(
        route: (o, b) => jsonResponse('{}', status: 401),
      );
      final r = await adapter.hasActivity(owner, eth);
      expect((r as Err<bool>).failure, isA<UnauthorizedFailure>());
    });

    test('响应结构无效_UnknownFailure', () async {
      final (adapter, _) = build(route: (o, b) => jsonResponse('[1,2]'));
      final r = await adapter.fetchHoldings(owner, eth);
      expect((r as Err<List<RawHolding>>).failure, isA<UnknownFailure>());
    });

    test('代币元数据限频_整体失败而不是漏掉代币', () async {
      final (adapter, _) = build(
        route: (o, b) => b['method'] == 'alchemy_getTokenMetadata'
            ? jsonResponse('{}', status: 429)
            : defaultRoute(o, b),
      );
      final r = await adapter.fetchHoldings(owner, eth);
      expect((r as Err<List<RawHolding>>).failure, isA<RateLimitedFailure>());
    });

    test('不支持的链_UnsupportedFailure', () async {
      final (adapter, fake) = build();
      final r = await adapter.fetchHoldings(owner, Chains.byId('bitcoin'));
      expect((r as Err<List<RawHolding>>).failure, isA<UnsupportedFailure>());
      expect(fake.requests, isEmpty);
    });

    test('Failure的detail不含完整地址与Key', () async {
      final (adapter, _) = build(
        route: (o, b) => rpcError(-32602, 'bad $owner'),
      );
      final r = await adapter.fetchHoldings(owner, eth);
      final detail = (r as Err<List<RawHolding>>).failure.detail!;
      expect(detail, isNot(contains(owner)));
      expect(detail, isNot(contains(fakeKey)));
    });
  });

  group('自定义节点', () {
    test('配置了自定义RPC_只查原生币且不需要Key', () async {
      final (adapter, fake) = build(
        config: FakeConfig(
          key: null,
          custom: {'ethereum': Uri.parse('https://rpc.example.invalid/path')},
        ),
      );
      final r = await adapter.fetchHoldings(owner, eth);
      final list = r.valueOrNull!;
      expect(list.length, 1);
      expect(list.single.token, const NativeToken('ethereum'));
      expect(fake.methods, ['eth_getBalance']);
      expect(fake.requests.single.uri.host, 'rpc.example.invalid');
      expect(fake.requests.single.uri.path, '/path');
    });

    test('自定义节点_非https被拒绝', () async {
      final (adapter, fake) = build(
        config: FakeConfig(
          custom: {'ethereum': Uri.parse('http://rpc.invalid/')},
        ),
      );
      final r = await adapter.fetchHoldings(owner, eth);
      expect((r as Err<List<RawHolding>>).failure, isA<ValidationFailure>());
      expect(fake.requests, isEmpty);
    });

    test('自定义节点_让Alchemy不支持的链也可查询原生币', () async {
      // 假设某链不在内置表中：用只有自定义节点的 EVM 链信息。
      const odd = ChainInfo(
        id: 'oddchain',
        family: ChainFamily.evm,
        name: 'Odd',
        nativeSymbol: 'ODD',
        nativeDecimals: 18,
        evmChainId: 999999,
        explorerAddressUrl: 'https://example.invalid/{address}',
      );
      final (plain, _) = build();
      final unsupported = await plain.fetchHoldings(owner, odd);
      expect(
        (unsupported as Err<List<RawHolding>>).failure,
        isA<UnsupportedFailure>(),
      );
      final (custom, _) = build(
        config: FakeConfig(
          custom: {'oddchain': Uri.parse('https://rpc.example.invalid/')},
        ),
      );
      final ok = await custom.fetchHoldings(owner, odd);
      expect(ok.valueOrNull!.single.symbolHint, 'ODD');
    });
  });

  group('hasActivity', () {
    test('余额非零_true且不查交易计数', () async {
      final (adapter, fake) = build();
      final r = await adapter.hasActivity(owner, eth);
      expect(r.valueOrNull, isTrue);
      expect(fake.methods, ['eth_getBalance']);
    });

    test('余额为零但交易计数非零_true', () async {
      final (adapter, _) = build(
        route: (o, b) => b['method'] == 'eth_getBalance'
            ? rpcResult('0x0')
            : rpcResult('0x2'),
      );
      expect((await adapter.hasActivity(owner, eth)).valueOrNull, isTrue);
    });

    test('余额与交易计数都为零_false', () async {
      final (adapter, _) = build(route: (o, b) => rpcResult('0x0'));
      expect((await adapter.hasActivity(owner, eth)).valueOrNull, isFalse);
    });

    test('不支持的链_UnsupportedFailure', () async {
      final (adapter, _) = build();
      final r = await adapter.hasActivity(owner, Chains.byId('solana'));
      expect((r as Err<bool>).failure, isA<UnsupportedFailure>());
    });
  });
}

/// 统计并发请求数的适配器包装。
class _CountingAdapter implements HttpClientAdapter {
  _CountingAdapter(this.inner, {required this.onStart, required this.onEnd});

  final FakeAdapter inner;
  final void Function() onStart;
  final void Function() onEnd;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    onStart();
    try {
      // 让出事件循环，使并发的请求真正重叠。
      await Future<void>.delayed(const Duration(milliseconds: 2));
      return await inner.fetch(
        options,
        requestStream?.map((c) => c is Uint8List ? c : Uint8List.fromList(c)),
        cancelFuture,
      );
    } finally {
      onEnd();
    }
  }

  @override
  void close({bool force = false}) {}
}

class _CountingLimiter extends RateLimiter {
  _CountingLimiter(this.onRun)
    : super(maxRequests: 1000000, window: const Duration(seconds: 1));

  final void Function() onRun;

  @override
  Future<T> run<T>(Future<T> Function() task) {
    onRun();
    return super.run(task);
  }
}
