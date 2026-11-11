import 'package:ow_net/ow_net.dart';
import 'package:test/test.dart';

/// 假时钟：delay 只推进假时间，不真正等待。
class FakeClock {
  DateTime time = DateTime.utc(2026, 1, 1);
  DateTime now() => time;
  Future<void> delay(Duration d) async {
    // 让出一次事件循环，模拟真实的异步等待。
    await Future<void>.value();
    time = time.add(d);
  }
}

RateLimiter _limiter(FakeClock clock, int n, Duration window) => RateLimiter(
  maxRequests: n,
  window: window,
  now: clock.now,
  delay: clock.delay,
);

void main() {
  test('窗口内最多N次_超出的顺延到下一个窗口', () async {
    final clock = FakeClock();
    final limiter = _limiter(clock, 3, const Duration(seconds: 1));
    final starts = <DateTime>[];
    await Future.wait([
      for (var i = 0; i < 10; i++)
        limiter.run(() async => starts.add(clock.now())),
    ]);

    expect(starts, hasLength(10));
    // 任意长度为 window 的滑动区间内不超过 3 次
    for (final t in starts) {
      final inWindow = starts.where(
        (s) => !s.isBefore(t) && s.isBefore(t.add(const Duration(seconds: 1))),
      );
      expect(inWindow.length, lessThanOrEqualTo(3));
    }
    // 前 3 个在 t0，随后每 3 个顺延一个窗口
    final t0 = DateTime.utc(2026, 1, 1);
    expect(starts.take(3).every((s) => s == t0), isTrue);
    expect(starts[3], t0.add(const Duration(seconds: 1)));
    expect(starts[9], t0.add(const Duration(seconds: 3)));
  });

  test('排队顺序保持_先调用的先执行', () async {
    final clock = FakeClock();
    final limiter = _limiter(clock, 1, const Duration(seconds: 2));
    final order = <int>[];
    await Future.wait([
      for (var i = 0; i < 6; i++) limiter.run(() async => order.add(i)),
    ]);
    expect(order, [0, 1, 2, 3, 4, 5]);
  });

  test('返回任务的结果', () async {
    final limiter = _limiter(FakeClock(), 2, const Duration(seconds: 1));
    expect(await limiter.run(() async => 42), 42);
    expect(await limiter.run(() async => 'x'), 'x');
  });

  test('任务抛出异常_原样传出且不影响后续排队', () async {
    final limiter = _limiter(FakeClock(), 1, const Duration(seconds: 1));
    final failing = limiter.run<int>(() async => throw StateError('boom'));
    final next = limiter.run(() async => 7);
    await expectLater(failing, throwsStateError);
    expect(await next, 7);
  });

  test('窗口过去后名额恢复_无需等待', () async {
    final clock = FakeClock();
    final limiter = _limiter(clock, 1, const Duration(seconds: 1));
    await limiter.run(() async {});
    clock.time = clock.time.add(const Duration(seconds: 1));
    final before = clock.now();
    await limiter.run(() async {});
    expect(clock.now(), before);
  });

  test('参数非法_抛出ArgumentError', () {
    expect(
      () => RateLimiter(maxRequests: 0, window: const Duration(seconds: 1)),
      throwsArgumentError,
    );
    expect(
      () => RateLimiter(maxRequests: 1, window: Duration.zero),
      throwsArgumentError,
    );
  });
}
