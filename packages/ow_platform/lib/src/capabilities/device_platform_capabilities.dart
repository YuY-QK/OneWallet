import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:ow_domain/ow_domain.dart';

import '../biometrics/device_biometric_auth.dart';
import '../keystore/device_hardware_key_store.dart';

/// 当前设备的 [PlatformCapabilities]。
///
/// 平台能力检测：
/// - `hardwareKeystore`：是否有可绑定生物识别的硬件密钥（M0-11）。
/// - `biometrics`：是否有可用的生物识别（M3-02）。
/// - `screenProtection`：Android 为 [ScreenProtection.block]，iOS 为
///   [ScreenProtection.detect]，其余 [ScreenProtection.none]（M4-04）。
/// - `camera`：移动端为 true，其余为 false。
///
/// 平台名称判断只在本包内进行；界面只读取这些能力。
final class DevicePlatformCapabilities implements PlatformCapabilities {
  /// 默认按 [defaultTargetPlatform] 判断；各字段供测试或探测结果指定。
  DevicePlatformCapabilities({
    TargetPlatform? platform,
    this.hardwareKeystore = false,
    this.biometrics = false,
    this.cameraOverride,
    this.screenProtectionOverride,
  }) : _platform = platform ?? defaultTargetPlatform;

  final TargetPlatform _platform;
  @override
  final bool hardwareKeystore;
  @override
  final bool biometrics;
  final bool? cameraOverride;
  final ScreenProtection? screenProtectionOverride;

  @override
  ScreenProtection get screenProtection =>
      screenProtectionOverride ??
      switch (_platform) {
        TargetPlatform.android => ScreenProtection.block,
        TargetPlatform.iOS => ScreenProtection.detect,
        _ => ScreenProtection.none,
      };

  @override
  bool get camera =>
      cameraOverride ??
      (_platform == TargetPlatform.android || _platform == TargetPlatform.iOS);

  /// 异步真实探测当前平台的硬件与生物识别能力。
  static Future<DevicePlatformCapabilities> probe({
    TargetPlatform? platform,
    MethodChannel? biometricsChannel,
    MethodChannel? keystoreChannel,
  }) async {
    final target = platform ?? defaultTargetPlatform;
    if (target != TargetPlatform.android && target != TargetPlatform.iOS) {
      return DevicePlatformCapabilities(
        platform: target,
        hardwareKeystore: false,
        biometrics: false,
        cameraOverride: false,
        screenProtectionOverride: ScreenProtection.none,
      );
    }

    final bio = DeviceBiometricAuth(channel: biometricsChannel);
    final isBioAvailable = await bio.isAvailable();

    final ks = DeviceHardwareKeyStore(channel: keystoreChannel);
    final isKsAvailable = await ks.isAvailable();

    return DevicePlatformCapabilities(
      platform: target,
      hardwareKeystore: isKsAvailable,
      biometrics: isBioAvailable,
      cameraOverride: true,
      screenProtectionOverride: target == TargetPlatform.android
          ? ScreenProtection.block
          : ScreenProtection.detect,
    );
  }
}
