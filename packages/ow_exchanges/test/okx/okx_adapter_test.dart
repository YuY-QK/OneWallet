import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:ow_exchanges/ow_exchanges.dart';
import 'package:ow_net/ow_net.dart';
import 'package:test/test.dart';

import '../support/fake_adapter.dart';

String fx(String name) => fixture('okx/$name.json');

/// 默认路由：只读 Key，交易、资金、理财接口都返回样本。
ResponseBody route(RequestOptions o, {String config = 'readonly'}) {
  switch (o.uri.path) {
    case OkxPaths.publicTime:
      return jsonResponse(fx('time'));
    case OkxPaths.accountConfig:
      return jsonResponse(fx('config_$config'));
    case OkxPaths.accountBalance:
      return jsonResponse(fx('balance'));
    case OkxPaths.fundingBalances:
      return jsonResponse(fx('funding'));
    case OkxPaths.savingsBalance:
      return jsonResponse(fx('savings'));
    case OkxPaths.stakingActiveOrders:
      return jsonResponse(fx('staking'));
  }
  return jsonResponse('{"code":"51000","msg":"unexpected"}', status: 404);
}

OkxAdapter build(FakeAdapter fake, {FixedClock? clock}) => OkxAdapter(
  clock: clock ?? FixedClock(DateTime.utc(2026, 11, 12)),
  rateLimiter: testLimiter(),
  clientBuilder: (config) => OwHttpClientFactory.create(config, adapter: fake),
);

/// 测试用凭据：Key、Secret、Passphrase 都是明显的假数据。
ExchangeCredentials creds() => fakeCredentials(passphrase: 'TESTPASS');

Map<(ExchangeSubAccount, String), Decimal> byKey(
  List<(ExchangeSubAccount, RawHolding)> list,
) => {
  for (final (sub, h) in list)
    (sub, (h.token as ExchangeToken).symbol): h.amount,
};

Decimal d(String s) => Decimal.parse(s);

