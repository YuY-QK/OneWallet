import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

SyncRecord record({
  String accountId = 'acc-1',
  DateTime? startedAt,
  DateTime? finishedAt,
  SyncStatus status = SyncStatus.success,
  String? failureType,
}) => SyncRecord(
  accountId: accountId,
  startedAt: startedAt ?? DateTime.utc(2026, 4, 1, 10),
  finishedAt: finishedAt ?? DateTime.utc(2026, 4, 1, 10, 0, 5),
  status: status,
  failureType: failureType,
);

void main() {
  group('SyncRecord', () {
    test('SyncRecord_成功记录_字段可读', () {
      final r = record();
      expect(r.accountId, 'acc-1');
      expect(r.startedAt, DateTime.utc(2026, 4, 1, 10));
      expect(r.finishedAt, DateTime.utc(2026, 4, 1, 10, 0, 5));
      expect(r.status, SyncStatus.success);
      expect(r.failureType, isNull);
    });

    test('SyncRecord_进行中_finishedAt为null', () {
      final r = SyncRecord(
        accountId: 'acc-1',
        startedAt: DateTime.utc(2026, 4, 1, 10),
        status: SyncStatus.running,
      );
      expect(r.finishedAt, isNull);
      expect(r.status, SyncStatus.running);
    });

    test('SyncRecord_失败记录_记录失败类型名', () {
      final r = record(
        status: SyncStatus.failed,
        failureType: 'RateLimitedFailure',
      );
      expect(r.status, SyncStatus.failed);
      expect(r.failureType, 'RateLimitedFailure');
    });

    test('SyncRecord_字段相同_相等且哈希相同', () {
      final a = record(
        status: SyncStatus.failed,
        failureType: 'NetworkFailure',
      );
      final b = record(
        status: SyncStatus.failed,
        failureType: 'NetworkFailure',
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('SyncRecord_任一字段不同_不相等', () {
      final base = record();
      expect(record(accountId: 'acc-2'), isNot(base));
      expect(record(startedAt: DateTime.utc(2026, 4, 1, 11)), isNot(base));
      expect(record(finishedAt: DateTime.utc(2026, 4, 1, 10, 1)), isNot(base));
      expect(record(status: SyncStatus.failed), isNot(base));
      expect(record(failureType: 'NetworkFailure'), isNot(base));
    });

    test('toString_含账户与状态名', () {
      expect(
        record(status: SyncStatus.failed).toString(),
        'SyncRecord(acc-1, failed)',
      );
    });
  });
}
