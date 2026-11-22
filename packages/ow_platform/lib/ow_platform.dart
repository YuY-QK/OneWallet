/// OneWallet 平台适配层。
///
/// 目前包含：系统安全存储（[SecureSecretStore]）、平台能力
/// （[DevicePlatformCapabilities]）、加密数据库的打开（[SqlCipherDatabaseOpener]）、
/// 保险库文件的原子读写（[FileVaultStorage]）、系统生物识别（[DeviceBiometricAuth]）、
/// 硬件密钥（[DeviceHardwareKeyStore]）、防截屏与录屏检测（[DeviceScreenGuard]）、
/// 设备完整性检查（[DevicePlatformIntegrity]）。
library;

export 'src/biometrics/device_biometric_auth.dart';
export 'src/capabilities/device_platform_capabilities.dart';
export 'src/database/database_opener.dart';
export 'src/integrity/device_platform_integrity.dart';
export 'src/keystore/device_hardware_key_store.dart';
export 'src/screenguard/device_screen_guard.dart';
export 'src/secret/clearable_secret_store.dart';
export 'src/secret/secure_secret_store.dart';
export 'src/vault/file_vault_storage.dart';
