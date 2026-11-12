import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/features/overview/controllers/overview_view.dart';
import 'package:onewallet/features/shared/sync_failure.dart';
import 'package:ow_domain/ow_domain.dart';

Account _account(String id) => Account(
  id: id,
  type: AccountType.wallet,
  name: id,
  colorIndex: 0,
  createdAt: DateTime.utc(2026, 11, 1),
);

void main() {
  test('buildOverviewView_上次同步时间取账户级最近成功时间中最晚的', () {
    final view = buildOverviewView(
      accounts: [_account('a1'), _account('a2')],
      // 同步记录里已经没有成功记录（被裁剪），只有失败。
      records: [
        SyncRecord(
          accountId: 'a1',
          startedAt: DateTime.utc(2026, 11, 12, 11),
          finishedAt: DateTime.utc(2026, 11, 12, 11),
          status: SyncStatus.failed,
          failureType: 'NetworkFailure',
        ),
      ],
      lastSuccess: {
        'a1': DateTime.utc(2026, 11, 12, 9),
        'a2': DateTime.utc(2026, 11, 12, 10),
        'deleted': DateTime.utc(2026, 11, 12, 11, 30),
      },
      syncing: false,
    );
    expect(view.status, OverviewStatus.content);
    expect(view.lastSyncedAt, DateTime.utc(2026, 11, 12, 10));
  });

  test('buildOverviewView_没有任何成功时间_视为无缓存', () {
    final view = buildOverviewView(
      accounts: [_account('a1')],
      records: const [],
      lastSuccess: const {},
      syncing: true,
    );
    expect(view.status, OverviewStatus.loading);
    expect(view.lastSyncedAt, isNull);
  });

  test('failureFromTypeName_不支持的两种原因各自还原', () {
    final platform = failureFromTypeName('UnsupportedFailure');
    final notIntegrated = failureFromTypeName(
      'UnsupportedFailure.notIntegrated',
    );
    expect((platform as UnsupportedFailure).reason, UnsupportedReason.platform);
    expect(
      (notIntegrated as UnsupportedFailure).reason,
      UnsupportedReason.notIntegrated,
    );
    expect(failureFromTypeName('???'), isA<UnknownFailure>());
  });
}
