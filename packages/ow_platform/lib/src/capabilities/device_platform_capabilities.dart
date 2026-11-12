import 'package:flutter/foundation.dart';
import 'package:ow_domain/ow_domain.dart';

/// 当前设备的 [PlatformCapabilities]。
///
/// M0-13 阶段只给出保守的静态值：
/// - `hardwareKeystore`、`biometrics` 一律为 false。
///   TODO(M0-11)：由硬件密钥与生物识别插件探测真实值。
/// - `screenProtection`：Android 为 [ScreenProtection.block]，iOS 为
///   [ScreenProtection.detect]，其余 [ScreenProtection.none]。
///   TODO(M3-02)：随防截屏插件实现，确认真实能力。
/// - `camera`：移动端 true，其余 false。TODO(M3-02)：改为真实探测。
///
/// 平台名称判断只在本包内进行；界面只读取这些能力。
final class DevicePlatformCapabilities implements PlatformCapabilities {
  /// 默认按 [defaultTargetPlatform] 判断；[platform] 供测试指定。
  DevicePlatformCapabilities({TargetPlatform? platform})
    : _platform = platform ?? defaultTargetPlatform;

  final TargetPlatform _platform;

  @override
  bool get hardwareKeystore => false;

  @override
  bool get biometrics => false;

  @override
  ScreenProtection get screenProtection => switch (_platform) {
    TargetPlatform.android => ScreenProtection.block,
    TargetPlatform.iOS => ScreenProtection.detect,
    _ => ScreenProtection.none,
  };

  @override
  bool get camera =>
      _platform == TargetPlatform.android || _platform == TargetPlatform.iOS;
}
