import 'package:ow_domain/ow_domain.dart';

/// 能一次清除本应用全部条目的 [SecretStore]。
///
/// 领域层的 [SecretStore] 只有读、写、删单个键。首次启动清理钥匙串残留
/// （SECURITY_DESIGN 第 11 节 S4）需要"清除全部 `ow.` 条目"，所以在平台层
/// 扩一个接口，不改 `ow_domain`。
abstract interface class ClearableSecretStore implements SecretStore {
  /// 删除键名以 `ow.` 开头的全部条目。其他条目不动。
  Future<void> clearAll();
}
