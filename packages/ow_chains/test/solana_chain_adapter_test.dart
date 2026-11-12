import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:ow_chains/ow_chains.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:ow_net/ow_net.dart';
import 'package:test/test.dart';

import 'fake_adapter.dart';
import 'result_ext.dart';

// 响应结构按 Helius 文档对 getBalance、getTokenAccountsByOwner（jsonParsed）、
// getSignaturesForAddress 的描述整理；地址与账户为假数据，mint 中的 USDC、USDT、
// PYUSD 是真实 mint，其余为假。solana.com 文档当时无法访问，见 EXTERNAL_APIS.md。
const owner = '9xQeWvG816bUx9EPjHmaT23yvVM2ZWbrrpZb9PusVFin';
const fakeKey = 'test-key-0123456789abcdef-not-real';
const usdc = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';
const pyusd = '2b1kV6DkPAnxd5ixfnxCpjxmKwqjjaYmCZfHsFu24GXo';
const unknownMint = 'UnknownMintFixture000000000000000000000001';
const supplyMint = 'SupplyFixtureMint00000000000000000000000001';

String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

class FakeConfig implements DataSourceConfig {
  FakeConfig({this.key, this.custom = const {}});
  final String? key;
  final Map<String, Uri> custom;

  @override
  Future<String?> apiKey(String providerId) async =>
      providerId == 'helius' ? key : null;

  @override
  Future<Uri?> customEndpoint(String chainId) async => custom[chainId];
}

RateLimiter fastLimiter() =>
    RateLimiter(maxRequests: 1000000, window: const Duration(seconds: 1));

ResponseBody balance(int lamports) => rpcResult({
  'context': {'slot': 1},
  'value': lamports,
});

/// 没有任何代币账户的 getTokenAccountsByOwner 响应。
ResponseBody emptyAccounts() => rpcResult(<String, Object?>{
  'context': <String, Object?>{'slot': 1},
  'value': <Object?>[],
});

/// 默认路由：1.5 SOL，两个 programId 各有代币账户。
ResponseBody defaultRoute(RequestOptions o, Map<String, Object?> body) {
  final params = body['params']! as List<Object?>;
  switch (body['method']) {
    case 'getBalance':
      return balance(1500000000);
    case 'getTokenAccountsByOwner':
      final filter = params[1]! as Map<String, Object?>;
      return jsonResponse(
        fixture(
          filter['programId'] == SolanaChainAdapter.token2022ProgramId
              ? 'sol_token_accounts_token2022.json'
              : 'sol_token_accounts_token_program.json',
        ),
      );
    case 'getSignaturesForAddress':
      return rpcResult([
        {'signature': 'sigFixture', 'slot': 1, 'err': null, 'memo': null},
      ]);
  }
  return rpcError(-32601, 'method not found');
}

(SolanaChainAdapter, FakeAdapter) build({
  FakeConfig? config,
  ResponseBody Function(RequestOptions, Map<String, Object?>) route =
      defaultRoute,
  OwLogSink? onLog,
}) {
  final fake = FakeAdapter(route);
  final adapter = SolanaChainAdapter(
    config: config ?? FakeConfig(),
    rateLimiter: fastLimiter(),
    onLog: onLog,
    clientBuilder: (c) => OwHttpClientFactory.create(c, adapter: fake),
  );
  return (adapter, fake);
}

