import 'package:ow_domain/ow_domain.dart';

import 'set_up_pin.dart';
import 'verify_pin.dart';

/// 修改应用锁 PIN 码。
final class ChangePin {
  ChangePin({required this.verifyPin, required this.setUpPin});

  final VerifyPin verifyPin;
  final SetUpPin setUpPin;

  /// 验证 [oldPin] 后将应用锁 PIN 更新为 [newPin]。
  Future<Result<void>> call({
    required Sensitive oldPin,
    required Sensitive newPin,
  }) async {
    // 1. 验证旧 PIN
    final verifyRes = await verifyPin(oldPin);
    if (verifyRes case Err(:final failure)) {
      return Err(failure);
    }

    // 2. 设置新 PIN（覆盖模式）
    return await setUpPin(newPin, overwrite: true);
  }
}
