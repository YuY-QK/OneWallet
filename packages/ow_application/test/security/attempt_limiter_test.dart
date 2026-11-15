import 'package:ow_application/src/security/attempt_limiter.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

import '../fakes/fake_services.dart';

final class FakeSecretStore implements SecretStore {
  final Map<String, String> data = {};

  @override
  Future<void> write(String key, String value) async {
    data[key] = value;
  }

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> delete(String key) async {
    data.remove(key);
  }
}

void main() {
  group('T1 AttemptLimiter', () {
    late FakeSecretStore store;
    late FakeClock clock;
    late AttemptLimiter limiter;

    setUp(() {
      store = FakeSecretStore();
      clock = FakeClock(DateTime.utc(2026, 11, 15, 12, 0));
      limiter = AttemptLimiter(
        store: store,
        clock: clock,
        keyPrefix: 'ow.vault.unlock',
      );
    });

    test('第 1–4 次失败返回 WrongPasswordFailure', () async {
      for (var i = 1; i <= 4; i++) {
        final res = await limiter.recordFailure();
        expect(res.isOk, isFalse);
        expect((res as Err<void>).failure, isA<WrongPasswordFailure>());
        final state = await limiter.check();
        expect(state, Unlocked(i));
      }
    });

    test('第 5 次失败返回 LockedOutFailure 且锁定 1 分钟', () async {
      for (var i = 1; i <= 4; i++) {
        await limiter.recordFailure();
      }
      final res = await limiter.recordFailure();
      expect(res.isOk, isFalse);
      final failure = (res as Err<void>).failure;
      expect(failure, isA<LockedOutFailure>());
      final expectedUntil = clock.nowUtc().add(const Duration(minutes: 1));
      expect((failure as LockedOutFailure).until, expectedUntil);

      final state = await limiter.check();
      expect(state, Locked(expectedUntil));
    });

    test(
      '锁定期间 check 为 Locked，且再次 recordFailure 仍返回 LockedOutFailure',
      () async {
        for (var i = 1; i <= 5; i++) {
          await limiter.recordFailure();
        }
        clock.advance(const Duration(seconds: 30));
        final state = await limiter.check();
        expect(state, isA<Locked>());

        final res = await limiter.recordFailure();
        expect((res as Err<void>).failure, isA<LockedOutFailure>());
      },
    );

    test('锁定结束后失败次数不清零：第 6 次锁 2 分钟，第 7 次 4 分钟，上限 60 分钟', () async {
      for (var i = 1; i <= 5; i++) {
        await limiter.recordFailure();
      }

      // 1 分钟后解锁
      clock.advance(const Duration(minutes: 1, seconds: 1));
      expect(await limiter.check(), const Unlocked(5));

      // 第 6 次失败：锁定 2 分钟
      final res6 = await limiter.recordFailure();
      expect((res6 as Err<void>).failure, isA<LockedOutFailure>());
      final until6 = clock.nowUtc().add(const Duration(minutes: 2));
      expect((res6.failure as LockedOutFailure).until, until6);

      // 2 分钟后
      clock.advance(const Duration(minutes: 2, seconds: 1));
      expect(await limiter.check(), const Unlocked(6));

      // 第 7 次失败：锁定 4 分钟
      final res7 = await limiter.recordFailure();
      final until7 = clock.nowUtc().add(const Duration(minutes: 4));
      expect(((res7 as Err<void>).failure as LockedOutFailure).until, until7);

      // 连续失败直到达到 60 分钟上限
      // 8: 8m, 9: 16m, 10: 32m, 11: 64m -> 60m
      for (var f = 8; f <= 15; f++) {
        clock.advance(const Duration(minutes: 65));
        final res = await limiter.recordFailure();
        final lockoutMin = ((res as Err<void>).failure as LockedOutFailure)
            .until
            .difference(clock.nowUtc())
            .inMinutes;
        expect(lockoutMin, lessThanOrEqualTo(60));
        if (f >= 11) {
          expect(lockoutMin, 60);
        }
      }
    });

    test('成功后清零', () async {
      for (var i = 1; i <= 3; i++) {
        await limiter.recordFailure();
      }
      expect(await limiter.check(), const Unlocked(3));

      await limiter.recordSuccess();
      expect(await limiter.check(), const Unlocked(0));
      expect(store.data.isEmpty, isTrue);
    });

    test('把时钟往回调不能提前解锁', () async {
      for (var i = 1; i <= 5; i++) {
        await limiter.recordFailure();
      }

      // 恶意将系统时钟调回 1 小时前
      clock.now = clock.nowUtc().subtract(const Duration(hours: 1));

      // check 发现时间比 recorded_at 早，校正 until 为 now + remainingMs
      final state = await limiter.check();
      expect(state, isA<Locked>());
      final newUntil = (state as Locked).until;
      expect(newUntil, clock.nowUtc().add(const Duration(minutes: 1)));
      expect(newUntil.isAfter(clock.nowUtc()), isTrue);
    });

    test('键值损坏时锁 60 分钟', () async {
      store.data['ow.vault.unlock.failures'] = 'not-a-number';
      final state = await limiter.check();
      expect(state, isA<Locked>());
      final lockedUntil = (state as Locked).until;
      expect(lockedUntil.difference(clock.nowUtc()).inMinutes, 60);
    });
  });
}
