import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'clearable_secret_store.dart';

/// 基于 `flutter_secure_storage` 的 [ClearableSecretStore]。
///
/// 存放数据库密钥、数据源 API Key、自定义端点等（SECURITY_DESIGN 6.2）。
/// 读取不要求每次做生物识别，否则后台同步无法进行。
///
/// 具体选项：
/// - iOS / macOS：钥匙串可访问性 `first_unlock_this_device`（首次解锁后可读，
///   条目带 ThisDeviceOnly，不随备份迁移到其他设备）；`synchronizable: false`
///   （不进 iCloud 钥匙串）；不使用访问控制标志（不要求每次生物识别）。
/// - Android：`AndroidOptions` 的默认存储，AES-GCM 加密数据，包裹密钥由
///   Android Keystore 保护。`resetOnError: false`：出错时抛异常而不是静默清空
///   全部条目，否则数据库密钥丢失会让整个库永久不可读；让启动流程显示错误页。
/// - 键名必须以 [keyPrefix] 开头，否则抛 [ArgumentError]；由调用方使用完整键名
///   （如 `ow.db.key`），便于 [clearAll] 只清理本应用的条目。
///
/// 本类依赖平台通道，只在设备上可验证；单元测试通过
/// `FlutterSecureStorage.setMockInitialValues` 验证前缀与清除逻辑。
final class SecureSecretStore implements ClearableSecretStore {
  SecureSecretStore({FlutterSecureStorage? storage})
    : _storage = storage ?? _defaultStorage;

  /// 全部键名的统一前缀。
  static const keyPrefix = 'ow.';

  static const _defaultStorage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      synchronizable: false,
    ),
    mOptions: MacOsOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      synchronizable: false,
    ),
    aOptions: AndroidOptions(resetOnError: false),
  );

  final FlutterSecureStorage _storage;

  @override
  Future<void> write(String key, String value) async {
    _checkKey(key);
    await _storage.write(key: key, value: value);
  }

  @override
  Future<String?> read(String key) async {
    _checkKey(key);
    return _storage.read(key: key);
  }

  @override
  Future<void> delete(String key) async {
    _checkKey(key);
    await _storage.delete(key: key);
  }

  @override
  Future<void> clearAll() async {
    final all = await _storage.readAll();
    final ours = all.keys.where((k) => k.startsWith(keyPrefix)).toList();
    for (final key in ours) {
      await _storage.delete(key: key);
    }
  }

  void _checkKey(String key) {
    if (!key.startsWith(keyPrefix)) {
      // 只报键名，不涉及值。
      throw ArgumentError.value(key, 'key', '键名必须以 $keyPrefix 开头');
    }
  }
}
