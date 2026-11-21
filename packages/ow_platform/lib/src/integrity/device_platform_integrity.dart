import 'package:flutter/services.dart';
import 'package:ow_domain/ow_domain.dart';

/// 设备完整性检查的平台实现（M3-08）。
///
/// 通过平台通道 `ow.platform/device_integrity` 与原生系统交互：
/// - Android: 检测 root 迹象（su 路径、test-keys 签名）及调试器连接状态（isDebuggerConnected、FLAG_DEBUGGABLE、ADB_ENABLED）
/// - iOS: 检测越狱迹象（Cydia 等特征文件路径、沙盒外目录写权限、常见越狱 Scheme）
/// - 桌面端与测试环境：平台通道未实现或异常时默认返回 false（不误报）
final class DevicePlatformIntegrity implements DeviceIntegrity {
  DevicePlatformIntegrity({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('ow.platform/device_integrity');

  final MethodChannel _channel;

  @override
  Future<bool> looksCompromised() async {
    try {
      final result = await _channel.invokeMethod<bool>('looksCompromised');
      return result ?? false;
    } on MissingPluginException {
      // 桌面端或测试环境未注册通道，默认返回 false
      return false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
