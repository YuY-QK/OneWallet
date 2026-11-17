import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

import '../fakes/fake_adapters.dart';
import '../fakes/fake_repositories.dart';
import '../fakes/fake_services.dart';

void main() {
  late InMemoryAccountRepository accounts;
  late FakeCredentialRepository credentials;
  late FakeAdapterRegistry adapters;
  late FakeClock clock;
  late AddExchangeAccount add;

  setUp(() {
    accounts = InMemoryAccountRepository();
    credentials = FakeCredentialRepository();
    adapters = FakeAdapterRegistry();
    clock = FakeClock(DateTime.utc(2026, 1, 1, 12, 0));
    add = AddExchangeAccount(
      accounts: accounts,
      credentials: credentials,
      adapters: adapters,
      ids: SequentialIds(),
      clock: clock,
    );
  });

  ExchangeCredentials creds({
    String key = 'test-api-key',
    String secret = 'test-api-secret',
    String? passphrase,
  }) => ExchangeCredentials(
    apiKey: Sensitive.fromString(key),
    apiSecret: Sensitive.fromString(secret),
    passphrase: passphrase != null ? Sensitive.fromString(passphrase) : null,
  );

  group('AddExchangeAccount 成功流程', () {
    test('Binance 正常添加_写入账户与凭据并返回账户', () async {
      final res = await add(
        name: '  币安主账户  ',
        exchange: ExchangeId.binance,
        credentials: creds(),
      );

      expect(res, isA<Ok<Account>>());
      final account = (res as Ok<Account>).value;
      expect(account.id, 'id-1');
      expect(account.name, '币安主账户');
      expect(account.type, AccountType.exchange);
      expect(account.exchange, ExchangeId.binance);
      expect(account.colorIndex, 0); // 首次添加轮换为 0
      expect(account.createdAt, DateTime.utc(2026, 1, 1, 12, 0));

      // 验证账户持久化
      final savedAcc = await accounts.byId('id-1');
      expect(savedAcc, equals(account));

      // 验证凭据持久化
      final savedCreds = await credentials.load('id-1');
      expect(savedCreds, isNotNull);
      expect(savedCreds!.apiKey.useString((s) => s), 'test-api-key');
      expect(savedCreds.apiSecret.useString((s) => s), 'test-api-secret');
      expect(savedCreds.passphrase, isNull);

      // 验证调用了适配器的 verify
      expect(
        adapters.exchangeFake(ExchangeId.binance).verifyCalls,
        hasLength(1),
      );
    });

    test('OKX 正常添加_需包含 Passphrase 并正确持久化', () async {
      final res = await add(
        name: 'OKX 账户',
        exchange: ExchangeId.okx,
        credentials: creds(passphrase: 'okx-pass-123'),
        colorIndex: 4,
        note: '测试备注',
      );

      expect(res, isA<Ok<Account>>());
      final account = (res as Ok<Account>).value;
      expect(account.exchange, ExchangeId.okx);
      expect(account.colorIndex, 4);
      expect(account.note, '测试备注');

      final savedCreds = await credentials.load(account.id);
      expect(savedCreds?.passphrase?.useString((s) => s), 'okx-pass-123');
    });

    test('颜色轮换_已有 3 个账户时新建账户使用序号 3', () async {
      for (var i = 0; i < 3; i++) {
        await accounts.upsert(
          Account.exchange(
            id: 'acc-$i',
            name: '账户$i',
            colorIndex: i,
            createdAt: DateTime.utc(2026, 1, 1),
            exchange: ExchangeId.binance,
          ),
        );
      }

      final res = await add(
        name: '第四个账户',
        exchange: ExchangeId.bybit,
        credentials: creds(),
      );

      expect((res as Ok<Account>).value.colorIndex, 3);
    });
  });

  group('AddExchangeAccount 参数校验', () {
    test('名称为空或全空白_返回 ValidationFailure', () async {
      final r1 = await add(
        name: '',
        exchange: ExchangeId.binance,
        credentials: creds(),
      );
      expect(r1, isA<Err<Account>>());
      expect((r1 as Err).failure, isA<ValidationFailure>());

      final r2 = await add(
        name: '   ',
        exchange: ExchangeId.binance,
        credentials: creds(),
      );
      expect(r2, isA<Err<Account>>());
    });

    test('名称超过 30 字符_返回 ValidationFailure', () async {
      final r = await add(
        name: '一' * 31,
        exchange: ExchangeId.binance,
        credentials: creds(),
      );
      expect(r, isA<Err<Account>>());
      expect((r as Err).failure.detail, contains('1–30 字'));
    });

    test('颜色序号无效_返回 ValidationFailure', () async {
      final r1 = await add(
        name: '账户',
        exchange: ExchangeId.binance,
        credentials: creds(),
        colorIndex: -1,
      );
      expect(r1, isA<Err<Account>>());

      final r2 = await add(
        name: '账户',
        exchange: ExchangeId.binance,
        credentials: creds(),
        colorIndex: 8,
      );
      expect(r2, isA<Err<Account>>());
    });

    test('API Key 为空_返回 ValidationFailure', () async {
      final r = await add(
        name: '账户',
        exchange: ExchangeId.binance,
        credentials: creds(key: '   '),
      );
      expect(r, isA<Err<Account>>());
      expect((r as Err).failure.detail, contains('API Key 不能为空'));
    });

    test('API Secret 为空_返回 ValidationFailure', () async {
      final r = await add(
        name: '账户',
        exchange: ExchangeId.binance,
        credentials: creds(secret: '   '),
      );
      expect(r, isA<Err<Account>>());
      expect((r as Err).failure.detail, contains('API Secret 不能为空'));
    });

    test('OKX 缺少 Passphrase_返回 ValidationFailure', () async {
      final r = await add(
        name: 'OKX 账户',
        exchange: ExchangeId.okx,
        credentials: creds(passphrase: null),
      );
      expect(r, isA<Err<Account>>());
      expect((r as Err).failure.detail, contains('Passphrase 不能为空'));
    });
  });

  group('AddExchangeAccount 适配器校验与覆盖', () {
    test('verifyCredentials 为 true_适配器返回失败时整体返回失败且不写入存储', () async {
      adapters.exchangeFake(ExchangeId.binance).verifyResult = const Err(
        UnauthorizedFailure('API Key 无效'),
      );

      final res = await add(
        name: '失败账户',
        exchange: ExchangeId.binance,
        credentials: creds(),
        verifyCredentials: true,
      );

      expect(res, isA<Err<Account>>());
      expect((res as Err).failure, isA<UnauthorizedFailure>());
      expect(await accounts.watchAll().first, isEmpty);
      expect(await credentials.load('id-1'), isNull);
    });

    test('verifyCredentials 为 false_跳过适配器 verify 检查并保存', () async {
      adapters.exchangeFake(ExchangeId.binance).verifyResult = const Err(
        UnauthorizedFailure('API Key 无效'),
      );

      final res = await add(
        name: '强制保存账户',
        exchange: ExchangeId.binance,
        credentials: creds(),
        verifyCredentials: false,
      );

      expect(res, isA<Ok<Account>>());
      expect(adapters.exchangeFake(ExchangeId.binance).verifyCalls, isEmpty);
      expect(await accounts.byId('id-1'), isNotNull);
      expect(await credentials.load('id-1'), isNotNull);
    });

    test('独立 verify 方法调用适配器检查', () async {
      adapters.exchangeFake(ExchangeId.bybit).verifyResult = const Ok(
        CredentialCheck(permission: KeyPermission.canTrade),
      );

      final check = await add.verify(
        exchange: ExchangeId.bybit,
        credentials: creds(),
      );

      expect(check, isA<Ok<CredentialCheck>>());
      expect(
        (check as Ok<CredentialCheck>).value.permission,
        KeyPermission.canTrade,
      );
    });
  });
}
