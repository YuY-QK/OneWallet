import 'package:decimal/decimal.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

import '../fakes/fake_repositories.dart';
import '../fakes/fake_services.dart';

void main() {
  group('buildBackupChecklistData', () {
    final now = DateTime.utc(2026, 11, 16, 12);

    test('classifies wallets according to R34 and R35', () {
      final wNone = Account.wallet(
        id: 'w_none',
        name: 'None',
        colorIndex: 0,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final wKeyless = Account.wallet(
        id: 'w_keyless',
        name: 'Keyless',
        colorIndex: 1,
        createdAt: DateTime.utc(2026, 1, 2),
        backup: const BackupStatus(keyless: true),
      );
      final wVault = Account.wallet(
        id: 'w_vault',
        name: 'Vault',
        colorIndex: 2,
        createdAt: DateTime.utc(2026, 1, 3),
        vaultItemId: 'item-1',
      );
      final wOffline = Account.wallet(
        id: 'w_offline',
        name: 'Offline',
        colorIndex: 3,
        createdAt: DateTime.utc(2026, 1, 4),
        backup: BackupStatus(
          offlineBackedUp: true,
          offlineVerifiedAt: now.subtract(const Duration(days: 30)),
        ),
      );
      final wDual = Account.wallet(
        id: 'w_dual',
        name: 'Dual',
        colorIndex: 4,
        createdAt: DateTime.utc(2026, 1, 5),
        vaultItemId: 'item-2',
        backup: BackupStatus(
          offlineBackedUp: true,
          offlineVerifiedAt: now.subtract(const Duration(days: 10)),
        ),
      );
      // Keyless wallet that was also saved to vault shows as inVault (green)
      final wKeylessVault = Account.wallet(
        id: 'w_kl_vault',
        name: 'Keyless in Vault',
        colorIndex: 5,
        createdAt: DateTime.utc(2026, 1, 6),
        vaultItemId: 'item-3',
        backup: const BackupStatus(keyless: true),
      );

      final data = buildBackupChecklistData(
        accounts: [wNone, wKeyless, wVault, wOffline, wDual, wKeylessVault],
        accountValuations: const {},
        settings: const AppSettings(),
        now: now,
      );

      expect(data.totalWallets, equals(6));
      expect(data.backedUpWallets, equals(4));
      expect(data.pendingCount, equals(2));
      expect(
        data.pendingWallets.map((e) => e.account.id),
        containsAllInOrder(['w_keyless', 'w_none']),
      );
      expect(
        data.completedWallets.map((e) => e.account.id),
        containsAll(['w_vault', 'w_offline', 'w_dual', 'w_kl_vault']),
      );
    });

    test('R36: 180-day overdue check on offline backups', () {
      final wNullVerified = Account.wallet(
        id: 'w1',
        name: 'Null Verified',
        colorIndex: 0,
        createdAt: DateTime.utc(2026, 1, 1),
        backup: const BackupStatus(
          offlineBackedUp: true,
          offlineVerifiedAt: null,
        ),
      );
      final wFresh = Account.wallet(
        id: 'w2',
        name: 'Fresh Verified',
        colorIndex: 0,
        createdAt: DateTime.utc(2026, 1, 1),
        backup: BackupStatus(
          offlineBackedUp: true,
          offlineVerifiedAt: now.subtract(const Duration(days: 179)),
        ),
      );
      final wOverdue = Account.wallet(
        id: 'w3',
        name: 'Overdue Verified',
        colorIndex: 0,
        createdAt: DateTime.utc(2026, 1, 1),
        backup: BackupStatus(
          offlineBackedUp: true,
          offlineVerifiedAt: now.subtract(const Duration(days: 180)),
        ),
      );
      final wVaultOnly = Account.wallet(
        id: 'w4',
        name: 'Vault Only',
        colorIndex: 0,
        createdAt: DateTime.utc(2026, 1, 1),
        vaultItemId: 'v1',
      );

      final data = buildBackupChecklistData(
        accounts: [wNullVerified, wFresh, wOverdue, wVaultOnly],
        accountValuations: const {},
        settings: const AppSettings(),
        now: now,
      );

      final byId = {
        for (final item in data.completedWallets) item.account.id: item,
      };
      expect(byId['w1']!.isOverdue, isTrue);
      expect(byId['w1']!.daysSinceVerification, isNull);

      expect(byId['w2']!.isOverdue, isFalse);
      expect(byId['w2']!.daysSinceVerification, equals(179));

      expect(byId['w3']!.isOverdue, isTrue);
      expect(byId['w3']!.daysSinceVerification, equals(180));

      expect(byId['w4']!.isOverdue, isFalse);
      expect(byId['w4']!.daysSinceVerification, isNull);
    });

    test('R37: excludes exchange accounts from checklist', () {
      final w1 = Account.wallet(
        id: 'w1',
        name: 'Wallet 1',
        colorIndex: 0,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final e1 = Account.exchange(
        id: 'e1',
        name: 'Binance',
        colorIndex: 1,
        createdAt: DateTime.utc(2026, 1, 2),
        exchange: ExchangeId.binance,
      );

      final data = buildBackupChecklistData(
        accounts: [w1, e1],
        accountValuations: const {},
        settings: const AppSettings(),
        now: now,
      );

      expect(data.totalWallets, equals(1));
      expect(data.pendingWallets.length, equals(1));
      expect(data.pendingWallets.first.account.id, equals('w1'));
      expect(data.completedWallets, isEmpty);
    });

    test('R38: detects unexported vault changes', () {
      final w1 = Account.wallet(
        id: 'w1',
        name: 'Wallet 1',
        colorIndex: 0,
        createdAt: DateTime.utc(2026, 1, 1),
        vaultItemId: 'v1',
      );

      // 1. No changes recorded
      var data = buildBackupChecklistData(
        accounts: [w1],
        accountValuations: const {},
        settings: const AppSettings(),
        now: now,
      );
      expect(data.hasUnexportedVaultChanges, isFalse);

      // 2. Vault changed, never exported
      data = buildBackupChecklistData(
        accounts: [w1],
        accountValuations: const {},
        settings: AppSettings(vaultChangedAt: DateTime.utc(2026, 11, 1)),
        now: now,
      );
      expect(data.hasUnexportedVaultChanges, isTrue);

      // 3. Vault changed, then exported later
      data = buildBackupChecklistData(
        accounts: [w1],
        accountValuations: const {},
        settings: AppSettings(
          vaultChangedAt: DateTime.utc(2026, 11, 1),
          lastBackupExportedAt: DateTime.utc(2026, 11, 2),
        ),
        now: now,
      );
      expect(data.hasUnexportedVaultChanges, isFalse);

      // 4. Vault changed after last export
      data = buildBackupChecklistData(
        accounts: [w1],
        accountValuations: const {},
        settings: AppSettings(
          vaultChangedAt: DateTime.utc(2026, 11, 5),
          lastBackupExportedAt: DateTime.utc(2026, 11, 2),
        ),
        now: now,
      );
      expect(data.hasUnexportedVaultChanges, isTrue);
    });

    test('sorting: pending by valuation desc, name asc; completed by createdAt desc', () {
      final w1 = Account.wallet(
        id: 'w1',
        name: 'Beta',
        colorIndex: 0,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final w2 = Account.wallet(
        id: 'w2',
        name: 'Alpha',
        colorIndex: 1,
        createdAt: DateTime.utc(2026, 1, 2),
      );
      final w3 = Account.wallet(
        id: 'w3',
        name: 'Gamma',
        colorIndex: 2,
        createdAt: DateTime.utc(2026, 1, 3),
      );

      final c1 = Account.wallet(
        id: 'c1',
        name: 'Completed Older',
        colorIndex: 3,
        createdAt: DateTime.utc(2026, 1, 10),
        vaultItemId: 'v1',
      );
      final c2 = Account.wallet(
        id: 'c2',
        name: 'Completed Newer',
        colorIndex: 4,
        createdAt: DateTime.utc(2026, 1, 20),
        vaultItemId: 'v2',
      );

      final data = buildBackupChecklistData(
        accounts: [w1, w2, w3, c1, c2],
        accountValuations: {
          'w1': Decimal.parse('100'),
          'w2': Decimal.parse(
            '100',
          ), // same valuation as w1, but 'Alpha' < 'Beta'
          'w3': Decimal.parse('500'), // highest valuation
        },
        settings: const AppSettings(),
        now: now,
      );

      expect(data.pendingWallets.map((e) => e.account.id).toList(), [
        'w3',
        'w2',
        'w1',
      ]);
      expect(data.completedWallets.map((e) => e.account.id).toList(), [
        'c2',
        'c1',
      ]);
    });
  });

  group('WatchBackupChecklist', () {
    test(
      'emits checklist data and updates when accounts or prices change',
      () async {
        final accounts = InMemoryAccountRepository();
        final holdings = InMemoryHoldingRepository();
        final prices = InMemoryPriceRepository();
        final settings = InMemorySettingsRepository();
        final clock = FakeClock(DateTime.utc(2026, 11, 16));

        final useCase = WatchBackupChecklist(
          accounts: accounts,
          holdings: holdings,
          prices: prices,
          settings: settings,
          clock: clock,
        );

        final stream = useCase();
        final emissions = <BackupChecklistData>[];
        final sub = stream.listen(emissions.add);

        await Future<void>.delayed(Duration.zero);
        expect(emissions.length, equals(1));
        expect(emissions.first.isEmpty, isTrue);

        final wallet = Account.wallet(
          id: 'w1',
          name: 'Wallet 1',
          colorIndex: 0,
          createdAt: DateTime.utc(2026, 11, 1),
        );
        await accounts.upsert(wallet);
        await Future<void>.delayed(Duration.zero);

        expect(emissions.last.totalWallets, equals(1));
        expect(emissions.last.pendingWallets.length, equals(1));
        expect(
          emissions.last.pendingWallets.first.account.name,
          equals('Wallet 1'),
        );

        await sub.cancel();
      },
    );
  });
}
