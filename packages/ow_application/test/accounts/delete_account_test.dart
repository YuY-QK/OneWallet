import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

import '../fakes/fake_repositories.dart';

void main() {
  late InMemoryAccountRepository accounts;
  late FakeCredentialRepository credentials;
  late DeleteAccount deleteAccount;

  final now = DateTime.utc(2026, 11, 15);
  final walletAccount = Account.wallet(
    id: 'w1',
    name: '钱包',
    colorIndex: 0,
    createdAt: now,
  );
  final exchangeAccount = Account.exchange(
    id: 'e1',
    name: '币安',
    colorIndex: 1,
    createdAt: now,
    exchange: ExchangeId.binance,
  );

  setUp(() async {
    accounts = InMemoryAccountRepository();
    credentials = FakeCredentialRepository();
    deleteAccount = DeleteAccount(accounts: accounts, credentials: credentials);

    await accounts.upsert(walletAccount);
    await accounts.upsert(exchangeAccount);
    credentials.seed(
      'e1',
      ExchangeCredentials(
        apiKey: Sensitive.fromString('key'),
        apiSecret: Sensitive.fromString('secret'),
      ),
    );
  });

  group('DeleteAccount', () {
    test('删除钱包账户_成功移除且不影响其他账户', () async {
      final res = await deleteAccount('w1');
      expect(res.isOk, isTrue);

      expect(await accounts.byId('w1'), isNull);
      expect(await accounts.byId('e1'), isNotNull);
    });

    test('删除交易所账户_同时清理凭据存储', () async {
      expect(await credentials.load('e1'), isNotNull);

      final res = await deleteAccount('e1');
      expect(res.isOk, isTrue);

      expect(await accounts.byId('e1'), isNull);
      expect(await credentials.load('e1'), isNull);
    });

    test('删除不存在的账户_幂等且返回成功', () async {
      final res = await deleteAccount('non_existent');
      expect(res.isOk, isTrue);

      expect(await accounts.byId('w1'), isNotNull);
      expect(await accounts.byId('e1'), isNotNull);
    });

    test('凭据删除抛异常时_先删凭据失败导致中止_账户与凭据仍然存在', () async {
      credentials.deleteError = Exception('Secure storage IO error');

      expect(() => deleteAccount('e1'), throwsA(isA<Exception>()));

      // 账户必须仍然保留，不能已被删除
      expect(await accounts.byId('e1'), isNotNull);
      // 凭据也仍在
      expect(await credentials.load('e1'), isNotNull);
    });
  });
}
