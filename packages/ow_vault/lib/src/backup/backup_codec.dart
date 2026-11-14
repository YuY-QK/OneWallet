import 'dart:typed_data';

import 'package:ow_domain/ow_domain.dart';

import '../crypto/vault_crypto.dart';
import '../vault/vault_format.dart' show nonceLength, saltLength;
import 'backup_format.dart';
import 'backup_payload.dart';
import 'payload_reader.dart';
import 'payload_writer.dart';

/// 加密备份文件 `.owbak` 的编解码（SECURITY_DESIGN 5.2；格式的权威说明是
/// `tools/backup_decrypt/FORMAT.md`）。
///
/// ```text
/// 文件 = "OWBK" ‖ 版本(1 字节，=1) ‖ L(4 字节大端) ‖ 头部 JSON(L 字节) ‖ 密文
/// K    = Argon2id(备份密码的 UTF-8 字节, kdf.salt, kdf.mem_kib, kdf.iters)，32 字节
/// 密文 = XChaCha20-Poly1305-IETF(K, nonce, 载荷 JSON, AAD = 文件前 9 + L 字节)
/// ```
///
/// 文件自成一体：只凭备份密码即可解密，不依赖任何设备、硬件密钥或保险库主密钥。
/// 不压缩载荷（压缩后的长度会泄露内容特征，且载荷很小）。
///
/// 密码学原语只经 [VaultCrypto]；本类不读时钟、不取随机数之外的任何外部状态。
abstract final class BackupCodec {
  /// 把 [payload] 加密为备份文件的完整字节。
  ///
  /// - [password]：备份密码，按字节原样使用（不做 Unicode 规范化）；不被清除，仍归调用方。
  /// - [params]：Argon2id 参数，写入头部。默认用 `KdfParams.backupDefault`；
  ///   内存不足时应用层可以降级（不低于保险库默认值），解码对任意合法参数都工作。
  /// - [createdAt]、[appVersion]：写入头部，明文可见（`peekHeader` 可读）。
  ///
  /// 依次取 16 字节 salt、24 字节 nonce（均来自 [VaultCrypto.randomBytes]）。
  /// 派生出的密钥与载荷明文的缓冲在返回前清零；[payload] 不被清除，仍归调用方。
  ///
  /// 失败：[password] 为空、载荷中的保险库条目不合法（见 `PayloadWriter`）、
  /// [appVersion] 过长使头部超过 4096 字节时抛出 [ArgumentError]（属于程序缺陷，
  /// 界面应先校验）；Argon2id 内存不足等库内部失败以异常抛出。异常信息不含内容。
  static Future<Uint8List> encode({
    required BackupPayload payload,
    required Sensitive password,
    required VaultCrypto crypto,
    required KdfParams params,
    required DateTime createdAt,
    required String appVersion,
  }) async {
    if (password.use((b) => b.isEmpty)) {
      throw ArgumentError('备份密码不能为空');
    }
    PayloadWriter.check(payload);
    final salt = crypto.randomBytes(saltLength);
    final nonce = crypto.randomBytes(nonceLength);
    final prefix = encodeBackupPrefix(
      salt: salt,
      nonce: nonce,
      params: params,
      createdAt: createdAt,
      appVersion: appVersion,
    );
    final key = await crypto.argon2id(password, salt, params);
    try {
      final plaintext = PayloadWriter.encode(payload);
      try {
        final ciphertext = crypto.aeadEncrypt(key, nonce, plaintext, prefix);
        final out = Uint8List(prefix.length + ciphertext.length);
        out.setRange(0, prefix.length, prefix);
        out.setRange(prefix.length, out.length, ciphertext);
        return out;
      } finally {
        plaintext.fillRange(0, plaintext.length, 0);
      }
    } finally {
      key.fillRange(0, key.length, 0);
    }
  }

  /// 用 [password] 解密备份文件 [file]。
  ///
  /// 先检查容器结构（不需要密码、不做密码学运算），再派生密钥、认证解密，最后
  /// 解析载荷。失败时不返回任何部分内容：
  /// - 魔数、长度、头部不合法，KDF 参数超出允许范围 → `BackupCorruptedFailure`
  ///   （此时不执行 Argon2id，防止被改成耗尽内存的参数）；
  /// - 容器版本或载荷版本高于本应用支持的版本 → `BackupVersionUnsupportedFailure`；
  /// - [password] 为空 → `WrongPasswordFailure`（不执行 Argon2id，与保险库一致）；
  /// - 认证解密失败 → `WrongPasswordFailure`。认证加密无法区分"密码错误"与"头部
  ///   或密文的任一字节被改动、文件被截断或追加"，界面文案应为"密码不正确或文件已损坏"；
  /// - 解密成功但载荷不合法 → `BackupCorruptedFailure`。
  ///
  /// 返回的 [BackupPayload] 归调用方，用完必须 `wipe()`。派生密钥与明文缓冲在
  /// 返回前清零；[password] 与 [file] 不被修改。Argon2id 内存不足等库内部失败以
  /// 异常抛出（信息不含密码）。
  static Future<Result<BackupPayload>> decode({
    required Uint8List file,
    required Sensitive password,
    required VaultCrypto crypto,
  }) async {
    final parsed = BackupContainer.parse(file);
    final BackupContainer container;
    switch (parsed) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        container = value;
    }
    if (password.use((b) => b.isEmpty)) {
      return const Err(WrongPasswordFailure());
    }
    final key = await crypto.argon2id(
      password,
      container.salt,
      container.header.kdfParams,
    );
    final Result<Uint8List> opened;
    try {
      opened = crypto.aeadDecrypt(
        key,
        container.nonce,
        container.ciphertext,
        container.aad,
      );
    } finally {
      key.fillRange(0, key.length, 0);
    }
    final plaintext = opened.valueOrNull;
    if (plaintext == null) return const Err(WrongPasswordFailure());
    try {
      return PayloadReader.decode(plaintext);
    } finally {
      plaintext.fillRange(0, plaintext.length, 0);
    }
  }

  /// 读取头部里的非敏感信息（创建时间、应用版本、KDF 参数），不需要密码，
  /// 不做任何密码学运算。供界面在输入密码之前显示。
  ///
  /// 失败与 [decode] 的结构检查相同。头部不受认证保护之前不可信：这里读到的
  /// 内容只供显示，被改动过的头部会在 [decode] 时导致解密失败。
  static Result<BackupHeader> peekHeader(Uint8List file) =>
      BackupContainer.parse(file).map((c) => c.header);
}
