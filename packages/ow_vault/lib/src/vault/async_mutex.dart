import 'dart:async';

/// 最简单的异步互斥：按调用顺序逐个执行 [run] 的动作。
///
/// 动作抛出的异常原样传给它自己的调用方，不影响排在后面的动作。不可重入：
/// 在动作内部再次调用同一实例的 [run] 会死锁。
final class AsyncMutex {
  Future<void> _tail = Future<void>.value();

  /// 等前面的动作全部结束后执行 [action]，返回它的结果。
  Future<T> run<T>(Future<T> Function() action) {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    return previous.then((_) => action()).whenComplete(done.complete);
  }
}
