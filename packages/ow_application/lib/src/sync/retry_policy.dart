import 'dart:async';

import 'package:ow_domain/ow_domain.dart';

import 'sync_cancellation.dart';

/// 等待指定时长。测试注入不真正等待的实现。
typedef DelayFn = Future<void> Function(Duration duration);

Future<void> _realDelay(Duration d) => Future<void>.delayed(d);

/// 限频与网络失败的指数退避重试（PRD R17、TECH_DESIGN 5.2）。
///
/// 首次失败后依次等待 1、2、4 秒再试，最多重试 [maxRetries] 次（共 4 次尝试）。
/// 只重试 [RateLimitedFailure] 与 [NetworkFailure]；其他失败立即返回。
final class RetryPolicy {
  /// [delay] 默认真实等待；[baseDelay] 为第一次重试前的等待时长，之后逐次翻倍。
  const RetryPolicy({
    this._delay = _realDelay,
    this.maxRetries = 3,
    this.baseDelay = const Duration(seconds: 1),
  });

  final DelayFn _delay;

  /// 最多重试次数，不含首次尝试。
  final int maxRetries;

  /// 第一次重试前的等待时长。
  final Duration baseDelay;

  /// 执行 [action]，按规则重试，返回最后一次的结果。
  ///
  /// [cancellation] 被取消后不再发起新的尝试，正在进行的等待会被打断，
  /// 返回最近一次的失败结果。[action] 本身抛出的异常（程序缺陷）不重试、原样抛出。
  Future<Result<T>> call<T>(
    Future<Result<T>> Function() action, {
    SyncCancellation? cancellation,
  }) async {
    var result = await action();
    for (var attempt = 0; attempt < maxRetries; attempt++) {
      final failure = switch (result) {
        Err<T>(:final failure) => failure,
        Ok<T>() => null,
      };
      if (failure == null || !isRetryable(failure)) return result;
      if (cancellation?.isCancelled ?? false) return result;
      await _wait(baseDelay * (1 << attempt), cancellation);
      if (cancellation?.isCancelled ?? false) return result;
      result = await action();
    }
    return result;
  }

  /// [failure] 是否属于可重试的类型。
  static bool isRetryable(Failure failure) =>
      failure is RateLimitedFailure || failure is NetworkFailure;

  Future<void> _wait(Duration d, SyncCancellation? cancellation) {
    final wait = _delay(d);
    if (cancellation == null) return wait;
    return Future.any([wait, cancellation.whenCancelled]);
  }
}
