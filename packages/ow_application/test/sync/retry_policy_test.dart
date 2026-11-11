import 'dart:async';

import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

import '../fakes/fake_services.dart';

/// 依次返回 [results] 的动作，记录调用次数。
final class _Scripted {
  _Scripted(this.results);

  final List<Result<int>> results;
  int calls = 0;

  Future<Result<int>> call() async {
    final i = calls < results.length ? calls : results.length - 1;
    calls++;
    return results[i];
  }
}

void main() {
  late RecordingDelay delay;
  late RetryPolicy policy;

  setUp(() {
    delay = RecordingDelay();
    policy = RetryPolicy(delay: delay.call);
  });

  test('RetryPolicy_一直限频_按1、2、4秒退避且最多重试3次', () async {
    final action = _Scripted([const Err(RateLimitedFailure())]);
    final result = await policy(action.call);

    expect(delay.durations, const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
    ]);
    expect(action.calls, 4);
    expect(
      result.when(ok: (_) => null, err: (f) => f),
      isA<RateLimitedFailure>(),
    );
  });

  test('RetryPolicy_网络失败后成功_返回成功值并停止重试', () async {
    final action = _Scripted([const Err(NetworkFailure()), const Ok(7)]);
    final result = await policy(action.call);

    expect(result.valueOrNull, 7);
    expect(action.calls, 2);
    expect(delay.durations, const [Duration(seconds: 1)]);
  });

  test('RetryPolicy_凭据无效_不重试', () async {
    final action = _Scripted([const Err(UnauthorizedFailure())]);
    final result = await policy(action.call);

    expect(action.calls, 1);
    expect(delay.durations, isEmpty);
    expect(result.isOk, isFalse);
  });

  test('RetryPolicy_首次成功_不等待', () async {
    final action = _Scripted([const Ok(1)]);
    expect((await policy(action.call)).valueOrNull, 1);
    expect(delay.durations, isEmpty);
  });

  test('RetryPolicy_已取消_不再发起重试', () async {
    final cancellation = SyncCancellation()..cancel();
    final action = _Scripted([const Err(RateLimitedFailure())]);
    await policy(action.call, cancellation: cancellation);

    expect(action.calls, 1);
    expect(delay.durations, isEmpty);
  });

  test('RetryPolicy_等待中被取消_打断等待且不再尝试', () async {
    final never = Completer<void>();
    final cancellation = SyncCancellation();
    final waiting = RetryPolicy(
      delay: (d) {
        cancellation.cancel();
        return never.future;
      },
    );
    final action = _Scripted([const Err(NetworkFailure())]);
    final result = await waiting(action.call, cancellation: cancellation);

    expect(action.calls, 1);
    expect(result.isOk, isFalse);
  });

  test('isRetryable_各失败类型_只有限频与网络可重试', () {
    expect(RetryPolicy.isRetryable(const RateLimitedFailure()), isTrue);
    expect(RetryPolicy.isRetryable(const NetworkFailure()), isTrue);
    expect(RetryPolicy.isRetryable(const ServiceDownFailure()), isFalse);
    expect(RetryPolicy.isRetryable(const UnauthorizedFailure()), isFalse);
  });

  test('SyncCancellation_重复取消_无副作用', () async {
    final c = SyncCancellation();
    expect(c.isCancelled, isFalse);
    c
      ..cancel()
      ..cancel();
    expect(c.isCancelled, isTrue);
    await c.whenCancelled;
  });
}
