import 'dart:convert';
import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:ow_exchanges/ow_exchanges.dart';
import 'package:ow_net/ow_net.dart';
import 'package:test/test.dart';

import '../support/fake_adapter.dart';

String fx(String name) => fixture('binance/$name.json');

/// 默认路由：只读 Key（不带杠杆与合约权限）。
ResponseBody route(RequestOptions o, {String restrictions = 'readonly'}) {
  switch (o.uri.path) {
    case BinancePaths.apiRestrictions:
      return jsonResponse(fx('restrictions_$restrictions'));
    case BinancePaths.spotAccount:
      return jsonResponse(fx('spot_account'));
    case BinancePaths.fundingAssets:
      return jsonResponse(fx('funding'));
    case BinancePaths.crossMargin:
      return jsonResponse(fx('cross_margin'));
    case BinancePaths.isolatedMargin:
      return jsonResponse(fx('isolated_margin'));
    case BinancePaths.usdmBalance:
      return jsonResponse(fx('usdm_balance'));
    case BinancePaths.coinmBalance:
      return jsonResponse(fx('coinm_balance'));
    case BinancePaths.flexiblePosition:
      return jsonResponse(fx('flexible'));
    case BinancePaths.lockedPosition:
      return jsonResponse(fx('locked'));
    case BinancePaths.serverTime:
      return jsonResponse(fx('server_time'));
  }
  return jsonResponse('{"code":-1,"msg":"unexpected"}', status: 404);
}

BinanceAdapter build(FakeAdapter fake, {FixedClock? clock}) => BinanceAdapter(
  clock: clock ?? FixedClock(DateTime.utc(2026, 11, 12)),
  rateLimiter: testLimiter(),
  clientBuilder: (config) => OwHttpClientFactory.create(config, adapter: fake),
);

Map<(ExchangeSubAccount, String), Decimal> byKey(
  List<(ExchangeSubAccount, RawHolding)> list,
) => {
  for (final (sub, h) in list)
    (sub, (h.token as ExchangeToken).symbol): h.amount,
};

Decimal d(String s) => Decimal.parse(s);

