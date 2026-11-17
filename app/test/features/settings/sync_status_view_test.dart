import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/features/settings/controllers/sync_status_view.dart';
import 'package:ow_domain/ow_domain.dart';

void main() {
  group('buildSyncStatusView', () {
    final t0 = DateTime.utc(2026, 11, 15, 12, 0);

    final a1 = Account(
      id: 'w1',
      name: 'Uni 钱包',
      type: AccountType.wallet,
      colorIndex: 0,
      createdAt: t0,
    );
    final a2 = Account(
      id: 'ex1',
      name: 'OKX',
      type: AccountType.exchange,
      exchange: ExchangeId.okx,
      colorIndex: 1,
      createdAt: t0,
    );
    final a3 = Account(
      id: 'ex2',
      name: 'Binance',
      type: AccountType.exchange,
      exchange: ExchangeId.binance,
      colorIndex: 2,
      createdAt: t0,
    );

    test('空账户列表_返回空状态', () {
      final view = buildSyncStatusView(
        accounts: [],
        latestRecords: [],
        lastSuccessPerAccount: {},
        recentLogs: [],
        syncingAccountIds: {},
      );

      expect(view.accounts, isEmpty);
      expect(view.logs, isEmpty);
      expect(view.lastFullSyncAt, isNull);
      expect(view.lastFullSyncDuration, isNull);
      expect(view.isFullSyncRunning, isFalse);
      expect(view.failedCount, 0);
      expect(view.runningCount, 0);
    });

    test('多账户状态归一化_正确识别成功失败进行中及凭据失效', () {
      final r1 = SyncRecord(
        accountId: 'w1',
        startedAt: t0,
        finishedAt: t0.add(const Duration(seconds: 2)),
        status: SyncStatus.success,
      );
      final r2 = SyncRecord(
        accountId: 'ex1',
        startedAt: t0,
        finishedAt: t0.add(const Duration(seconds: 1)),
        status: SyncStatus.failed,
        failureType: 'KeyExpiredFailure',
      );
      final r3 = SyncRecord(
        accountId: 'ex2',
        startedAt: t0,
        finishedAt: t0.add(const Duration(seconds: 3)),
        status: SyncStatus.failed,
        failureType: 'NetworkFailure',
      );

      final view = buildSyncStatusView(
        accounts: [a1, a2, a3],
        latestRecords: [r1, r2, r3],
        lastSuccessPerAccount: {
          'w1': t0,
          'ex1': t0.subtract(const Duration(hours: 2)),
        },
        recentLogs: [r3, r2, r1],
        syncingAccountIds: {'w1'},
      );

      expect(view.accounts, hasLength(3));
      // w1 正在同步中
      final item1 = view.accounts[0];
      expect(item1.account.id, 'w1');
      expect(item1.isRunning, isTrue);
      expect(item1.isSuccess, isFalse);
      expect(item1.isFailed, isFalse);

      // ex1 失败且为 KeyExpiredFailure
      final item2 = view.accounts[1];
      expect(item2.account.id, 'ex1');
      expect(item2.isRunning, isFalse);
      expect(item2.isFailed, isTrue);
      expect(item2.isKeyIssue, isTrue);
      expect(item2.lastSuccessAt, t0.subtract(const Duration(hours: 2)));

      // ex2 失败但为 NetworkFailure
      final item3 = view.accounts[2];
      expect(item3.account.id, 'ex2');
      expect(item3.isRunning, isFalse);
      expect(item3.isFailed, isTrue);
      expect(item3.isKeyIssue, isFalse);
      expect(item3.lastSuccessAt, isNull);

      expect(view.failedCount, 2);
      expect(view.runningCount, 1);
    });

    test('同步日志映射_正确关联账户名与耗时_已删除账户名称为null', () {
      final r1 = SyncRecord(
        accountId: 'w1',
        startedAt: t0,
        finishedAt: t0.add(const Duration(milliseconds: 1200)),
        status: SyncStatus.success,
      );
      final rUnknown = SyncRecord(
        accountId: 'deleted_account',
        startedAt: t0,
        finishedAt: t0.add(const Duration(milliseconds: 350)),
        status: SyncStatus.failed,
        failureType: 'NetworkFailure',
      );

      final view = buildSyncStatusView(
        accounts: [a1],
        latestRecords: [r1],
        lastSuccessPerAccount: {},
        recentLogs: [rUnknown, r1],
        syncingAccountIds: {},
      );

      expect(view.logs, hasLength(2));
      expect(view.logs[0].accountName, isNull);
      expect(view.logs[0].duration, const Duration(milliseconds: 350));
      expect(view.logs[1].accountName, 'Uni 钱包');
      expect(view.logs[1].duration, const Duration(milliseconds: 1200));
    });

    test('全量同步耗时_使用明确传入的值_未传入时为null', () {
      final r1 = SyncRecord(
        accountId: 'w1',
        startedAt: t0,
        finishedAt: t0.add(const Duration(seconds: 4)),
        status: SyncStatus.success,
      );
      final r2 = SyncRecord(
        accountId: 'ex1',
        startedAt: t0.add(const Duration(seconds: 1)),
        finishedAt: t0.add(const Duration(seconds: 11)),
        status: SyncStatus.success,
      );

      // 1. 未传入全量同步状态时，不推导，保持为 null
      final viewNone = buildSyncStatusView(
        accounts: [a1, a2],
        latestRecords: [r1, r2],
        lastSuccessPerAccount: {},
        recentLogs: [],
        syncingAccountIds: {},
      );
      expect(viewNone.lastFullSyncAt, isNull);
      expect(viewNone.lastFullSyncDuration, isNull);

      // 2. 传入显式值
      final viewExplicit = buildSyncStatusView(
        accounts: [a1, a2],
        latestRecords: [r1, r2],
        lastSuccessPerAccount: {},
        recentLogs: [],
        syncingAccountIds: {},
        lastFullSyncFinishedAt: t0.add(const Duration(minutes: 5)),
        lastFullSyncDuration: const Duration(seconds: 8),
        isFullSyncRunning: true,
      );
      expect(viewExplicit.lastFullSyncAt, t0.add(const Duration(minutes: 5)));
      expect(viewExplicit.lastFullSyncDuration, const Duration(seconds: 8));
      expect(viewExplicit.isFullSyncRunning, isTrue);
    });
  });
}
