import '../core/result.dart';

/// 系统生物识别验证（应用锁使用）。实现在 `ow_platform`（M3）。
abstract interface class BiometricAuth {
  /// 设备是否支持且已登记生物识别。
  Future<bool> isAvailable();

  /// 弹出系统验证，[reason] 显示在弹窗中。
  ///
  /// 验证通过返回 `Ok`。失败时：设备不支持返回 `UnsupportedFailure`；
  /// 用户取消或验证未通过返回其他 `Failure`，界面据此停留在 PIN 输入。
  Future<Result<void>> authenticate({required String reason});
}

/// 设备完整性检查（M3-08）。
abstract interface class DeviceIntegrity {
  /// 设备看起来已越狱或已 root。只用于提示，不阻止使用。
  Future<bool> looksCompromised();
}
