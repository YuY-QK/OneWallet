import 'dart:async';

/// 一次同步的取消信号。由发起方持有并调用 [cancel]，执行方在各检查点读取。
///
/// 只能从未取消变为已取消，不可复位；每次全量同步应新建一个实例。
final class SyncCancellation {
  final Completer<void> _completer = Completer<void>();

  /// 是否已取消。
  bool get isCancelled => _completer.isCompleted;

  /// 取消时完成的 Future，用于打断退避等待。
  Future<void> get whenCancelled => _completer.future;

  /// 发出取消信号。重复调用无副作用。
  void cancel() {
    if (!_completer.isCompleted) _completer.complete();
  }
}
