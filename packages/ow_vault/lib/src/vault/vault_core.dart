import 'dart:typed_data';

import 'package:ow_domain/ow_domain.dart';

import '../crypto/vault_crypto.dart';
import 'async_mutex.dart';
import 'vault_file.dart';

/// `Vault` 与它打开的各个会话共享的内部状态（不导出）。
///
/// 约定：一个保险库文件在进程内只由一个 `Vault` 实例管理。该实例上的全部
/// 写操作（创建、增删条目、改密码）以及解锁时的读取都经 [mutex] 串行执行，
/// 并基于 [current]（最近一次成功读取或写入的文件）构造完整的新文件，
/// 所以同一 `Vault` 打开的多个会话不会互相覆盖对方的修改。
final class VaultCore {
  VaultCore({
    required this.crypto,
    required this.storage,
    required this.defaultParams,
  });

  final VaultCrypto crypto;
  final VaultStorage storage;

  /// 创建与改密码时使用的 Argon2id 参数。
  final KdfParams defaultParams;

  final mutex = AsyncMutex();

  /// 最近一次成功读取或写入的文件内容。
  VaultFile? current;
  Uint8List? _currentBytes;

  /// 文件"身份"的代次。创建新保险库或发现文件被外部替换时加一；
  /// 代次不同的会话立即失效（防止用旧主密钥往新文件里写条目）。
  int epoch = 0;

  /// 读取存储。IO 异常转为 `UnknownFailure`（不带异常文本）。
  Future<Result<Uint8List?>> read() async {
    try {
      return Ok(await storage.read());
    } on Exception {
      return const Err(UnknownFailure('vault_read_failed'));
    }
  }

  /// 采用刚从存储读到并解析成功的文件。与已知内容不同则代次加一。
  void adopt(VaultFile file, Uint8List bytes) {
    final known = _currentBytes;
    if (known != null && !_bytesEqual(known, bytes)) epoch++;
    current = file;
    _currentBytes = bytes;
  }

  /// 把 [next] 整体写入存储（必须在 [mutex] 内调用）。
  ///
  /// 只有写入成功后才更新 [current]，因此失败时内存状态与存储保持一致。
  /// `writeAtomic` 抛出异常时再读一次存储：内容已是新文件（例如落盘后的
  /// 收尾步骤失败）则按成功处理；否则保持原状并返回 `UnknownFailure`。
  Future<Result<void>> commit(VaultFile next) async {
    final bytes = next.encode();
    try {
      await storage.writeAtomic(bytes);
    } on Exception {
      final stored = await read();
      final now = stored.valueOrNull;
      if (now == null || !_bytesEqual(now, bytes)) {
        return const Err(UnknownFailure('vault_write_failed'));
      }
    }
    current = next;
    _currentBytes = bytes;
    return const Ok(null);
  }

  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// 覆写清零。
void wipeBytes(Uint8List bytes) => bytes.fillRange(0, bytes.length, 0);

/// 小写十六进制（只用于非敏感值，如查重指纹）。
String hexOf(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
