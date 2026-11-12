import 'package:ow_domain/ow_domain.dart';

/// 取交易所服务器时间（毫秒，自 Unix 纪元起）。
typedef ServerTimeFetcher = Future<Result<int>> Function();

/// 请求时间戳的来源：注入的 [Clock] 加上一个偏移。
///
/// 设备时间与服务器偏差过大时交易所会拒绝签名（各家的错误码见 error_mapping.dart）。
/// 此时调用 [resync] 取服务器时间、算出偏移，之后的时间戳都按偏移校正。
/// 偏移只保存在内存里，不持久化。
final class ClockSync {
  ClockSync({required this.clock, required this.fetchServerTime});

  /// 设备时间来源（注入，便于测试）。
  final Clock clock;

  /// 取服务器时间的函数（各家的公开时间接口）。
  final ServerTimeFetcher fetchServerTime;
  int _offsetMs = 0;

  /// 当前偏移（服务器时间减设备时间），毫秒。
  int get offsetMs => _offsetMs;

  /// 校正后的"现在"，毫秒时间戳。
  int nowMs() => clock.nowUtc().millisecondsSinceEpoch + _offsetMs;

  /// 校正后的"现在"。
  DateTime nowUtc() =>
      DateTime.fromMillisecondsSinceEpoch(nowMs(), isUtc: true);

  /// 向服务器取时间并更新偏移。成功返回新偏移；失败返回取时间时的失败，偏移不变。
  ///
  /// 设备时间取请求发出前后两个时刻的中点，抵消一半往返延迟。
  Future<Result<int>> resync() async {
    final before = clock.nowUtc().millisecondsSinceEpoch;
    final server = await fetchServerTime();
    final after = clock.nowUtc().millisecondsSinceEpoch;
    return switch (server) {
      Ok<int>(:final value) => () {
        _offsetMs = value - (before + (after - before) ~/ 2);
        return Ok(_offsetMs);
      }(),
      Err<int>(:final failure) => Err(failure),
    };
  }
}
