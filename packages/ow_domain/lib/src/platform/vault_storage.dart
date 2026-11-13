import 'dart:typed_data';

/// 保险库文件（`vault.owv`）的字节读写，由平台层提供基于文件的实现。
///
/// 放在领域层而不是 `ow_vault`：它只涉及字节读写，属于平台能力接口；这样
/// `ow_vault` 与 `ow_platform` 都只依赖 `ow_domain`，不必让 `ow_platform` 依赖
/// `ow_vault`（DEV_GUIDELINES 第 2 节不允许）。
///
/// 内容是已加密的保险库文件，本接口不感知其格式。IO 失败以异常抛出，
/// 异常信息不得包含文件内容。
abstract interface class VaultStorage {
  /// 读取完整内容；文件不存在时返回 null。
  Future<Uint8List?> read();

  /// 用 [bytes] 原子地替换文件内容：返回后新内容已落盘；中途失败或进程被杀时，
  /// 下次 [read] 得到的要么是完整的旧内容，要么是完整的新内容，不会是半截。
  ///
  /// 同一实例上的并发调用必须串行执行。实现不得修改 [bytes]。
  Future<void> writeAtomic(Uint8List bytes);

  /// 删除文件以及实现保留的备份与临时文件。文件不存在时什么也不做。
  Future<void> delete();
}