void main() {
  group('verify（权限）', () {
    Future<Result<CredentialCheck>> run(String restrictions) {
      final fake = FakeAdapter((o, b) => route(o, restrictions: restrictions));
      return build(fake).verify(fakeCredentials());
    }

    test('只读', () async {
      final r = await run('readonly');
      expect(
        (r as Ok<CredentialCheck>).value.permission,
        KeyPermission.readOnly,
      );
    });

    test('带合约与杠杆开关视为能交易', () async {
      final r = await run('margin_futures');
      expect(
        (r as Ok<CredentialCheck>).value.permission,
        KeyPermission.canTrade,
      );
    });

    test('能提现优先于能交易', () async {
      final fake = FakeAdapter(
        (o, b) => jsonResponse(
          '{"enableReading":true,"enableWithdrawals":true,'
          '"enableSpotAndMarginTrading":true}',
        ),
      );
      final r = await build(fake).verify(fakeCredentials());
      expect(
        (r as Ok<CredentialCheck>).value.permission,
        KeyPermission.canWithdraw,
      );
    });

    test('Key 无效（-2015）', () async {
      final fake = FakeAdapter(
        (o, b) => jsonResponse('{"code":-2015,"msg":"x"}', status: 401),
      );
      final r = await build(fake).verify(fakeCredentials());
      expect((r as Err<CredentialCheck>).failure, isA<UnauthorizedFailure>());
    });

    test('请求带 Key 头，签名与查询串一致，且不泄漏 Secret', () async {
      final fake = FakeAdapter((o, b) => route(o));
      await build(fake).verify(fakeCredentials());
      final req = fake.requests.single;
      expect(req.headers['X-MBX-APIKEY'], 'TESTKEY');
      final query = req.uri.query;
      final cut = query.lastIndexOf('&signature=');
      final signed = query.substring(0, cut);
      final signature = query.substring(cut + '&signature='.length);
      final secret = Sensitive(Uint8List.fromList(utf8.encode('TESTSECRET')));
      expect(signature, hmacSha256Hex(secret, signed));
      expect(signed, contains('recvWindow=5000'));
      expect(signed, contains('timestamp=1794441600000'));
      expect(query, isNot(contains('TESTSECRET')));
    });
  });

  group('fetchHoldings', () {
    test('不看权限开关：接口返回成功就计入（只读 Key 也能读合约与杠杆）', () async {
      final fake = FakeAdapter((o, b) => route(o)); // 开关为假的只读 Key
      final adapter = build(fake);
      final r = await adapter.fetchHoldings(fakeCredentials());
      final m = byKey((r as Ok<List<(ExchangeSubAccount, RawHolding)>>).value);

      // 现货：总量 = 可用 + 冻结；零余额的 ETH 被丢弃。
      expect(m[(ExchangeSubAccount.spot, 'BTC')], d('4723846.89208129'));
      expect(m[(ExchangeSubAccount.spot, 'LTC')], d('4763370.18006011'));
      expect(m.containsKey((ExchangeSubAccount.spot, 'ETH')), isFalse);
      // 资金：可用 + 冻结 + 锁定 + 提现中。
      expect(m[(ExchangeSubAccount.funding, 'USDT')], d('104'));
      expect(m.containsKey((ExchangeSubAccount.funding, 'BNB')), isFalse);
      // 理财：活期与定期合并。
      expect(m[(ExchangeSubAccount.earn, 'USDT')], d('85.46'));
      expect(m[(ExchangeSubAccount.earn, 'AXS')], d('122.09202928'));
      expect(m[(ExchangeSubAccount.earn, 'BTC')], d('0.5'));
      // 合约与杠杆照常请求并计入。
      expect(m[(ExchangeSubAccount.futures, 'USDT')], d('122607.35137903'));
      expect(m[(ExchangeSubAccount.margin, 'BTC')], d('0.7'));
      expect(adapter.lastSkipped, isEmpty);
      // 不再调用权限接口。
      expect(fake.paths, isNot(contains(BinancePaths.apiRestrictions)));
    });

    test('现货成功后合约与杠杆返回 -2015：该子账户为空，记入 lastSkipped，整体成功', () async {
      final fake = FakeAdapter((o, b) {
        final p = o.uri.path;
        if (p == BinancePaths.crossMargin ||
            p == BinancePaths.isolatedMargin ||
            p == BinancePaths.usdmBalance ||
            p == BinancePaths.coinmBalance) {
          return jsonResponse('{"code":-2015,"msg":"x"}', status: 401);
        }
        return route(o);
      });
      final adapter = build(fake);
      final r = await adapter.fetchHoldings(fakeCredentials());
      final m = byKey((r as Ok<List<(ExchangeSubAccount, RawHolding)>>).value);
      expect(m.keys.where((k) => k.$1 == ExchangeSubAccount.margin), isEmpty);
      expect(m.keys.where((k) => k.$1 == ExchangeSubAccount.futures), isEmpty);
      expect(m.containsKey((ExchangeSubAccount.spot, 'BTC')), isTrue);
      expect(m.containsKey((ExchangeSubAccount.earn, 'USDT')), isTrue);
      expect(adapter.lastSkipped, ['杠杆账户', '合约账户']);
    });

    test('lastSkipped 每次调用重置', () async {
      var deny = true;
      final fake = FakeAdapter((o, b) {
        if (deny && o.uri.path == BinancePaths.usdmBalance) {
          return jsonResponse('{"code":-2015,"msg":"x"}', status: 401);
        }
        return route(o);
      });
      final adapter = build(fake);
      await adapter.fetchHoldings(fakeCredentials());
      expect(adapter.lastSkipped, ['合约账户']);
      deny = false;
      await adapter.fetchHoldings(fakeCredentials());
      expect(adapter.lastSkipped, isEmpty);
    });

    test('合约接口限频：整体失败，不当作无权限', () async {
      final fake = FakeAdapter((o, b) {
        if (o.uri.path == BinancePaths.usdmBalance) {
          return jsonResponse('{}', status: 429);
        }
        return route(o);
      });
      final r = await build(fake).fetchHoldings(fakeCredentials());
      expect(
        (r as Err<List<(ExchangeSubAccount, RawHolding)>>).failure,
        isA<RateLimitedFailure>(),
      );
    });

    test('现货就返回 -2015：凭据无效，整体失败', () async {
      final fake = FakeAdapter((o, b) {
        if (o.uri.path == BinancePaths.spotAccount) {
          return jsonResponse('{"code":-2015,"msg":"x"}', status: 401);
        }
        return route(o);
      });
      final r = await build(fake).fetchHoldings(fakeCredentials());
      expect(
        (r as Err<List<(ExchangeSubAccount, RawHolding)>>).failure,
        isA<UnauthorizedFailure>(),
      );
    });

    test('开启杠杆与合约权限：净资产与账户权益', () async {
      final fake = FakeAdapter(
        (o, b) => route(o, restrictions: 'margin_futures'),
      );
      final r = await build(fake).fetchHoldings(fakeCredentials());
      final m = byKey((r as Ok<List<(ExchangeSubAccount, RawHolding)>>).value);

      // 全仓 BTC 0.6 + 逐仓 BTC 0.1；USDT：-60.1 + 10 + 5，净资产可为负。
      expect(m[(ExchangeSubAccount.margin, 'BTC')], d('0.7'));
      expect(m[(ExchangeSubAccount.margin, 'USDT')], d('-45.1'));
      // U 本位：钱包余额 + 未实现盈亏；币本位同理；ETH 为零被丢弃。
      expect(m[(ExchangeSubAccount.futures, 'USDT')], d('122607.35137903'));
      expect(m[(ExchangeSubAccount.futures, 'BNB')], d('0.75'));
      expect(m[(ExchangeSubAccount.futures, 'BTC')], d('0.011'));
      expect(m.containsKey((ExchangeSubAccount.futures, 'ETH')), isFalse);
      // 合约请求发往 fapi / dapi 主机。
      final hosts = {for (final q in fake.requests) q.uri.host};
      expect(
        hosts,
        containsAll([
          'api.binance.com',
          'fapi.binance.com',
          'dapi.binance.com',
        ]),
      );
    });

    test('返回的代币是 ExchangeToken(binance, 大写符号)', () async {
      final fake = FakeAdapter((o, b) => route(o));
      final r = await build(fake).fetchHoldings(fakeCredentials());
      final list = (r as Ok<List<(ExchangeSubAccount, RawHolding)>>).value;
      expect(
        list.first.$2.token,
        const ExchangeToken(ExchangeId.binance, 'BTC'),
      );
    });

    test('理财持仓分页读到最后一页', () async {
      final page1 = jsonEncode({
        'rows': [
          for (var i = 0; i < 100; i++) {'asset': 'USDT', 'totalAmount': '1'},
        ],
      });
      final fake = FakeAdapter((o, b) {
        if (o.uri.path == BinancePaths.flexiblePosition) {
          return jsonResponse(
            o.uri.queryParameters['current'] == '1'
                ? page1
                : '{"rows":[{"asset":"USDT","totalAmount":"0.5"}]}',
          );
        }
        return route(o);
      });
      final r = await build(fake).fetchHoldings(fakeCredentials());
      final m = byKey((r as Ok<List<(ExchangeSubAccount, RawHolding)>>).value);
      // 100 + 0.5（活期）+ 10（定期）。
      expect(m[(ExchangeSubAccount.earn, 'USDT')], d('110.5'));
      final flexible = fake.requests.where(
        (q) => q.uri.path == BinancePaths.flexiblePosition,
      );
      expect(flexible, hasLength(2));
    });

    test('某个子账户失败导致整体失败，不悄悄少算', () async {
      final fake = FakeAdapter((o, b) {
        if (o.uri.path == BinancePaths.fundingAssets) {
          return jsonResponse('{}', status: 503);
        }
        return route(o);
      });
      final r = await build(fake).fetchHoldings(fakeCredentials());
      expect(
        (r as Err<List<(ExchangeSubAccount, RawHolding)>>).failure,
        isA<ServiceDownFailure>(),
      );
    });

    test('杠杆账户未开通（-3003）视为空，不算失败', () async {
      final fake = FakeAdapter((o, b) {
        if (o.uri.path == BinancePaths.crossMargin ||
            o.uri.path == BinancePaths.isolatedMargin) {
          return jsonResponse('{"code":-3003,"msg":"x"}', status: 400);
        }
        return route(o, restrictions: 'margin_futures');
      });
      final r = await build(fake).fetchHoldings(fakeCredentials());
      final m = byKey((r as Ok<List<(ExchangeSubAccount, RawHolding)>>).value);
      expect(m.keys.where((k) => k.$1 == ExchangeSubAccount.margin), isEmpty);
      expect(m.containsKey((ExchangeSubAccount.futures, 'USDT')), isTrue);
    });

    test('限频：HTTP 429', () async {
      final fake = FakeAdapter((o, b) => jsonResponse('{}', status: 429));
      final r = await build(fake).fetchHoldings(fakeCredentials());
      expect(
        (r as Err<List<(ExchangeSubAccount, RawHolding)>>).failure,
        isA<RateLimitedFailure>(),
      );
    });

    test('时间偏差：校正后重试成功，只多一次时间请求', () async {
      // 设备时间比服务器慢很多；时间戳不足服务器时间时 Binance 返回 -1021。
      const serverMs = 1499827319559;
      final clock = FixedClock(DateTime.utc(2017, 7, 1));
      final fake = FakeAdapter((o, b) {
        if (o.uri.path == BinancePaths.serverTime) return route(o);
        final ts = int.parse(o.uri.queryParameters['timestamp']!);
        if ((serverMs - ts).abs() > 5000) {
          return jsonResponse('{"code":-1021,"msg":"x"}', status: 400);
        }
        return route(o);
      });
      final r = await build(
        fake,
        clock: clock,
      ).fetchHoldings(fakeCredentials());
      expect(r, isA<Ok<List<(ExchangeSubAccount, RawHolding)>>>());
      expect(
        fake.paths.where((p) => p == BinancePaths.serverTime),
        hasLength(1),
      );
    });

    test('校正后仍偏差返回 ClockSkewFailure', () async {
      final fake = FakeAdapter((o, b) {
        if (o.uri.path == BinancePaths.serverTime) return route(o);
        return jsonResponse('{"code":-1021,"msg":"x"}', status: 400);
      });
      final r = await build(fake).fetchHoldings(fakeCredentials());
      expect(
        (r as Err<List<(ExchangeSubAccount, RawHolding)>>).failure,
        isA<ClockSkewFailure>(),
      );
    });
  });

  group('只读约束', () {
    test('所有请求路径都在只读白名单内', () async {
      final fake = FakeAdapter(
        (o, b) => route(o, restrictions: 'margin_futures'),
      );
      final adapter = build(fake);
      await adapter.verify(fakeCredentials());
      await adapter.fetchHoldings(fakeCredentials());
      expect(fake.paths, isNotEmpty);
      expect(pathsOutsideAllowlist(fake.paths, binanceReadOnlyPaths), isEmpty);
    });

    test('白名单路径不含任何动用资金的接口', () {
      final bad = RegExp('order|trade|withdraw|transfer|convert');
      // 权限字段名不是路径，这里只检查路径。
      for (final p in binanceReadOnlyPaths) {
        expect(bad.hasMatch(p), isFalse, reason: p);
      }
    });
  });

  test('充值地址：返回空列表且不发请求', () async {
    final fake = FakeAdapter((o, b) => route(o));
    final r = await build(fake).fetchDepositAddresses(fakeCredentials());
    expect((r as Ok<List<DepositAddress>>).value, isEmpty);
    expect(fake.requests, isEmpty);
  });

  test('基本属性与未包含清单', () {
    final a = build(FakeAdapter((o, b) => route(o)));
    expect(a.id, ExchangeId.binance);
    expect(a.needsPassphrase, isFalse);
    expect(BinanceAdapter.notIncluded, isNotEmpty);
  });
}
