import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

import '../fakes/fake_adapters.dart';
import '../fakes/fake_repositories.dart';

void main() {
  late InMemoryAccountRepository accounts;
  late FakeCredentialRepository credentials;
  late FakeAdapterRegistry adapters;
  late ReplaceExchangeCredentials replace;

  setUp(() async {
    accounts = InMemoryAccountRepository();
    credentials = FakeCredentialRepository();
    adapters = FakeAdapterRegistry();
    replace = ReplaceExchangeCredentials(
      accounts: accounts,
      credentials: credentials,
      adapters: adapters,
    );

    await accounts.upsert(
      Account.exchange(
        id: 'acc-binance',
        name: '币安主账户',
        colorIndex: 0,
        createdAt: DateTime.utc(2026, 1, 1),
        exchange: ExchangeId.binance,
      ),
    );
    await accounts.upsert(
      Account.wallet(
        id: 'acc-wallet',
        name: '钱包账户',
        colorIndex: 1,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
  });

  ExchangeCredentials creds({
    String key = 'new-api-key',
    String secret = 'new-api-secret',
    String? passphrase,
  }) => ExchangeCredentials(
    apiKey: Sensitive.fromString(key),
    apiSecret: Sensitive.fromString(secret),
    passphrase: passphrase != null ? Sensitive.fromString(passphrase) : null,
  );

  group('ReplaceExchangeCredentials', () {
    test('正常更换凭据_成功写入存储', () async {
      final res = await replace(
        accountId: 'acc-binance',
        credentials: creds(key: 'updated-key', secret: 'updated-secret'),
      );

      expect(res, isA<Ok<void>>());
      final saved = await credentials.load('acc-binance');
      expect(saved?.apiKey.useString((s) => s), 'updated-key');
      expect(saved?.apiSecret.useString((s) => s), 'updated-secret');
      expect(
        adapters.exchangeFake(ExchangeId.binance).verifyCalls,
        hasLength(1),
      );
    });

    test('账户不存在_返回 ValidationFailure', () async {
      final res = await replace(
        accountId: 'non-existent',
        credentials: creds(),
      );
      expect(res, isA<Err<void>>());
      expect((res as Err).failure.detail, contains('账户不存在'));
    });

    test('账户是钱包类型_返回 ValidationFailure', () async {
      final res = await replace(accountId: 'acc-wallet', credentials: creds());
      expect(res, isA<Err<void>>());
      expect((res as Err).failure.detail, contains('不是交易所账户'));
    });

    test('凭据字段为空_返回 ValidationFailure', () async {
      final r1 = await replace(
        accountId: 'acc-binance',
        credentials: creds(key: ''),
      );
      expect(r1, isA<Err<void>>());

      final r2 = await replace(
        accountId: 'acc-binance',
        credentials: creds(secret: ''),
      );
      expect(r2, isA<Err<void>>());
    });

    test('适配器校验失败_返回失败且不更新凭据', () async {
      adapters.exchangeFake(ExchangeId.binance).verifyResult = const Err(
        UnauthorizedFailure('凭据已失效'),
      );

      final res = await replace(
        accountId: 'acc-binance',
        credentials: creds(key: 'invalid-key'),
        verifyCredentials: true,
      );

      expect(res, isA<Err<void>>());
      expect((res as Err).failure, isA<UnauthorizedFailure>());
      expect(await credentials.load('acc-binance'), isNull);
    });

    test('verifyCredentials 为 false_跳过适配器校验直接更新凭据', () async {
      adapters.exchangeFake(ExchangeId.binance).verifyResult = const Err(
        UnauthorizedFailure('凭据已失效'),
      );

      final res = await replace(
        accountId: 'acc-binance',
        credentials: creds(key: 'forced-key'),
        verifyCredentials: false,
      );

      expect(res, isA<Ok<void>>());
      expect(adapters.exchangeFake(ExchangeId.binance).verifyCalls, isEmpty);
      final saved = await credentials.load('acc-binance');
      expect(saved?.apiKey.useString((s) => s), 'forced-key');
    });

    test('独立 verify 方法调用适配器检查', () async {
      adapters.exchangeFake(ExchangeId.binance).verifyResult = const Ok(
        CredentialCheck(permission: KeyPermission.readOnly),
      );

      final check = await replace.verify(
        exchange: ExchangeId.binance,
        credentials: creds(),
      );

      expect(check, isA<Ok<CredentialCheck>>());
    });
  });
}
