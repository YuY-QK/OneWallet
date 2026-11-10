import 'dart:typed_data';

import '../core/result.dart';

/// 敏感页面的防截屏能力等级。
enum ScreenProtection {
  /// 可以阻止截屏和录屏（Android）。
  block,

  /// 只能检测到录屏或投屏并隐藏内容（iOS）。
  detect,

  /// 做不到；界面需显示警示并缩短明文显示时长。
  none,
}

/// 当前平台具备哪些能力。界面据此降级，不根据平台名称判断。
abstract interface class PlatformCapabilities {
  /// 是否有受硬件保护、可绑定生物识别的密钥存储。
  bool get hardwareKeystore;

  /// 是否有可用的生物识别。
  bool get biometrics;

  ScreenProtection get screenProtection;

  /// 是否有摄像头可用于扫码。
  bool get camera;
}

/// 用硬件密钥包裹一小段数据（保险库主密钥）。
///
/// 解包时系统会要求用户在场验证。生物识别信息变更后，已有的包裹失效。
abstract interface class HardwareKeyStore {
  Future<Result<Uint8List>> wrap(String keyAlias, Uint8List plaintext);

  /// [reason] 显示在系统验证弹窗中。
  Future<Result<Uint8List>> unwrap(
    String keyAlias,
    Uint8List wrapped, {
    required String reason,
  });

  Future<void> delete(String keyAlias);
}

/// 应用级安全存储：数据库密钥、API Secret、PIN 校验值等。
///
/// 仅本设备可读，不随系统备份。读取不要求每次生物识别。
abstract interface class SecretStore {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
}

/// 敏感页面的显示保护。
abstract interface class ScreenGuard {
  Future<void> enable();
  Future<void> disable();

  /// 是否正在录屏或投屏。
  Stream<bool> get captureActive;
}

/// 文件的导出与选取。手机用系统分享面板，桌面用"另存为"对话框。
abstract interface class FileExporter {
  /// 返回用户是否完成了保存。
  Future<bool> export(String suggestedName, Uint8List bytes);

  Future<Uint8List?> pick(List<String> extensions);
}
