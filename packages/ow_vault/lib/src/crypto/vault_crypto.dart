import 'dart:typed_data';

import 'package:ow_domain/ow_domain.dart';

/// Argon2id 的参数（SECURITY_DESIGN 第 4 节）。
///
/// libsodium 的 `crypto_pwhash` 并行度固定为 1，所以 [parallelism] 只接受 1
/// （见 ADR_005）。字段保留是为了与保险库文件头 `kdf.parallelism` 一一对应。
final class KdfParams {
  /// [memKib] 为内存用量（KiB），[iterations] 为迭代次数（libsodium 的 opslimit）。
  ///
  /// 取值不在 [minMemKib]–[maxMemKib]、[minIterations]–[maxIterations] 之内，
  /// 或 [parallelism] 不为 1 时抛出 [ArgumentError]（属于程序缺陷）。
  KdfParams({
    required this.memKib,
    required this.iterations,
    this.parallelism = 1,
  }) {
    if (!isValid(
      memKib: memKib,
      iterations: iterations,
      parallelism: parallelism,
    )) {
      throw ArgumentError('Argon2id 参数超出允许范围');
    }
  }

  /// 保险库的默认参数：内存 64 MiB、迭代 3、并行 1。
  ///
  /// 这是 SECURITY_DESIGN 第 11 节 S1 记载的"真机定标之前"的默认值，
  /// M0-12 定标后在此回填。
  static final vaultDefault = KdfParams(memKib: 65536, iterations: 3);

  /// 加密备份文件的默认参数：内存 256 MiB、迭代 3、并行 1（SECURITY_DESIGN 第 4 节）。
  ///
  /// 备份文件可能被拷走后离线暴力破解，且解密只在导出、恢复时各做一次，所以比
  /// 保险库更强。手机内存不足时应用层可以降级，但不低于 [vaultDefault]；实际参数
  /// 写在文件头部，解密时按头部取值。M0-12 真机定标后在此回填。
  static final backupDefault = KdfParams(memKib: 262144, iterations: 3);

  /// libsodium Argon2id 的内存下限（`crypto_pwhash_MEMLIMIT_MIN` 为 8192 字节）。
  static const minMemKib = 8;

  /// 本应用接受的内存上限：1 GiB。
  ///
  /// 文件头中的参数不受认证保护，被改大后可能让解锁耗尽内存；
  /// 解析文件时超过此值视为损坏。
  static const maxMemKib = 1024 * 1024;

  /// 迭代次数下限（libsodium Argon2id 的 `OPSLIMIT_MIN`）。
  static const minIterations = 1;

  /// 本应用接受的迭代次数上限，理由同 [maxMemKib]。
  static const maxIterations = 32;

  /// 内存用量，单位 KiB。
  final int memKib;

  /// 迭代次数。
  final int iterations;

  /// 并行度，只能为 1。
  final int parallelism;

  /// 三个参数是否都在允许范围内。解析文件头时用它判断而不抛异常。
  static bool isValid({
    required int memKib,
    required int iterations,
    required int parallelism,
  }) =>
      memKib >= minMemKib &&
      memKib <= maxMemKib &&
      iterations >= minIterations &&
      iterations <= maxIterations &&
      parallelism == 1;

  @override
  bool operator ==(Object other) =>
      other is KdfParams &&
      other.memKib == memKib &&
      other.iterations == iterations &&
      other.parallelism == parallelism;

  @override
  int get hashCode => Object.hash(memKib, iterations, parallelism);

  @override
  String toString() =>
      'KdfParams(memKib: $memKib, iterations: $iterations, '
      'parallelism: $parallelism)';
}

/// 保险库使用的密码学原语。唯一实现是 [SodiumVaultCrypto]（libsodium）。
///
/// 约定：
/// - 参数中的密钥（`Uint8List`）由调用方持有并负责用完清零；实现只在调用期间
///   把它复制进 libsodium 的安全内存，返回前释放（libsodium 释放时会清零）。
/// - 返回的密钥材料（[argon2id]、[deriveSubkey] 的结果）归调用方所有，
///   用完须覆写清零。
/// - 长度不符合要求的密钥、nonce 等属于程序缺陷，抛出 [ArgumentError]；
///   来自文件的、可能被篡改的数据（[aeadDecrypt] 的密文与 nonce）以 `Err` 返回。
/// - 任何异常与 `Failure.detail` 都不含密钥、密码或明文。
abstract interface class VaultCrypto {
  /// 返回 [length] 字节的安全随机数（libsodium `randombytes_buf`）。
  Uint8List randomBytes(int length);

  /// Argon2id（`crypto_pwhash`，算法 Argon2id13），输出 32 字节。
  ///
  /// [salt] 必须为 16 字节，[password] 不得为空，否则抛出 [ArgumentError]。
  /// 在独立的 isolate 中计算，不阻塞调用方的 isolate；[password] 以
  /// libsodium 安全内存的形式转交给该 isolate。[password] 不被清除，
  /// 仍由调用方负责。内存不足等库内部失败以异常抛出（信息不含密码）。
  Future<Uint8List> argon2id(
    Sensitive password,
    Uint8List salt,
    KdfParams params,
  );

  /// XChaCha20-Poly1305-IETF 加密。[key] 32 字节，[nonce] 24 字节。
  ///
  /// 返回 `密文 ‖ 16 字节认证标签`。[aad] 是关联数据，解密时必须原样提供。
  Uint8List aeadEncrypt(
    Uint8List key,
    Uint8List nonce,
    Uint8List plaintext,
    Uint8List aad,
  );

  /// XChaCha20-Poly1305-IETF 解密并验证。
  ///
  /// 认证失败（密钥不对，或密文、nonce、关联数据任一字节被改）以及 nonce、
  /// 密文长度不对时返回 `Err(VaultCorruptedFailure)`；调用方按上下文改写
  /// （例如密码包裹解不开应报告为 `WrongPasswordFailure`）。
  /// 成功时返回的明文归调用方所有，用完须清零。[key] 不是 32 字节时抛出
  /// [ArgumentError]。
  Result<Uint8List> aeadDecrypt(
    Uint8List key,
    Uint8List nonce,
    Uint8List ciphertext,
    Uint8List aad,
  );

  /// 用 `crypto_kdf_derive_from_key` 从 32 字节的 [masterKey] 派生 32 字节子密钥。
  ///
  /// [context8] 必须恰好是 8 个 ASCII 字节，[subkeyId] 不得为负，否则抛出
  /// [ArgumentError]。
  Uint8List deriveSubkey(Uint8List masterKey, String context8, int subkeyId);

  /// 带密钥的 BLAKE2b（`crypto_generichash`）。
  ///
  /// [key] 16–64 字节，[outputLength] 16–64，否则抛出 [ArgumentError]。
  Uint8List keyedHash(Uint8List key, Uint8List message, int outputLength);

  /// 常量时间比较（libsodium `sodium_memcmp`）：耗时只取决于长度，不取决于内容。
  ///
  /// 长度不同时直接返回 false（长度不是秘密）。用于比较校验值等密钥材料。
  bool constantTimeEquals(Uint8List a, Uint8List b);
}
