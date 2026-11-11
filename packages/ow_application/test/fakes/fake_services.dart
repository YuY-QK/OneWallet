import 'package:ow_domain/ow_domain.dart';

/// 可手动拨动的时钟。
final class FakeClock implements Clock {
  FakeClock([DateTime? start]) : now = start ?? DateTime.utc(2026, 11, 11, 8);

  DateTime now;

  void advance(Duration d) => now = now.add(d);

  @override
  DateTime nowUtc() => now;
}

/// 依次生成 `id-1`、`id-2`……
final class SequentialIds implements IdGenerator {
  int _n = 0;

  @override
  String newId() => 'id-${++_n}';
}

/// 记录收到的等待时长，不真正等待。
final class RecordingDelay {
  final durations = <Duration>[];

  Future<void> call(Duration d) async {
    durations.add(d);
  }
}

/// 测试用的合法格式地址（假数据，不对应任何真实钱包）。
abstract final class TestAddresses {
  static const evmA = '0x1111111111111111111111111111111111111111';
  static const evmB = '0x2222222222222222222222222222222222222222';
  static const evmC = '0xaAaAaAaaAaAaAaaAaAAAAAAAAaaaAaAaAaaAaaAa';
  static const tron = 'TAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
  static const btc = 'bc1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq';
}
