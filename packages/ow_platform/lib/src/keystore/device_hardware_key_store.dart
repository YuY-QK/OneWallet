import 'package:flutter/services.dart';
import 'package:ow_domain/ow_domain.dart';

/// 用硬件密钥包裹一小段数据（保险库主密钥）。
///
/// 通过平台通道 `ow.platform/hardware_key_store` 与原生安全框架交互：
/// - iOS: 钥匙串条目，访问控制设为 `.biometryCurrentSet`
/// - Android: AndroidKeyStore AES-256-GCM 密钥，绑定生物识别
final class DeviceHardwareKeyStore implements HardwareKeyStore {
  DeviceHardwareKeyStore({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('ow.platform/hardware_key_store');

  final MethodChannel _channel;

  /// 设备是否支持受硬件保护且可绑定生物识别的密钥存储。
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
  Future<Result<Uint8List>> wrap(String keyAlias, Uint8List plaintext) async {
    try {
      final res = await _channel.invokeMethod<Uint8List>('wrap', {
        'alias': keyAlias,
        'plaintext': plaintext,
      });
      if (res != null) {
        return Ok(res);
      }
      return const Err(UnknownFailure('wrap_returned_null'));
    } on MissingPluginException {
      return const Err(UnsupportedFailure('当前平台不支持硬件密钥'));
    } on PlatformException catch (e) {
      if (e.code == 'UNSUPPORTED') {
        return const Err(UnsupportedFailure('当前设备不支持硬件密钥'));
      }
      if (e.code == 'BIOMETRIC_UNAVAILABLE' ||
          e.code == 'USER_CANCELED' ||
          e.code == 'KEY_PERMANENTLY_INVALIDATED') {
        return Err(BiometricUnavailableFailure(e.message));
      }
      return Err(UnknownFailure(e.message));
    }
  }

  @override
  Future<Result<Uint8List>> unwrap(
    String keyAlias,
    Uint8List wrapped, {
    required String reason,
  }) async {
    try {
      final res = await _channel.invokeMethod<Uint8List>('unwrap', {
        'alias': keyAlias,
        'wrapped': wrapped,
        'reason': reason,
      });
      if (res != null) {
        return Ok(res);
      }
      return const Err(UnknownFailure('unwrap_returned_null'));
    } on MissingPluginException {
      return const Err(UnsupportedFailure('当前平台不支持硬件密钥'));
    } on PlatformException catch (e) {
      if (e.code == 'UNSUPPORTED') {
        return const Err(UnsupportedFailure('当前设备不支持硬件密钥'));
      }
      if (e.code == 'BIOMETRIC_UNAVAILABLE' ||
          e.code == 'USER_CANCELED' ||
          e.code == 'KEY_PERMANENTLY_INVALIDATED') {
        return Err(BiometricUnavailableFailure(e.message));
      }
      return Err(UnknownFailure(e.message));
    }
  }

  @override
  Future<void> delete(String keyAlias) async {
    try {
      await _channel.invokeMethod<void>('delete', {'alias': keyAlias});
    } on MissingPluginException {
      // 桌面端或测试环境不支持
    } on PlatformException {
      // 忽略平台异常
    }
  }
}