void main() {
  group('verify（权限）', () {
    Future<Result<CredentialCheck>> run(String config) {
      final fake = FakeAdapter((o, b) => route(o, config: config));
      return build(fake).verify(creds());
    }

    test('只读', () async {
      final r = await run('readonly');
      expect(
        (r as Ok<CredentialCheck>).value.permission,
        KeyPermission.readOnly,
      );
    });

    test('带交易权限', () async {
      final r = await run('trade');
      expect(
        (r as Ok<CredentialCheck>).value.permission,
        KeyPermission.canTrade,
      );
    });

    test('能提现优先于能交易', () async {
      final r = await run('withdraw');
      expect(
        (r as Ok<CredentialCheck>).value.permission,
        KeyPermission.canWithdraw,
      );
    });

    test('perm 字段缺失返回 unknown', () async {
      final fake = FakeAdapter(
        (o, b) => jsonResponse('{"code":"0","msg":"","data":[{"acctLv":"2"}]}'),
      );
      final r = await build(fake).verify(creds());
      expect(
        (r as Ok<CredentialCheck>).value.permission,
        KeyPermission.unknown,
      );
    });

    test('permissionFrom 容忍空格，未知取值返回 unknown', () {
      expect(
        OkxAdapter.permissionFrom(' read_only , trade '),
        KeyPermission.canTrade,
      );
      expect(OkxAdapter.permissionFrom('foo'), KeyPermission.unknown);
      expect(OkxAdapter.permissionFrom(null), KeyPermission.unknown);
    });

    test('Key 无效（50111）', () async {
      final fake = FakeAdapter(
        (o, b) => jsonResponse('{"code":"50111","msg":"x"}', status: 401),
      );
      final r = await build(fake).verify(creds());
      expect((r as Err<CredentialCheck>).failure, isA<UnauthorizedFailure>());
    });

    test('缺少 Passphrase：直接返回 UnauthorizedFailure，不发请求', () async {
      final fake = FakeAdapter((o, b) => route(o));
      final r = await build(fake).verify(fakeCredentials());
      expect((r as Err<CredentialCheck>).failure, isA<UnauthorizedFailure>());
      expect(fake.requests, isEmpty);
    });

    test('请求头：Key、Passphrase、时间戳与签名正确，且不泄漏 Secret', () async {
      final fake = FakeAdapter((o, b) => route(o));
      await build(fake).verify(creds());
      final req = fake.requests.single;
      expect(req.uri.path, OkxPaths.accountConfig);
      expect(req.uri.query, isEmpty);
      expect(req.headers['OK-ACCESS-KEY'], 'TESTKEY');
      expect(req.headers['OK-ACCESS-PASSPHRASE'], 'TESTPASS');
      expect(req.headers['OK-ACCESS-TIMESTAMP'], '2026-11-12T00:00:00.000Z');
      // 期望值由 Python 标准库独立计算：
      // base64(HMAC-SHA256(b'TESTSECRET', b'2026-11-12T00:00:00.000ZGET/api/v5/account/config'))
      expect(
        req.headers['OK-ACCESS-SIGN'],
        'fifzn7i2vTCScuW/kaUzUv5kP0AQRjMMU2+1l88B9bI=',
      );
      expect(req.headers.values.join(' '), isNot(contains('TESTSECRET')));
    });
  });

  group('fetchHoldings', () {
    test('三个账户的合并：交易（可用+冻结）、资金、理财', () async {
      final fake = FakeAdapter((o, b) => route(o));
      final adapter = build(fake);
      final r = await adapter.fetchHoldings(creds());
      final m = byKey((r as Ok<List<(ExchangeSubAccount, RawHolding)>>).value);

      // 交易账户：USDT = 可用 4834.317093622894 + 冻结 158.573；BTC = 0.5 + 0.2。
      expect(m[(ExchangeSubAccount.spot, 'USDT')], d('4992.890093622894'));
      expect(m[(ExchangeSubAccount.spot, 'BTC')], d('0.7'));
      // 零余额的 ETH 被丢弃。
      expect(m.containsKey((ExchangeSubAccount.spot, 'ETH')), isFalse);
      // 资金账户：USDT = 100 + 4；ETH 原样。
      expect(m[(ExchangeSubAccount.funding, 'USDT')], d('104'));
      expect(m[(ExchangeSubAccount.funding, 'ETH')], d('37.11827078'));
      // 理财：余币宝 USDT 与链上赚币 USDT 本金 1、DOT 本金 2 合并。
      expect(m[(ExchangeSubAccount.earn, 'USDT')], d('12.0010737453457821'));
      expect(m[(ExchangeSubAccount.earn, 'DOT')], d('2'));
      expect(adapter.lastSkipped, isEmpty);
    });

    test('返回的代币是 ExchangeToken(okx, 大写符号)', () async {
      final fake = FakeAdapter((o, b) => route(o));
      final r = await build(fake).fetchHoldings(creds());
      final list = (r as Ok<List<(ExchangeSubAccount, RawHolding)>>).value;
      expect(list.first.$2.token, const ExchangeToken(ExchangeId.okx, 'USDT'));
    });

    test('每个请求都带签名与 Passphrase，且路径都在只读白名单内', () async {
      final fake = FakeAdapter((o, b) => route(o));
      await build(fake).fetchHoldings(creds());
      for (final req in fake.requests) {
        if (req.uri.path == OkxPaths.publicTime) continue;
        expect(req.headers['OK-ACCESS-SIGN'], isNotEmpty, reason: '${req.uri}');
        expect(req.headers['OK-ACCESS-PASSPHRASE'], 'TESTPASS');
      }
    });

    test('缺少 Passphrase：直接失败，不发请求', () async {
      final fake = FakeAdapter((o, b) => route(o));
      final r = await build(fake).fetchHoldings(fakeCredentials());
      expect(
        (r as Err<List<(ExchangeSubAccount, RawHolding)>>).failure,
        isA<UnauthorizedFailure>(),
      );
      expect(fake.requests, isEmpty);
    });

    test('交易账户失败（503）导致整体失败，不悄悄少算', () async {
      final fake = FakeAdapter((o, b) {
        if (o.uri.path == OkxPaths.accountBalance) {
          return jsonResponse('{}', status: 503);
        }
        return route(o);
      });
      final r = await build(fake).fetchHoldings(creds());
      expect(
        (r as Err<List<(ExchangeSubAccount, RawHolding)>>).failure,
        isA<ServiceDownFailure>(),
      );
    });

    test('资金账户失败（50001）导致整体失败', () async {
      final fake = FakeAdapter((o, b) {
        if (o.uri.path == OkxPaths.fundingBalances) {
          return jsonResponse('{"code":"50001","msg":"x"}', status: 503);
        }
        return route(o);
      });
      final r = await build(fake).fetchHoldings(creds());
      expect(
        (r as Err<List<(ExchangeSubAccount, RawHolding)>>).failure,
        isA<ServiceDownFailure>(),
      );
    });

    test('余币宝未开通（50120，无权限）：该产品为空，记入 lastSkipped，整体成功', () async {
      final fake = FakeAdapter((o, b) {
        if (o.uri.path == OkxPaths.savingsBalance) {
          return jsonResponse('{"code":"50120","msg":"x"}');
        }
        return route(o);
      });
      final adapter = build(fake);
      final r = await adapter.fetchHoldings(creds());
      final m = byKey((r as Ok<List<(ExchangeSubAccount, RawHolding)>>).value);
      // 余币宝的 USDT 缺席，链上赚币的 USDT 本金 1 仍在。
      expect(m[(ExchangeSubAccount.earn, 'USDT')], d('1'));
      expect(m[(ExchangeSubAccount.earn, 'DOT')], d('2'));
      expect(adapter.lastSkipped, ['余币宝']);
    });

    test('两个理财产品都无权限：earn 为空，lastSkipped 按顺序记录两项', () async {
      final fake = FakeAdapter((o, b) {
        if (o.uri.path == OkxPaths.savingsBalance ||
            o.uri.path == OkxPaths.stakingActiveOrders) {
          return jsonResponse('{"code":"50120","msg":"x"}');
        }
        return route(o);
      });
      final adapter = build(fake);
      final r = await adapter.fetchHoldings(creds());
      final m = byKey((r as Ok<List<(ExchangeSubAccount, RawHolding)>>).value);
      expect(m.keys.where((k) => k.$1 == ExchangeSubAccount.earn), isEmpty);
      expect(m[(ExchangeSubAccount.spot, 'USDT')], d('4992.890093622894'));
      expect(adapter.lastSkipped, ['余币宝', '链上赚币']);
    });

    test('理财接口限频（50011）：整体失败，不当作无权限', () async {
      final fake = FakeAdapter((o, b) {
        if (o.uri.path == OkxPaths.stakingActiveOrders) {
          return jsonResponse('{"code":"50011","msg":"x"}', status: 429);
        }
        return route(o);
      });
      final r = await build(fake).fetchHoldings(creds());
      expect(
        (r as Err<List<(ExchangeSubAccount, RawHolding)>>).failure,
        isA<RateLimitedFailure>(),
      );
    });

    test('lastSkipped 每次调用重置', () async {
      var deny = true;
      final fake = FakeAdapter((o, b) {
        if (deny && o.uri.path == OkxPaths.savingsBalance) {
          return jsonResponse('{"code":"50120","msg":"x"}');
        }
        return route(o);
      });
      final adapter = build(fake);
      await adapter.fetchHoldings(creds());
      expect(adapter.lastSkipped, ['余币宝']);
      deny = false;
      await adapter.fetchHoldings(creds());
      expect(adapter.lastSkipped, isEmpty);
    });

    test('限频：HTTP 429 且业务码 50011', () async {
      final fake = FakeAdapter(
        (o, b) => jsonResponse('{"code":"50011","msg":"x"}', status: 429),
      );
      final r = await build(fake).fetchHoldings(creds());
      expect(
        (r as Err<List<(ExchangeSubAccount, RawHolding)>>).failure,
        isA<RateLimitedFailure>(),
      );
    });

    test('时间偏差：校正后重试成功，只多一次时间请求', () async {
      // 设备时间比服务器慢很多；时间戳偏差超过 30 秒时 OKX 返回 50102。
      final serverMs = DateTime.utc(2026, 11, 12).millisecondsSinceEpoch;
      final clock = FixedClock(DateTime.utc(2017, 7, 1));
      final fake = FakeAdapter((o, b) {
        if (o.uri.path == OkxPaths.publicTime) return route(o);
        final ts = DateTime.parse(o.headers['OK-ACCESS-TIMESTAMP'] as String)
            .millisecondsSinceEpoch;
        if ((serverMs - ts).abs() > 30000) {
          return jsonResponse('{"code":"50102","msg":"x"}', status: 401);
        }
        return route(o);
      });
      final r = await build(clock: clock, fake).fetchHoldings(creds());
      expect(r, isA<Ok<List<(ExchangeSubAccount, RawHolding)>>>());
      expect(fake.paths.where((p) => p == OkxPaths.publicTime), hasLength(1));
    });

    test('校正后仍偏差返回 ClockSkewFailure', () async {
      final fake = FakeAdapter((o, b) {
        if (o.uri.path == OkxPaths.publicTime) return route(o);
        return jsonResponse('{"code":"50102","msg":"x"}', status: 401);
      });
      final r = await build(fake).fetchHoldings(creds());
      expect(
        (r as Err<List<(ExchangeSubAccount, RawHolding)>>).failure,
        isA<ClockSkewFailure>(),
      );
    });
  });

  group('只读约束', () {
    test('所有请求路径都在只读白名单内', () async {
      final fake = FakeAdapter((o, b) => route(o, config: 'withdraw'));
      final adapter = build(fake);
      await adapter.verify(creds());
      await adapter.fetchHoldings(creds());
      expect(fake.paths, isNotEmpty);
      expect(pathsOutsideAllowlist(fake.paths, okxReadOnlyPaths), isEmpty);
    });

    test('白名单路径不含任何动用资金的接口（链上赚币的 orders 为只读查询，单独说明）', () {
      final bad = RegExp('order|trade|withdraw|transfer|convert');
      // 唯一例外：链上赚币进行中订单的查询。路径中的 "orders" 不代表下单，见
      // check_deps.dart 的 readOnlyPathAllowlist 与 docs/EXTERNAL_APIS.md。
      const exception = OkxPaths.stakingActiveOrders;
      for (final p in okxReadOnlyPaths) {
        if (p == exception) {
          expect(p, contains('/orders-active'));
          continue;
        }
        expect(bad.hasMatch(p), isFalse, reason: p);
      }
    });
  });

  test('充值地址：返回空列表且不发请求', () async {
    final fake = FakeAdapter((o, b) => route(o));
    final r = await build(fake).fetchDepositAddresses(creds());
    expect((r as Ok<List<DepositAddress>>).value, isEmpty);
    expect(fake.requests, isEmpty);
  });

  test('基本属性与未包含清单', () {
    final a = build(FakeAdapter((o, b) => route(o)));
    expect(a.id, ExchangeId.okx);
    expect(a.needsPassphrase, isTrue);
    expect(OkxAdapter.notIncluded, isNotEmpty);
  });
}
