import 'package:ow_domain/ow_domain.dart';

/// 清除本应用全部持久化数据（P18、PRD 第 10 节）。
///
/// 依次清空数据库所有数据表（[DatabaseWiper.wipe]）、删除本地保险库文件（若有），
/// 并清空安全存储中全部 `ow.` 凭据与密钥（[ClearableSecretStore.clearAll]）。
/// 操作不可撤销；完成后应用需回到初始引导状态。
final class WipeAllData {
  const WipeAllData({
    required this.databaseWiper,
    this.vaultStorage,
    this.secrets,
  });

  final DatabaseWiper databaseWiper;
  final VaultStorage? vaultStorage;
  final ClearableSecretStore? secrets;

  Future<Result<void>> call() async {
    await databaseWiper.wipe();
    await vaultStorage?.delete();
    await secrets?.clearAll();
    return const Ok(null);
  }
}
