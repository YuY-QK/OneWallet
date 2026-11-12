/// OneWallet 平台适配层。
///
/// 目前包含：系统安全存储（[SecureSecretStore]）、平台能力
/// （[DevicePlatformCapabilities]）、加密数据库的打开（[SqlCipherDatabaseOpener]）。
/// 硬件密钥、生物识别、防截屏、文件导出由 M0-11、M3-02 等任务加入。
library;

export 'src/capabilities/device_platform_capabilities.dart';
export 'src/database/database_opener.dart';
export 'src/secret/clearable_secret_store.dart';
export 'src/secret/secure_secret_store.dart';
