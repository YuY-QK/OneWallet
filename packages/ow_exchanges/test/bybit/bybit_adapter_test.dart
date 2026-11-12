import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:ow_exchanges/ow_exchanges.dart';
import 'package:ow_net/ow_net.dart';
import 'package:test/test.dart';

import '../support/fake_adapter.dart';

String fx(String name) => fixture('bybit/$name.json');

/// 默认路由：样本数据。[perm] 选择 `apikey_<perm>` 样本。
ResponseBody route(RequestOptions o, {String perm = 'readonly'}) {
  switch (o.uri.path) {
    case BybitPaths.serverTime:
      return jsonResponse(fx('time'));
    case BybitPaths.apiKeyInfo:
      return jsonResponse(fx('apikey_$perm'));
    case BybitPaths.walletBalance:
      return jsonResponse(fx('wallet'));
    case BybitPaths.fundBalance:
      return jsonResponse(fx('fund'));
    case BybitPaths.earnPosition:
      return jsonResponse(
        fx(
          o.uri.queryParameters['category'] == 'OnChain'
              ? 'earn_onchain'
              : 'earn_flexible',
        ),
      );
    case BybitPaths.fixedTermPosition:
      return jsonResponse(fx('fixed_term'));
  }
  return jsonResponse('{"retCode":10001,"retMsg":"unexpected"}');
}

