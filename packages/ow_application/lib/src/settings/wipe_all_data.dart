import 'package:ow_domain/ow_domain.dart';

import '../vault/vault_constants.dart';

/// 清除本应用全部本地数据（P18、PRD 第 10 节）。
///
/// 严格按顺序执行：
/// 1. 关闭当前数据库连接（[DatabaseCloser.close]，若存在）；
/// 2. 删除数据库物理文件（[DatabaseDeleter.delete]，含 .db、-wal、-shm）；
/// 3. 删除本地保险库文件（[VaultStorage.delete]）；
/// 4. 清空安全存储中全部 `ow.` 凭据与密钥（[ClearableSecretStore.clearAll]）；
/// 5. 删除硬件密钥库中的主密钥包裹（[HardwareKeyStore.delete]）。
///
/// 设置页危险区与启动失败页两处清除入口共用此逻辑。
/// 操作不可撤销；完成后触发重新启动以进入全新初始状态。
final class WipeAllData {
  const WipeAllData({
    this.closer,
    required this.databaseDeleter,
    this.vaultStorage,
    this.secrets,
    this.hardwareKeyStore,
  });

  final DatabaseCloser? closer;
  final DatabaseDeleter databaseDeleter;
  final VaultStorage? vaultStorage;
  final ClearableSecretStore? secrets;
  final HardwareKeyStore? hardwareKeyStore;

  static const String _keyAlias = vaultMasterKeyHardwareAlias;

  Future<Result<void>> call({DatabaseCloser? closer}) async {
    try {
      final activeCloser = closer ?? this.closer;
      if (activeCloser != null) {
        await activeCloser.close();
      }
      await databaseDeleter.delete();
      await vaultStorage?.delete();
      await secrets?.clearAll();
      await hardwareKeyStore?.delete(_keyAlias);
      return const Ok(null);
    } catch (e) {
      return Err(UnknownFailure('清除本地数据失败: $e'));
    }
  }
}
