import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:ow_net/ow_net.dart';
import 'package:ow_pricing/ow_pricing.dart';
import 'package:test/test.dart';

import '../support/fakes.dart';

const _btc = Asset(
  id: 'BTC',
  symbol: 'BTC',
  name: 'Bitcoin',
  priceId: 'bitcoin',
);
const _eth = Asset(
  id: 'ETH',
  symbol: 'ETH',
  name: 'Ethereum',
  priceId: 'ethereum',
);
const _usdt = Asset(
  id: 'USDT',
  symbol: 'USDT',
  name: 'Tether USD',
  priceId: 'tether',
);
const _noPrice = Asset(id: 'XYZ', symbol: 'XYZ', name: 'No price');

void main() {
  late FakeClock clock;
  late FakeConfig config;

  setUp(() {
    clock = FakeClock(DateTime.utc(2026, 11, 11, 12));
    config = FakeConfig();
  });

  CoinGeckoPriceSource build(
    FakeAdapter adapter, {
    int maxIds = 100,
    int maxLookups = 20,
    AssetCatalog? catalog,
  }) => CoinGeckoPriceSource(
    config: config,
    clock: clock,
    catalog: catalog,
    client: OwHttpClientFactory.create(
      const OwHttpConfig(baseUrl: CoinGeckoPriceSource.baseUrl),
      adapter: adapter,
    ),
    rateLimiter: RateLimiter(
      maxRequests: 1000,
      window: const Duration(minutes: 1),
    ),
    maxIdsPerRequest: maxIds,
    maxLookupsPerCall: maxLookups,
  );

  group('fetchPrices', () {
    test('解析价格、24 小时涨跌与更新时间，请求参数正确', () async {
      final adapter = FakeAdapter(
        (_) => jsonBody(fixture('simple_price_usd.json')),
      );
      final result = await build(adapter)
          .fetchPrices({_btc, _eth, _usdt}, Quote.usd);

      final prices = {
        for (final p in (result as Ok<List<Price>>).value) p.assetId: p,
      };
      expect(prices.keys, {'BTC', 'ETH', 'USDT'});
      // 价格按 JSON 原文构造，没有经过 double
      expect(prices['BTC']!.price, Decimal.parse('67187.3358936566'));
      expect(prices['BTC']!.price.toString(), '67187.3358936566');
      expect(
        prices['BTC']!.change24hPercent,
        Decimal.parse('3.63727894677354'),
      );
      expect(prices['BTC']!.quote, Quote.usd);
      expect(prices['ETH']!.change24hPercent, Decimal.parse('-1.25'));
      expect(prices['USDT']!.price, Decimal.parse('0.999877'));
      expect(prices['USDT']!.change24hPercent, Decimal.zero);
      expect(
        prices['BTC']!.updatedAt,
        DateTime.fromMillisecondsSinceEpoch(1711356300 * 1000, isUtc: true),
      );

      expect(adapter.requests, hasLength(1));
      final req = adapter.requests.single;
      expect(req.uri.path, '/api/v3/simple/price');
      expect(req.uri.host, 'api.coingecko.com');
      expect(req.uri.scheme, 'https');
      expect(idsOf(req), ['bitcoin', 'ethereum', 'tether']);
      expect(req.queryParameters['vs_currencies'], 'usd');
      expect(req.queryParameters['include_24hr_change'], 'true');
      expect(req.queryParameters['precision'], 'full');
    });

    test('官方文档示例响应：整数价格与带额外字段的结构可解析', () async {
      // 响应取自 CoinGecko 官方 /simple/price 示例（含市值、成交量等本实现不用的字段）。
      final adapter = FakeAdapter(
        (_) => jsonBody(fixture('simple_price_doc.json')),
      );
      final result = await build(adapter).fetchPrices({_btc}, Quote.usd);
      final p = (result as Ok<List<Price>>).value.single;
      expect(p.price, Decimal.parse('76975'));
      expect(p.change24hPercent, Decimal.parse('-1.4093297098441402'));
      expect(
        p.updatedAt,
        DateTime.fromMillisecondsSinceEpoch(1779092258 * 1000, isUtc: true),
      );
    });

    test('CNY 报价读取 cny 字段', () async {
      final adapter = FakeAdapter(
        (_) => jsonBody(fixture('simple_price_cny.json')),
      );
      final result = await build(adapter).fetchPrices({_btc}, Quote.cny);
      final price = (result as Ok<List<Price>>).value.single;
      expect(price.quote, Quote.cny);
      expect(price.price, Decimal.parse('486012.52'));
      expect(price.change24hPercent, Decimal.parse('3.63727894677354'));
      expect(adapter.requests.single.queryParameters['vs_currencies'], 'cny');
    });

    test('指数写法的价格精确展开', () async {
      final adapter = FakeAdapter(
        (_) => jsonBody(fixture('simple_price_exponent.json')),
      );
      const pepe = Asset(
        id: 'PEPE',
        symbol: 'PEPE',
        name: 'Pepe',
        priceId: 'pepe',
      );
      final result = await build(adapter).fetchPrices({pepe}, Quote.usd);
      final price = (result as Ok<List<Price>>).value.single;
      expect(price.price, Decimal.parse('0.00000012'));
      expect(price.change24hPercent, Decimal.parse('-15'));
    });

    test('分批：超过上限的 id 拆成多次请求，结果合并', () async {
      final adapter = FakeAdapter((o) {
        final body = {
          for (final id in idsOf(o))
            id: {
              'usd': 1.5,
              'usd_24h_change': 0.5,
              'last_updated_at': 1711356300,
            },
        };
        return jsonBody(_encode(body));
      });
      final assets = {
        for (var i = 0; i < 5; i++)
          Asset(id: 'T$i', symbol: 'T$i', name: 'T$i', priceId: 'coin-$i'),
      };
      final result = await build(
        adapter,
        maxIds: 2,
      ).fetchPrices(assets, Quote.usd);
      expect((result as Ok<List<Price>>).value, hasLength(5));
      expect(adapter.requests.map(idsOf).toList(), [
        ['coin-0', 'coin-1'],
        ['coin-2', 'coin-3'],
        ['coin-4'],
      ]);
    });

    test('没有 priceId 的 Asset 被跳过；全部没有时不发请求', () async {
      final adapter = FakeAdapter(
        (_) => jsonBody(fixture('simple_price_usd.json')),
      );
      final source = build(adapter);
      final empty = await source.fetchPrices({_noPrice}, Quote.usd);
      expect((empty as Ok<List<Price>>).value, isEmpty);
      expect(adapter.requests, isEmpty);

      final mixed = await source.fetchPrices({_noPrice, _btc}, Quote.usd);
      expect((mixed as Ok<List<Price>>).value.map((p) => p.assetId), ['BTC']);
      expect(idsOf(adapter.requests.single), ['bitcoin']);
    });

    test('返回里缺少某个币、缺少报价或无涨跌时跳过/置空', () async {
      final adapter = FakeAdapter(
        (_) => jsonBody(fixture('simple_price_partial.json')),
      );
      final result = await build(adapter)
          .fetchPrices({_btc, _eth, _usdt}, Quote.usd);
      final prices = (result as Ok<List<Price>>).value;
      // ethereum 的条目为空、tether 整条缺失
      expect(prices.map((p) => p.assetId), ['BTC']);
      expect(prices.single.change24hPercent, isNull);
    });

    test('响应不是对象或价格非正数时不产生价格', () async {
      final adapter = FakeAdapter(
        (_) => jsonBody('{"bitcoin":{"usd":0},"ethereum":{"usd":"x"}}'),
      );
      final result = await build(adapter).fetchPrices({_btc, _eth}, Quote.usd);
      expect((result as Ok<List<Price>>).value, isEmpty);

      final list = FakeAdapter((_) => jsonBody('[]'));
      final r2 = await build(list).fetchPrices({_btc}, Quote.usd);
      expect((r2 as Ok<List<Price>>).value, isEmpty);
    });

    test('429 → RateLimitedFailure', () async {
      final adapter = FakeAdapter(
        (_) => jsonBody(fixture('error_429.json'), status: 429),
      );
      final result = await build(adapter).fetchPrices({_btc}, Quote.usd);
      expect((result as Err<List<Price>>).failure, isA<RateLimitedFailure>());
    });

    test('401 → UnauthorizedFailure，5xx → ServiceDownFailure', () async {
      final r1 = await build(FakeAdapter((_) => jsonBody('{}', status: 401)))
          .fetchPrices({_btc}, Quote.usd);
      expect((r1 as Err<List<Price>>).failure, isA<UnauthorizedFailure>());
      final r2 = await build(FakeAdapter((_) => jsonBody('{}', status: 503)))
          .fetchPrices({_btc}, Quote.usd);
      expect((r2 as Err<List<Price>>).failure, isA<ServiceDownFailure>());
    });

    test('网络错误 → NetworkFailure', () async {
      final adapter = FakeAdapter(
        (o) => throw DioException(
          requestOptions: o,
          type: DioExceptionType.connectionError,
        ),
      );
      final result = await build(adapter).fetchPrices({_btc}, Quote.usd);
      expect((result as Err<List<Price>>).failure, isA<NetworkFailure>());

      final timeout = FakeAdapter(
        (o) => throw DioException(
          requestOptions: o,
          type: DioExceptionType.receiveTimeout,
        ),
      );
      final r2 = await build(timeout).fetchPrices({_btc}, Quote.usd);
      expect((r2 as Err<List<Price>>).failure, isA<NetworkFailure>());
    });

    test('响应不是合法 JSON → UnknownFailure，且信息不含响应原文', () async {
      final adapter = FakeAdapter(
        (_) => jsonBody('<html>secret-looking-body</html>'),
      );
      final result = await build(adapter).fetchPrices({_btc}, Quote.usd);
      final failure = (result as Err<List<Price>>).failure;
      expect(failure, isA<UnknownFailure>());
      expect(failure.toString(), isNot(contains('secret-looking-body')));
    });

    test('分批中某批失败则整体失败，已成功批次的结果留在缓存里', () async {
      var call = 0;
      final adapter = FakeAdapter((o) {
        call++;
        if (call == 2) return jsonBody('{}', status: 429);
        return jsonBody(
          _encode({
            for (final id in idsOf(o))
              id: {'usd': 2, 'last_updated_at': 1711356300},
          }),
        );
      });
      final assets = {
        for (var i = 0; i < 4; i++)
          Asset(id: 'T$i', symbol: 'T$i', name: 'T$i', priceId: 'coin-$i'),
      };
      final source = build(adapter, maxIds: 2);
      final first = await source.fetchPrices(assets, Quote.usd);
      expect((first as Err<List<Price>>).failure, isA<RateLimitedFailure>());
      expect(adapter.requests, hasLength(2));

      // 重试时第一批命中缓存，只需重发第二批
      final second = await source.fetchPrices(assets, Quote.usd);
      expect((second as Ok<List<Price>>).value, hasLength(4));
      expect(adapter.requests, hasLength(3));
      expect(idsOf(adapter.requests.last), ['coin-2', 'coin-3']);
    });

    test('缓存：5 分钟内不重复请求，到期后重新请求；不同报价货币分开缓存', () async {
      final adapter = FakeAdapter((o) {
        final vs = o.queryParameters['vs_currencies'] as String;
        return jsonBody(
          _encode({
            for (final id in idsOf(o))
              id: {vs: 10, 'last_updated_at': 1711356300},
          }),
        );
      });
      final source = build(adapter);

      await source.fetchPrices({_btc}, Quote.usd);
      expect(adapter.requests, hasLength(1));

      clock.now = clock.now.add(const Duration(minutes: 4, seconds: 59));
      final cached = await source.fetchPrices({_btc}, Quote.usd);
      expect(adapter.requests, hasLength(1), reason: '4 分 59 秒内命中缓存');
      expect(
        (cached as Ok<List<Price>>).value.single.price,
        Decimal.fromInt(10),
      );

      // 另一种报价货币不命中
      await source.fetchPrices({_btc}, Quote.cny);
      expect(adapter.requests, hasLength(2));

      clock.now = clock.now.add(const Duration(seconds: 1));
      await source.fetchPrices({_btc}, Quote.usd);
      expect(adapter.requests, hasLength(3), reason: '满 5 分钟后重新请求');
    });

    test('缓存：只请求缓存里没有的币，结果仍包含全部', () async {
      final adapter = FakeAdapter(
        (o) => jsonBody(
          _encode({
            for (final id in idsOf(o))
              id: {'usd': 3, 'last_updated_at': 1711356300},
          }),
        ),
      );
      final source = build(adapter);
      await source.fetchPrices({_btc}, Quote.usd);
      final result = await source.fetchPrices({_btc, _eth}, Quote.usd);
      expect((result as Ok<List<Price>>).value.map((p) => p.assetId).toSet(), {
        'BTC',
        'ETH',
      });
      expect(idsOf(adapter.requests.last), ['ethereum']);
    });

    test('Key 为空不带请求头；有 Key 时放在 x-cg-demo-api-key', () async {
      final adapter = FakeAdapter(
        (_) => jsonBody(fixture('simple_price_usd.json')),
      );
      final source = build(adapter);
      await source.fetchPrices({_btc}, Quote.usd);
      expect(
        adapter.requests.last.headers.containsKey('x-cg-demo-api-key'),
        isFalse,
      );

      config.key = '  ';
      clock.now = clock.now.add(const Duration(hours: 1));
      await source.fetchPrices({_btc}, Quote.usd);
      expect(
        adapter.requests.last.headers.containsKey('x-cg-demo-api-key'),
        isFalse,
      );

      config.key = 'CG-test-key-0000';
      clock.now = clock.now.add(const Duration(hours: 1));
      await source.fetchPrices({_btc}, Quote.usd);
      expect(
        adapter.requests.last.headers['x-cg-demo-api-key'],
        'CG-test-key-0000',
      );
    });
  });

  group('lookupContracts', () {
    const usdc = ContractToken(
      'ethereum',
      '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
    );

    test('正常：返回带 priceId 的 Asset，请求路径使用平台 id', () async {
      final adapter = FakeAdapter(
        (_) => jsonBody(fixture('contract_usdc.json')),
      );
      final result = await build(adapter).lookupContracts({usdc});
      final asset = (result as Ok<Map<ContractToken, Asset>>).value[usdc]!;
      expect(asset.id, 'USDC');
      expect(asset.symbol, 'USDC');
      expect(asset.priceId, 'usd-coin');
      expect(asset.name, 'USDC');
      expect(
        adapter.requests.single.uri.path,
        '/api/v3/coins/ethereum/contract/0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
      );
    });

    test('官方文档示例响应：id、symbol、name 在顶层，且不带多余查询参数', () async {
      const weth = ContractToken(
        'ethereum',
        '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2',
      );
      final adapter = FakeAdapter(
        (_) => jsonBody(fixture('contract_weth_doc.json')),
      );
      final result = await build(adapter).lookupContracts({weth});
      final asset = (result as Ok<Map<ContractToken, Asset>>).value[weth]!;
      expect(asset.priceId, 'weth');
      expect(asset.symbol, 'WETH');
      expect(asset.name, 'WETH');
      // 官方文档该接口没有列出任何查询参数。
      expect(adapter.requests.single.queryParameters, isEmpty);
    });

    test('九条链的平台 id 映射', () {
      expect(CoinGeckoPriceSource.platformIds, {
        'ethereum': 'ethereum',
        'bsc': 'binance-smart-chain',
        'arbitrum': 'arbitrum-one',
        'optimism': 'optimistic-ethereum',
        'base': 'base',
        'polygon': 'polygon-pos',
        'solana': 'solana',
        'tron': 'tron',
      });
    });

    test('不同链走各自的平台 id', () async {
      final adapter = FakeAdapter(
        (_) => jsonBody(fixture('contract_usdc.json')),
      );
      await build(adapter).lookupContracts({
        const ContractToken(
          'bsc',
          '0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d',
        ),
        const ContractToken(
          'solana',
          'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
        ),
      });
      expect(adapter.requests.map((r) => r.uri.pathSegments[3]).toSet(), {
        'binance-smart-chain',
        'solana',
      });
    });

    test('404 → 空映射而不是失败；结果被缓存，不重复请求', () async {
      final adapter = FakeAdapter(
        (_) => jsonBody('{"error":"coin not found"}', status: 404),
      );
      final source = build(adapter);
      final result = await source.lookupContracts({usdc});
      expect((result as Ok<Map<ContractToken, Asset>>).value, isEmpty);
      await source.lookupContracts({usdc});
      expect(adapter.requests, hasLength(1));
    });

    test('403（免费档不支持）→ 空映射', () async {
      final adapter = FakeAdapter((_) => jsonBody('{}', status: 403));
      final result = await build(adapter).lookupContracts({usdc});
      expect((result as Ok<Map<ContractToken, Asset>>).value, isEmpty);
    });

    test('不支持的链（Bitcoin 等）与不合法的地址：空映射，不发请求', () async {
      final adapter = FakeAdapter(
        (_) => jsonBody(fixture('contract_usdc.json')),
      );
      final result = await build(adapter).lookupContracts({
        const ContractToken(
          'bitcoin',
          'bc1qxyz0000000000000000000000000000000000',
        ),
        const ContractToken(
          'nochain',
          '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
        ),
        const ContractToken('ethereum', '../../secret'),
      });
      expect((result as Ok<Map<ContractToken, Asset>>).value, isEmpty);
      expect(adapter.requests, isEmpty);
    });

    test('空集合返回空映射', () async {
      final adapter = FakeAdapter((_) => jsonBody('{}'));
      final result = await build(adapter).lookupContracts({});
      expect((result as Ok<Map<ContractToken, Asset>>).value, isEmpty);
      expect(adapter.requests, isEmpty);
    });

    test('429、网络错误照实返回为失败', () async {
      final r1 = await build(FakeAdapter((_) => jsonBody('{}', status: 429)))
          .lookupContracts({usdc});
      expect(
        (r1 as Err<Map<ContractToken, Asset>>).failure,
        isA<RateLimitedFailure>(),
      );
      final net = FakeAdapter(
        (o) => throw DioException(
          requestOptions: o,
          type: DioExceptionType.connectionError,
        ),
      );
      final r2 = await build(net).lookupContracts({usdc});
      expect(
        (r2 as Err<Map<ContractToken, Asset>>).failure,
        isA<NetworkFailure>(),
      );
    });

    test('单次调用的请求数受 maxLookupsPerCall 限制', () async {
      final adapter = FakeAdapter(
        (_) => jsonBody(fixture('contract_usdc.json')),
      );
      final tokens = {
        for (var i = 0; i < 5; i++)
          ContractToken('ethereum', '0x${'$i'.padLeft(40, '0')}'),
      };
      final result = await build(
        adapter,
        maxLookups: 2,
      ).lookupContracts(tokens);
      expect(adapter.requests, hasLength(2));
      expect((result as Ok<Map<ContractToken, Asset>>).value, hasLength(2));
    });

    test('与内置币种同名但币种标识不同：加后缀，不会冒充内置币种', () async {
      final adapter = FakeAdapter(
        (_) => jsonBody(fixture('contract_symbol_clash.json')),
      );
      final fake = const ContractToken(
        'bsc',
        '0x0000000000000000000000000000000000000abc',
      );
      final result = await build(
        adapter,
        catalog: BuiltInAssetCatalog(),
      ).lookupContracts({fake});
      final asset = (result as Ok<Map<ContractToken, Asset>>).value[fake]!;
      expect(asset.id, isNot('USDT'));
      expect(asset.id, 'USDT-FAKE-TETHER-TOKEN');
      expect(asset.priceId, 'fake-tether-token');
    });

    test('catalog 只需实现 AssetCatalog 接口：按 byPriceId 合并、按 byId 判断符号冲突', () async {
      final known = const Asset(
        id: 'USDC',
        symbol: 'USDC',
        name: '已知的 USDC',
        priceId: 'usd-coin',
      );
      final adapter = FakeAdapter(
        (_) => jsonBody(fixture('contract_usdc.json')),
      );
      final result = await build(
        adapter,
        catalog: _MapCatalog({'usd-coin': known}),
      ).lookupContracts({usdc});
      expect((result as Ok<Map<ContractToken, Asset>>).value[usdc], known);
    });

    test('CoinGecko 认定为内置币种时合并到内置币种', () async {
      final adapter = FakeAdapter(
        (_) => jsonBody(fixture('contract_usdc.json')),
      );
      final catalog = BuiltInAssetCatalog();
      final result = await build(
        adapter,
        catalog: catalog,
      ).lookupContracts({usdc});
      expect(
        (result as Ok<Map<ContractToken, Asset>>).value[usdc],
        catalog.byId('USDC'),
      );
    });
  });
}

String _encode(Map<String, Object?> body) {
  final entries = body.entries.map((e) {
    final inner = (e.value as Map<String, Object?>).entries
        .map((i) => '"${i.key}":${i.value}')
        .join(',');
    return '"${e.key}":{$inner}';
  });
  return '{${entries.join(',')}}';
}

/// 只含若干 priceId -> 币种的最小目录，用来证明价格源只依赖接口。
final class _MapCatalog implements AssetCatalog {
  _MapCatalog(this._byPriceId);

  final Map<String, Asset> _byPriceId;

  @override
  Asset? byPriceId(String priceId) => _byPriceId[priceId];

  @override
  Asset? byId(String assetId) =>
      _byPriceId.values.where((a) => a.id == assetId).firstOrNull;

  @override
  Asset? resolve(TokenRef token) => null;
}
