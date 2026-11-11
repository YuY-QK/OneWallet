/// 按"每个时间窗口最多 [maxRequests] 次"限速的异步排队器。
///
/// 滑动窗口；任务按调用 [run] 的先后顺序获得名额（先进先出）。
/// 获得名额后任务立即开始执行，不等待前一个任务结束，因此并发度由调用方控制。
/// 时间来源与等待方式可注入，测试用假时钟即可，不依赖真实时间。
class RateLimiter {
  /// [maxRequests] 与 [window] 必须为正，否则抛出 [ArgumentError]（程序缺陷）。
  RateLimiter({
    required this.maxRequests,
    required this.window,
    DateTime Function()? now,
    Future<void> Function(Duration)? delay,
  }) : _now = now ?? DateTime.now,
       _delay = delay ?? Future<void>.delayed {
    if (maxRequests <= 0) {
      throw ArgumentError.value(maxRequests, 'maxRequests', '必须大于 0');
    }
    if (window <= Duration.zero) {
      throw ArgumentError.value(window, 'window', '必须大于 0');
    }
  }

  final int maxRequests;
  final Duration window;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _delay;

  /// 最近一个窗口内已放行的时刻，按时间升序。
  final List<DateTime> _granted = [];
  Future<void> _tail = Future<void>.value();

  /// 排队等到名额后执行 [task]，返回其结果；[task] 抛出的异常原样传给调用方。
  Future<T> run<T>(Future<T> Function() task) async {
    final slot = _tail.then((_) => _acquire());
    // 名额队列不因某次等待失败而中断。
    _tail = slot.then((_) {}, onError: (Object _) {});
    await slot;
    return task();
  }

  Future<void> _acquire() async {
    while (true) {
      final now = _now();
      _granted.removeWhere((t) => now.difference(t) >= window);
      if (_granted.length < maxRequests) {
        _granted.add(now);
        return;
      }
      await _delay(_granted.first.add(window).difference(now));
    }
  }
}
