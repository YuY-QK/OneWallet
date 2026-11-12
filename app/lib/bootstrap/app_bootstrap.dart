import 'dart:math';

import 'package:drift/drift.dart' show QueryExecutor;
import 'package:ow_data/ow_data.dart';
import 'package:ow_platform/ow_platform.dart';

import 'logger.dart';

/// 数据库密钥在 [SecretStore] 中的键名。值是 64 位十六进制（32 字节）。
const databaseKeyStoreKey = 'ow.db.key';

/// 启动失败的原因。每一种在错误页上有对应文案。
enum BootstrapFailureKind {
  /// 系统安全存储读写失败（例如设备尚未首次解锁、Keystore 异常）。
  secureStorageFailed,

  /// 数据库文件在，但安全存储里没有它的密钥（例如换机恢复、数据被清理）。
  /// 此时无法解密，也不能自动重建，否则会静默丢弃用户的数据。
  databaseKeyMissing,

  /// 数据库打不开：密钥不匹配、文件损坏、不是 SQLCipher 构建等。
  databaseOpenFailed,
}

/// 启动流程的结果。
sealed class BootstrapResult {
  const BootstrapResult();
}

/// 启动成功：持有已打开的数据库与安全存储。
final class BootstrapSuccess extends BootstrapResult {
  const BootstrapSuccess({required this.database, required this.secrets});

  final OwDatabase database;
  final ClearableSecretStore secrets;
}

/// 启动失败：只带原因，不带异常文本（可能含路径等信息，也避免泄漏密钥）。
final class BootstrapFailure extends BootstrapResult {
  const BootstrapFailure(this.kind);

  final BootstrapFailureKind kind;
}

/// 应用启动流程（TECH_DESIGN 6.1）：
///
/// 1. 数据库文件不存在 -> 清除安全存储里全部 `ow.` 条目（iOS 卸载后钥匙串会
///    残留，SECURITY_DESIGN 第 11 节 S4 的默认方案），再生成新的数据库密钥；
/// 2. 数据库文件存在 -> 读取密钥；读不到则失败，**不重建数据库**；
/// 3. 用密钥打开数据库并执行一条语句，确认真的可读；失败则关闭并返回失败。
///
/// 调用前须已初始化 Flutter 绑定（平台通道依赖它）。
Future<BootstrapResult> bootstrapApp({
  required ClearableSecretStore secrets,
  required DatabaseOpener opener,
  OwLogger? logger,
  Random? random,
  OwDatabase Function(QueryExecutor executor)? databaseFactory,
}) async {
  final log = logger ?? OwLogger();
  final String keyHex;
  try {
    final existing = await opener.exists();
    if (!existing) {
      await secrets.clearAll();
      keyHex = _newKeyHex(random ?? Random.secure());
      await secrets.write(databaseKeyStoreKey, keyHex);
      log.info('boot', '首次启动：已生成新的数据库密钥');
    } else {
      final stored = await secrets.read(databaseKeyStoreKey);
      if (stored == null || stored.isEmpty) {
        log.error('boot', '数据库存在但密钥缺失');
        return const BootstrapFailure(BootstrapFailureKind.databaseKeyMissing);
      }
      keyHex = stored;
    }
  } on Object catch (e) {
    // 只记类型：异常文本可能含平台细节。
    log.error('boot', '安全存储失败：${e.runtimeType}');
    return const BootstrapFailure(BootstrapFailureKind.secureStorageFailed);
  }

  OwDatabase? db;
  try {
    final executor = await opener.open(keyHex: keyHex);
    db = (databaseFactory ?? OwDatabase.new)(executor);
    // 数据库在第一条语句时才真正打开；这里触发它，把失败留在启动阶段。
    await db.customSelect('SELECT 1').get();
    return BootstrapSuccess(database: db, secrets: secrets);
  } on Object catch (e) {
    log.error('boot', '数据库打开失败：${e.runtimeType}');
    try {
      await db?.close();
    } on Object {
      // 关闭失败不影响向用户报告打开失败。
    }
    return const BootstrapFailure(BootstrapFailureKind.databaseOpenFailed);
  }
}

String _newKeyHex(Random random) {
  final buffer = StringBuffer();
  for (var i = 0; i < 32; i++) {
    buffer.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}