BybitAdapter build(FakeAdapter fake, {FixedClock? clock}) => BybitAdapter(
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
    Future<Result<CredentialCheck>> run(String perm) {
      final fake = FakeAdapter((o, b) => route(o, perm: perm));
      return build(fake).verify(fakeCredentials());
    }

    test('只读（readOnly=1）', () async {
      final r = await run('readonly');
      expect(
        (r as Ok<CredentialCheck>).value.permission,
        KeyPermission.readOnly,
      );
    });

    test('读写且无提现权限：能交易', () async {
      final r = await run('trade');
      expect(
        (r as Ok<CredentialCheck>).value.permission,
        KeyPermission.canTrade,
      );
    });

    test('Wallet 含 Withdraw：能提现优先', () async {
      final r = await run('withdraw');
      expect(
        (r as Ok<CredentialCheck>).value.permission,
        KeyPermission.canWithdraw,
      );
    });

    test('permissionFrom：字段缺失返回 unknown', () {
      expect(BybitAdapter.permissionFrom(const {}), KeyPermission.unknown);
      expect(
        BybitAdapter.permissionFrom(const {'readOnly': 2}),
        KeyPermission.unknown,
      );
    });

    test('Key 无效（10003）', () async {
      final fake = FakeAdapter(
        (o, b) => jsonResponse('{"retCode":10003,"retMsg":"x"}', status: 401),
      );
      final r = await build(fake).verify(fakeCredentials());
      expect((r as Err<CredentialCheck>).failure, isA<UnauthorizedFailure>());
    });

    test('签名错误（10004）返回 UnauthorizedFailure', () async {
      final fake = FakeAdapter(
        (o, b) => jsonResponse('{"retCode":10004,"retMsg":"x"}'),
      );
      final r = await build(fake).verify(fakeCredentials());
      expect((r as Err<CredentialCheck>).failure, isA<UnauthorizedFailure>());
    });

    test('请求头：Key、时间戳、接收窗口与签名正确，且不泄漏 Secret', () async {
      final fake = FakeAdapter((o, b) => route(o));
      await build(fake).verify(fakeCredentials());
      final req = fake.requests.single;
      expect(req.uri.path, BybitPaths.apiKeyInfo);
      expect(req.uri.query, isEmpty);
      expect(req.headers['X-BAPI-API-KEY'], 'TESTKEY');
      expect(req.headers['X-BAPI-TIMESTAMP'], '1794441600000');
      expect(req.headers['X-BAPI-RECV-WINDOW'], '5000');
      // 期望值由 Python 标准库独立计算（非官方向量）：
      // HMAC-SHA256(b'TESTSECRET', b'1794441600000TESTKEY5000') 的小写十六进制。
      expect(
        req.headers['X-BAPI-SIGN'],
        '1336c446d5b94f84dfca3b98d3451fb1baab510b873c95d6d167fb77fd7e9115',
      );
      expect(req.headers.values.join(' '), isNot(contains('TESTSECRET')));
    });
  });

  group('fetchHoldings', () {
    test('统一账户、资金、理财三类合并', () async {
      final fake = FakeAdapter((o, b) => route(o));
      final adapter = build(fake);
      final r = await adapter.fetchHoldings(fakeCredentials());
      final m = byKey((r as Ok<List<(ExchangeSubAccount, RawHolding)>>).value);

      // 统一账户：walletBalance - spotBorrow。BTC 0.8 - 0.1 = 0.7；USDT 不扣借贷。
      expect(m[(ExchangeSubAccount.spot, 'USDT')], d('104.5'));
      expect(m[(ExchangeSubAccount.spot, 'BTC')], d('0.7'));
      // 借入未持有的 SOL：净额为负，保留。
      expect(m[(ExchangeSubAccount.spot, 'SOL')], d('-2'));
      // 零余额的 ETH 被丢弃。
      expect(m.containsKey((ExchangeSubAccount.spot, 'ETH')), isFalse);
      // 资金账户：walletBalance；零余额的 USDT 被丢弃。
      expect(m[(ExchangeSubAccount.funding, 'USDC')], d('12.5'));
      expect(m.containsKey((ExchangeSubAccount.funding, 'USDT')), isFalse);
      // 理财：灵活储蓄 USDT 100 与定期 USDT 50 合并；链上赚币 ETH 0.5；零持仓丢弃。
      expect(m[(ExchangeSubAccount.earn, 'USDT')], d('150'));
      expect(m[(ExchangeSubAccount.earn, 'ETH')], d('0.5'));
      expect(m.containsKey((ExchangeSubAccount.earn, 'BTC')), isFalse);
      expect(adapter.lastSkipped, isEmpty);
    });

    test('返回的代币是 ExchangeToken(bybit, 大写符号)', () async {
      final fake = FakeAdapter((o, b) => route(o));
      final r = await build(fake).fetchHoldings(fakeCredentials());
      final list = (r as Ok<List<(ExchangeSubAccount, RawHolding)>>).value;
      expect(
        list.first.$2.token,
        const ExchangeToken(ExchangeId.bybit, 'USDT'),
      );
    });

    test('统一账户请求带 accountType=UNIFIED 与对应签名', () async {
      final fake = FakeAdapter((o, b) => route(o));
      await build(fake).fetchHoldings(fakeCredentials());
      final req = fake.requests.firstWhere(
        (q) => q.uri.path == BybitPaths.walletBalance,
      );
      expect(req.uri.query, 'accountType=UNIFIED');
      expect(
        req.headers['X-BAPI-SIGN'],
        'c4f53050a3f5d39784a7a064f01dc359eff8ef0ba79ae3878d35fdd43326fb07',
      );
    });

    test('资金账户请求带 accountType=FUND', () async {
      final fake = FakeAdapter((o, b) => route(o));
      await build(fake).fetchHoldings(fakeCredentials());
      final req = fake.requests.firstWhere(
        (q) => q.uri.path == BybitPaths.fundBalance,
      );
      expect(req.uri.query, 'accountType=FUND');
    });

    test('统一账户失败（503）导致整体失败，不悄悄少算', () async {
      final fake = FakeAdapter((o, b) {
        if (o.uri.path == BybitPaths.walletBalance) {
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

    test('资金账户失败（10016）导致整体失败', () async {
      final fake = FakeAdapter((o, b) {
        if (o.uri.path == BybitPaths.fundBalance) {
          return jsonResponse('{"retCode":10016,"retMsg":"x"}');
        }
        return route(o);
      });
      final r = await build(fake).fetchHoldings(fakeCredentials());
      expect(
        (r as Err<List<(ExchangeSubAccount, RawHolding)>>).failure,
        isA<ServiceDownFailure>(),
      );
    });

    test('灵活储蓄与链上赚币无权限（10005）：整组为空，记入 lastSkipped，整体成功', () async {
      final fake = FakeAdapter((o, b) {
        if (o.uri.path == BybitPaths.earnPosition) {
          return jsonResponse('{"retCode":10005,"retMsg":"x"}');
        }
        return route(o);
      });
      final adapter = build(fake);
      final r = await adapter.fetchHoldings(fakeCredentials());
      final m = byKey((r as Ok<List<(ExchangeSubAccount, RawHolding)>>).value);
      expect(m.containsKey((ExchangeSubAccount.earn, 'ETH')), isFalse);
      // 定期理财仍在。
      expect(m[(ExchangeSubAccount.earn, 'USDT')], d('50'));
      expect(adapter.lastSkipped, ['灵活储蓄与链上赚币']);
    });

    test('两组理财都无权限：earn 为空，lastSkipped 按顺序记录两项', () async {
      final fake = FakeAdapter((o, b) {
        if (o.uri.path == BybitPaths.earnPosition ||
            o.uri.path == BybitPaths.fixedTermPosition) {
          return jsonResponse('{"retCode":10005,"retMsg":"x"}');
        }
        return route(o);
      });
      final adapter = build(fake);
      final r = await adapter.fetchHoldings(fakeCredentials());
      final m = byKey((r as Ok<List<(ExchangeSubAccount, RawHolding)>>).value);
      expect(m.keys.where((k) => k.$1 == ExchangeSubAccount.earn), isEmpty);
      expect(m[(ExchangeSubAccount.spot, 'USDT')], d('104.5'));
      expect(adapter.lastSkipped, ['灵活储蓄与链上赚币', '定期理财']);
    });

    test('理财接口限频（10006）：整体失败，不当作无权限', () async {
      final fake = FakeAdapter((o, b) {
        if (o.uri.path == BybitPaths.fixedTermPosition) {
          return jsonResponse('{"retCode":10006,"retMsg":"Too many visits"}');
        }
        return route(o);
      });
      final r = await build(fake).fetchHoldings(fakeCredentials());
      expect(
        (r as Err<List<(ExchangeSubAccount, RawHolding)>>).failure,
        isA<RateLimitedFailure>(),
      );
    });

    test('lastSkipped 每次调用重置', () async {
      var deny = true;
      final fake = FakeAdapter((o, b) {
        if (deny && o.uri.path == BybitPaths.fixedTermPosition) {
          return jsonResponse('{"retCode":10005,"retMsg":"x"}');
        }
        return route(o);
      });
      final adapter = build(fake);
      await adapter.fetchHoldings(fakeCredentials());
      expect(adapter.lastSkipped, ['定期理财']);
      deny = false;
      await adapter.fetchHoldings(fakeCredentials());
      expect(adapter.lastSkipped, isEmpty);
    });

    test('限频：HTTP 403（IP 访问过于频繁）按限频处理', () async {
      final fake = FakeAdapter((o, b) => jsonResponse('{}', status: 403));
      final r = await build(fake).fetchHoldings(fakeCredentials());
      expect(
        (r as Err<List<(ExchangeSubAccount, RawHolding)>>).failure,
        isA<RateLimitedFailure>(),
      );
    });

    test('时间偏差：校正后重试成功，只多一次时间请求', () async {
      // 设备时间比服务器慢很多；时间戳不在 [server - recv_window, server + 1000) 内时返回 10002。
      final serverMs = DateTime.utc(2026, 11, 12).millisecondsSinceEpoch;
      final clock = FixedClock(DateTime.utc(2017, 7, 1));
      final fake = FakeAdapter((o, b) {
        if (o.uri.path == BybitPaths.serverTime) return route(o);
        final ts = int.parse(o.headers['X-BAPI-TIMESTAMP'] as String);
        if (ts < serverMs - 5000 || ts >= serverMs + 1000) {
          return jsonResponse('{"retCode":10002,"retMsg":"x"}');
        }
        return route(o);
      });
      final r = await build(
        fake,
        clock: clock,
      ).fetchHoldings(fakeCredentials());
      expect(r, isA<Ok<List<(ExchangeSubAccount, RawHolding)>>>());
      expect(fake.paths.where((p) => p == BybitPaths.serverTime), hasLength(1));
    });

    test('校正后仍偏差返回 ClockSkewFailure', () async {
      final fake = FakeAdapter((o, b) {
        if (o.uri.path == BybitPaths.serverTime) return route(o);
        return jsonResponse('{"retCode":10002,"retMsg":"x"}');
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
      final fake = FakeAdapter((o, b) => route(o, perm: 'withdraw'));
      final adapter = build(fake);
      await adapter.verify(fakeCredentials());
      await adapter.fetchHoldings(fakeCredentials());
      expect(fake.paths, isNotEmpty);
      expect(pathsOutsideAllowlist(fake.paths, bybitReadOnlyPaths), isEmpty);
    });

    test('白名单路径不含动用资金的接口（资金余额查询的 transfer 为已登记的例外）', () {
      final bad = RegExp('order|trade|withdraw|transfer|convert');
      // 唯一例外：资金账户余额查询。路径分组名含 transfer，但本接口只查询余额，
      // 见 check_deps.dart 的 readOnlyPathAllowlist 与 docs/EXTERNAL_APIS.md。
      const exception = BybitPaths.fundBalance;
      for (final p in bybitReadOnlyPaths) {
        if (p == exception) {
          expect(p, contains('/query-account-coins-balance'));
          continue;
        }
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
    expect(a.id, ExchangeId.bybit);
    expect(a.needsPassphrase, isFalse);
    expect(BybitAdapter.notIncluded, isNotEmpty);
  });
}
