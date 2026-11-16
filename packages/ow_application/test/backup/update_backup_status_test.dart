import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

import '../fakes/fake_repositories.dart';

void main() {
  group('UpdateBackupStatus', () {
    late InMemoryAccountRepository accounts;
    late UpdateBackupStatus useCase;

    setUp(() {
      accounts = InMemoryAccountRepository();
      useCase = UpdateBackupStatus(accounts: accounts);
    });

    test('updates backup status on an existing wallet account', () async {
      final wallet = Account.wallet(
        id: 'w1',
        name: 'My Wallet',
        colorIndex: 0,
        createdAt: DateTime.utc(2026, 11, 1),
      );
      await accounts.upsert(wallet);

      final verified = DateTime.utc(2026, 11, 15);
      final result = await useCase(
        accountId: 'w1',
        backup: BackupStatus(
          offlineBackedUp: true,
          offlineVerifiedAt: verified,
        ),
      );

      expect(result.isOk, isTrue);
      final updated = (result as Ok<Account>).value;
      expect(updated.backup.offlineBackedUp, isTrue);
      expect(updated.backup.offlineVerifiedAt, equals(verified));
      expect(updated.backup.keyless, isFalse);

      final persisted = await accounts.byId('w1');
      expect(persisted?.backup.offlineBackedUp, isTrue);
      expect(persisted?.backup.offlineVerifiedAt, equals(verified));
    });

    test('returns ValidationFailure when account does not exist', () async {
      final result = await useCase(
        accountId: 'non_existent',
        backup: const BackupStatus(offlineBackedUp: true),
      );

      expect(result.isOk, isFalse);
      expect(result, isA<Err<Account>>());
      final failure = (result as Err<Account>).failure;
      expect(
        failure,
        isA<ValidationFailure>().having(
          (f) => f.detail,
          'detail',
          'Account not found',
        ),
      );
    });

    test(
      'returns ValidationFailure when account is an exchange account',
      () async {
        final exchange = Account.exchange(
          id: 'e1',
          name: 'Binance',
          colorIndex: 1,
          createdAt: DateTime.utc(2026, 11, 1),
          exchange: ExchangeId.binance,
        );
        await accounts.upsert(exchange);

        final result = await useCase(
          accountId: 'e1',
          backup: const BackupStatus(offlineBackedUp: true),
        );

        expect(result.isOk, isFalse);
        expect(result, isA<Err<Account>>());
        final failure = (result as Err<Account>).failure;
        expect(
          failure,
          isA<ValidationFailure>().having(
            (f) => f.detail,
            'detail',
            'Account is not a wallet',
          ),
        );
      },
    );
  });
}