void main() {
  final sol = Chains.byId('solana');

  group('fetchHoldings', () {
    test('正常_原生币加两个程序的代币_按小数位换算且同mint合并', () async {
      final (adapter, _) = build();
      final list = (await adapter.fetchHoldings(owner, sol)).valueOrNull!;
      final byToken = {for (final h in list) h.token: h};

      expect(list.first.token, const NativeToken('solana'));
      expect(list.first.amount, Decimal.parse('1.5'));
      expect(list.first.symbolHint, 'SOL');

      // 同一 USDC mint 的两个账户合并：1500000 + 2500001 = 4000001（6 位小数）
      expect(
        byToken[const ContractToken('solana', usdc)]!.amount,
        Decimal.parse('4.000001'),
      );
      // Token-2022 的 PYUSD
      expect(
        byToken[const ContractToken('solana', pyusd)]!.amount,
        Decimal.parse('5'),
      );
      // 0 位小数的同质化代币（数量 1000）保留
      expect(
        byToken[const ContractToken('solana', supplyMint)]!.amount,
        Decimal.parse('1000'),
      );
      // 原生币 + USDC + PYUSD + unknown + supply；零余额、NFT、坏账户不出现
      expect(list.length, 5);
    });

    test('代币不带符号和名称提示', () async {
      final (adapter, _) = build();
      final list = (await adapter.fetchHoldings(owner, sol)).valueOrNull!;
      for (final h in list.skip(1)) {
        expect(h.symbolHint, isNull);
        expect(h.nameHint, isNull);
      }
    });

    test('大数精度_不经过浮点', () async {
      final (adapter, _) = build();
      final list = (await adapter.fetchHoldings(owner, sol)).valueOrNull!;
      final unknown = list.firstWhere(
        (h) => h.token == const ContractToken('solana', unknownMint),
      );
      // 123456789123456789 / 10^9；uiAmount 的 double 已无法精确表示
      expect(unknown.amount.toString(), '123456789.123456789');

      final (big, _) = build(
        route: (o, b) => b['method'] == 'getBalance'
            ? balance(123456789012345678)
            : emptyAccounts(),
      );
      final r = (await big.fetchHoldings(owner, sol)).valueOrNull!;
      expect(r.single.amount.toString(), '123456789.012345678');
    });

    test('NFT过滤_0位小数且数量为1的mint不返回', () async {
      final (adapter, _) = build();
      final list = (await adapter.fetchHoldings(owner, sol)).valueOrNull!;
      expect(
        list.any((h) => h.token.toString().contains('NftMintFixture')),
        isFalse,
      );
    });

    test('零余额且无代币账户_返回空列表', () async {
      final (adapter, _) = build(
        route: (o, b) =>
            b['method'] == 'getBalance' ? balance(0) : emptyAccounts(),
      );
      expect((await adapter.fetchHoldings(owner, sol)).valueOrNull, isEmpty);
    });

    test('只有代币没有SOL_只返回代币', () async {
      final (adapter, _) = build(
        route: (o, b) =>
            b['method'] == 'getBalance' ? balance(0) : defaultRoute(o, b),
      );
      final list = (await adapter.fetchHoldings(owner, sol)).valueOrNull!;
      expect(list.any((h) => h.token is NativeToken), isFalse);
      expect(list, isNotEmpty);
    });

    test('请求_方法参数与两个programId', () async {
      final (adapter, fake) = build();
      await adapter.fetchHoldings(owner, sol);
      expect(fake.methods, [
        'getBalance',
        'getTokenAccountsByOwner',
        'getTokenAccountsByOwner',
      ]);
      expect(fake.bodies[0]['params'], [
        owner,
        {'commitment': 'finalized'},
      ]);
      expect(fake.bodies[1]['params'], [
        owner,
        {'programId': 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA'},
        {'encoding': 'jsonParsed', 'commitment': 'finalized'},
      ]);
      expect(
        ((fake.bodies[2]['params']! as List<Object?>)[1]!
            as Map<String, Object?>)['programId'],
        'TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb',
      );
      expect(fake.bodies.first['jsonrpc'], '2.0');
    });
  });

  group('端点选择', () {
    test('无Key_使用官方公共RPC且不带查询参数', () async {
      final (adapter, fake) = build();
      await adapter.fetchHoldings(owner, sol);
      final u = fake.requests.first.uri;
      expect(u.scheme, 'https');
      expect(u.host, 'api.mainnet-beta.solana.com');
      expect(u.hasQuery, isFalse);
      expect(fake.requests.first.method, 'POST');
    });

    test('配置了Helius Key_使用Helius并把Key放在api-key查询参数', () async {
      final (adapter, fake) = build(config: FakeConfig(key: fakeKey));
      await adapter.fetchHoldings(owner, sol);
      final u = fake.requests.first.uri;
      expect(u.host, 'mainnet.helius-rpc.com');
      expect(u.queryParameters, {'api-key': fakeKey});
      // 请求体里不带 Key
      expect(jsonEncode(fake.bodies), isNot(contains(fakeKey)));
    });

    test('自定义节点优先级最高_查询串原样保留', () async {
      final (adapter, fake) = build(
        config: FakeConfig(
          key: fakeKey,
          custom: {
            'solana': Uri.parse(
              'https://rpc.custom.example/v1?token=abc123xyz',
            ),
          },
        ),
      );
      await adapter.fetchHoldings(owner, sol);
      final u = fake.requests.first.uri;
      expect(u.host, 'rpc.custom.example');
      expect(u.path, '/v1');
      expect(u.queryParameters, {'token': 'abc123xyz'});
    });

    test('自定义节点非https_被拒绝且不发请求', () async {
      final (adapter, fake) = build(
        config: FakeConfig(
          custom: {'solana': Uri.parse('http://rpc.custom.example')},
        ),
      );
      final r = await adapter.fetchHoldings(owner, sol);
      expect(r.failureOrNull, isA<ValidationFailure>());
      expect(fake.requests, isEmpty);
    });

    test('日志_Key与完整地址不出现', () async {
      final lines = <String>[];
      final (adapter, _) = build(
        config: FakeConfig(key: fakeKey),
        onLog: lines.add,
      );
      await adapter.fetchHoldings(owner, sol);
      final text = lines.join('\n');
      expect(lines, isNotEmpty);
      expect(text, isNot(contains(fakeKey)));
      expect(text, contains('api-key=test***'));
    });

    test('日志_自定义节点的查询参数名按敏感信息脱敏', () async {
      final lines = <String>[];
      final (adapter, _) = build(
        config: FakeConfig(
          custom: {
            'solana': Uri.parse(
              'https://rpc.custom.example/?auth=abcdefghijkl',
            ),
          },
        ),
        onLog: lines.add,
      );
      await adapter.fetchHoldings(owner, sol);
      expect(lines.join('\n'), isNot(contains('abcdefghijkl')));
    });

    test('地址含路径字符_被拒绝且不发请求', () async {
      final (adapter, fake) = build();
      final r = await adapter.fetchHoldings('../x', sol);
      expect(r.failureOrNull, isA<ValidationFailure>());
      expect(fake.requests, isEmpty);
    });

    test('非Solana链_返回不支持', () async {
      final (adapter, _) = build();
      final r = await adapter.fetchHoldings(owner, Chains.byId('bitcoin'));
      expect(r.failureOrNull, isA<UnsupportedFailure>());
    });
  });

  group('hasActivity', () {
    test('余额非零_有活动且不再查签名', () async {
      final (adapter, fake) = build();
      expect((await adapter.hasActivity(owner, sol)).valueOrNull, isTrue);
      expect(fake.methods, ['getBalance']);
    });

    test('余额为零但有签名_有活动', () async {
      final (adapter, fake) = build(
        route: (o, b) =>
            b['method'] == 'getBalance' ? balance(0) : defaultRoute(o, b),
      );
      expect((await adapter.hasActivity(owner, sol)).valueOrNull, isTrue);
      expect(fake.methods, ['getBalance', 'getSignaturesForAddress']);
      expect(fake.bodies[1]['params'], [
        owner,
        {'limit': 1, 'commitment': 'finalized'},
      ]);
    });

    test('余额为零且签名为空_无活动', () async {
      final (adapter, _) = build(
        route: (o, b) =>
            b['method'] == 'getBalance' ? balance(0) : rpcResult([]),
      );
      expect((await adapter.hasActivity(owner, sol)).valueOrNull, isFalse);
    });
  });

  group('错误映射', () {
    test('HTTP429_限频', () async {
      final (adapter, _) = build(
        route: (o, b) => ResponseBody.fromString('{}', 429),
      );
      expect(
        (await adapter.fetchHoldings(owner, sol)).failureOrNull,
        isA<RateLimitedFailure>(),
      );
    });

    test('HTTP5xx_服务故障', () async {
      final (adapter, _) = build(
        route: (o, b) => ResponseBody.fromString('oops', 503),
      );
      expect(
        (await adapter.fetchHoldings(owner, sol)).failureOrNull,
        isA<ServiceDownFailure>(),
      );
    });

    test('HTTP401_凭据无效', () async {
      final (adapter, _) = build(
        config: FakeConfig(key: fakeKey),
        route: (o, b) => ResponseBody.fromString('{}', 401),
      );
      expect(
        (await adapter.fetchHoldings(owner, sol)).failureOrNull,
        isA<UnauthorizedFailure>(),
      );
    });

    Future<Failure> failureFor(int code, String message) async {
      final (adapter, _) = build(route: (o, b) => rpcError(code, message));
      return (await adapter.fetchHoldings(owner, sol)).failureOrNull!;
    }

    test('JSON-RPC错误码_按表映射且detail不含message', () async {
      expect(
        await failureFor(-32005, 'Too many requests'),
        isA<RateLimitedFailure>(),
      );
      expect(
        await failureFor(-32005, 'Node is unhealthy'),
        isA<ServiceDownFailure>(),
      );
      expect(await failureFor(429, 'x'), isA<RateLimitedFailure>());
      expect(await failureFor(403, 'x'), isA<UnauthorizedFailure>());
      expect(await failureFor(-32601, 'x'), isA<UnsupportedFailure>());
      expect(await failureFor(-32602, 'x'), isA<ValidationFailure>());
      expect(await failureFor(-32603, 'x'), isA<ServiceDownFailure>());
      expect(await failureFor(-32009, 'x'), isA<ServiceDownFailure>());
      expect(await failureFor(-1, 'x'), isA<UnknownFailure>());

      final f = await failureFor(-32602, 'Invalid param: $owner');
      expect(f.detail, contains('code=-32602'));
      expect(f.detail, isNot(contains(owner)));
    });

    test('响应结构无效_未知错误', () async {
      for (final body in [
        '[]',
        '{"jsonrpc":"2.0","id":1}',
        '{"jsonrpc":"2.0","id":1,"result":"x"}',
      ]) {
        final (adapter, _) = build(route: (o, b) => jsonResponse(body));
        expect(
          (await adapter.fetchHoldings(owner, sol)).failureOrNull,
          isA<UnknownFailure>(),
          reason: body,
        );
      }
    });

    test('代币账户响应结构无效_未知错误', () async {
      final (adapter, _) = build(
        route: (o, b) => b['method'] == 'getBalance'
            ? balance(1)
            : rpcResult({'value': 'oops'}),
      );
      expect(
        (await adapter.fetchHoldings(owner, sol)).failureOrNull,
        isA<UnknownFailure>(),
      );
    });

    test('hasActivity_签名响应无效_未知错误', () async {
      final (adapter, _) = build(
        route: (o, b) =>
            b['method'] == 'getBalance' ? balance(0) : rpcResult('oops'),
      );
      expect(
        (await adapter.hasActivity(owner, sol)).failureOrNull,
        isA<UnknownFailure>(),
      );
    });
  });
}
