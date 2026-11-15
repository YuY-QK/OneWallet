import 'package:flutter/services.dart';
import 'package:ow_domain/ow_domain.dart';

/// 系统生物识别验证（应用锁使用）。
///
/// 通过平台通道 `ow.platform/biometrics` 与原生系统框架交互。
final class DeviceBiometricAuth implements BiometricAuth {
  DeviceBiometricAuth({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('ow.platform/biometrics');

  final MethodChannel _channel;

  @override
  Future<bool> isAvailable() async {
    try {
      final res = await _channel.invokeMethod<bool>('isAvailable');
      return res ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<Result<void>> authenticate({required String reason}) async {
    try {
      final res = await _channel.invokeMethod<bool>('authenticate', {
        'reason': reason,
      });
      if (res == true) {
        return const Ok(null);
      } else {
        return const Err(ValidationFailure('biometric_auth_failed'));
      }
    } on MissingPluginException {
      return const Err(UnsupportedFailure('当前平台不支持生物识别'));
    } on PlatformException catch (e) {
      if (e.code == 'UNSUPPORTED' || e.code == 'NOT_AVAILABLE') {
        return const Err(UnsupportedFailure('设备未开启或不支持生物识别'));
      }
      return Err(ValidationFailure(e.message ?? 'biometric_auth_failed'));
    }
  }
}
