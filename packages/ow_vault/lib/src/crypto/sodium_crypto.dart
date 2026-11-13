import 'dart:typed_data';

import 'package:ow_domain/ow_domain.dart';
import 'package:sodium/sodium_sumo.dart';

import 'vault_crypto.dart';

/// [VaultCrypto] 基于 libsodium 的实现（`sodium` 包，见 ADR_005）。
///
/// 只调用 libsodium 的高层接口：`randombytes_buf`、`crypto_pwhash`（Argon2id13）、
/// `crypto_aead_xchacha20poly1305_ietf_*`、`crypto_kdf_derive_from_key`、
/// `crypto_generichash`。`crypto_pwhash` 在 libsodium 中属于 "sumo" 接口，
/// 原生平台上两者是同一个库，所以用 [SodiumSumo]。
///
/// 密钥材料的生命周期：每次调用把传入的密钥复制进 libsodium 的安全内存
/// （[SecureKey]，`sodium_malloc` 分配、加锁、禁止换出），调用结束即
/// [SecureKey.dispose]（`sodium_free` 会先清零）。返回给调用方的 `Uint8List`
/// 位于 Dart 堆上，由调用方清零。
final class SodiumVaultCrypto implements VaultCrypto {
  SodiumVaultCrypto._(this._sodium);

  /// 加载并初始化 libsodium（原生库由 `sodium` 包的构建钩子编译并随应用打包）。
  ///
  /// 加载失败时抛出异常（属于构建或部署问题）。
  static Future<SodiumVaultCrypto> load() async =>
      SodiumVaultCrypto._(await SodiumSumoInit.init());

  final SodiumSumo _sodium;

  static const _keyBytes = 32;
  static const _nonceBytes = 24;
  static const _tagBytes = 16;
  static const _saltBytes = 16;
  static const _kdfOutputBytes = 32;

  /// libsodium 的版本号，用于诊断。
  String get libraryVersion => _sodium.version.toString();

  @override
  Uint8List randomBytes(int length) {
    if (length < 0) throw ArgumentError.value(length, 'length');
    return length == 0 ? Uint8List(0) : _sodium.randombytes.buf(length);
  }

  @override
  Future<Uint8List> argon2id(
    Sensitive password,
    Uint8List salt,
    KdfParams params,
  ) => argon2idWithLength(password, salt, params, _kdfOutputBytes);

  /// 与 [argon2id] 相同，但输出长度可选（16 字节起）。
  ///
  /// 只供测试用 libsodium 官方向量（输出长度各不相同）验证；业务代码用 [argon2id]。
  Future<Uint8List> argon2idWithLength(
    Sensitive password,
    Uint8List salt,
    KdfParams params,
    int outputLength,
  ) async {
    if (salt.length != _saltBytes) {
      throw ArgumentError('salt 必须为 $_saltBytes 字节');
    }
    final passwordKey = password.use((bytes) {
      if (bytes.isEmpty) throw ArgumentError('密码不得为空');
      return _sodium.secureCopy(bytes);
    });
    try {
      final derived = await _pwhashIsolated(
        _sodium,
        passwordKey,
        Uint8List.fromList(salt),
        params.memKib * 1024,
        params.iterations,
        outputLength,
      );
      try {
        return derived.extractBytes();
      } finally {
        derived.dispose();
      }
    } finally {
      passwordKey.dispose();
    }
  }

  /// 在新的 isolate 中执行 `crypto_pwhash`。
  ///
  /// 写成静态函数，保证闭包只捕获可发送的值：sodium 实例、salt 副本与三个整数。
  /// 密码经 `secureKeys` 以原生内存句柄转交（`sodium` 包先复制一份安全内存再
  /// 交出句柄），不经过 Dart 堆；该 isolate 内恢复出的 SecureKey 由
  /// `runIsolated` 在回调结束后释放。返回的 SecureKey 同样以句柄传回。
  static Future<SecureKey> _pwhashIsolated(
    SodiumSumo sodium,
    SecureKey passwordKey,
    Uint8List salt,
    int memLimit,
    int opsLimit,
    int outputLength,
  ) => sodium.runIsolated(
    secureKeys: [passwordKey],
    (secureKeys, _) => secureKeys.single.runUnlockedSync(
      (pw) => sodium.crypto.pwhash.callRaw(
        outLen: outputLength,
        password: pw.buffer.asInt8List(pw.offsetInBytes, pw.length),
        salt: salt,
        opsLimit: opsLimit,
        memLimit: memLimit,
        alg: CryptoPwhashAlgorithm.argon2id13,
      ),
    ),
  );

  @override
  Uint8List aeadEncrypt(
    Uint8List key,
    Uint8List nonce,
    Uint8List plaintext,
    Uint8List aad,
  ) {
    _checkLength(key, _keyBytes, 'key');
    _checkLength(nonce, _nonceBytes, 'nonce');
    return _withKey(
      key,
      (secureKey) => _sodium.crypto.aeadXChaCha20Poly1305IETF.encrypt(
        message: plaintext,
        nonce: nonce,
        key: secureKey,
        additionalData: aad.isEmpty ? null : aad,
      ),
    );
  }

  @override
  Result<Uint8List> aeadDecrypt(
    Uint8List key,
    Uint8List nonce,
    Uint8List ciphertext,
    Uint8List aad,
  ) {
    _checkLength(key, _keyBytes, 'key');
    if (nonce.length != _nonceBytes || ciphertext.length < _tagBytes) {
      return const Err(VaultCorruptedFailure('aead_malformed'));
    }
    try {
      return Ok(
        _withKey(
          key,
          (secureKey) => _sodium.crypto.aeadXChaCha20Poly1305IETF.decrypt(
            cipherText: ciphertext,
            nonce: nonce,
            key: secureKey,
            additionalData: aad.isEmpty ? null : aad,
          ),
        ),
      );
    } on SodiumException {
      // 认证失败。异常本身不含输入数据，但这里也不向外传递它。
      return const Err(VaultCorruptedFailure('aead_auth_failed'));
    }
  }

  @override
  Uint8List deriveSubkey(Uint8List masterKey, String context8, int subkeyId) =>
      deriveSubkeyWithLength(masterKey, context8, subkeyId, _kdfOutputBytes);

  /// 与 [deriveSubkey] 相同，但输出长度可选（16–64 字节）。
  ///
  /// 只供测试用 libsodium 官方向量验证；业务代码用 [deriveSubkey]。
  Uint8List deriveSubkeyWithLength(
    Uint8List masterKey,
    String context8,
    int subkeyId,
    int outputLength,
  ) {
    _checkLength(masterKey, _keyBytes, 'masterKey');
    if (context8.length != 8 ||
        context8.codeUnits.any((c) => c > 0x7e || c < 0x20)) {
      throw ArgumentError('context8 必须是 8 个可打印 ASCII 字符');
    }
    if (subkeyId < 0) throw ArgumentError.value(subkeyId, 'subkeyId');
    final subkey = _withKey(
      masterKey,
      (secureKey) => _sodium.crypto.kdf.deriveFromKey(
        masterKey: secureKey,
        context: context8,
        subkeyId: BigInt.from(subkeyId),
        subkeyLen: outputLength,
      ),
    );
    try {
      return subkey.extractBytes();
    } finally {
      subkey.dispose();
    }
  }

  @override
  Uint8List keyedHash(Uint8List key, Uint8List message, int outputLength) {
    final hash = _sodium.crypto.genericHash;
    if (key.length < hash.keyBytesMin || key.length > hash.keyBytesMax) {
      throw ArgumentError(
        'key 长度必须在 ${hash.keyBytesMin}–${hash.keyBytesMax} 字节之间',
      );
    }
    if (outputLength < hash.bytesMin || outputLength > hash.bytesMax) {
      throw ArgumentError.value(outputLength, 'outputLength');
    }
    return _withKey(
      key,
      (secureKey) =>
          hash.call(message: message, outLen: outputLength, key: secureKey),
    );
  }

  @override
  bool constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    if (a.isEmpty) return true;
    return _sodium.memcmp(a, b);
  }

  /// 把 [key] 复制进安全内存执行 [action]，结束后立即释放（libsodium 释放前清零）。
  T _withKey<T>(Uint8List key, T Function(SecureKey key) action) {
    final secureKey = _sodium.secureCopy(key);
    try {
      return action(secureKey);
    } finally {
      secureKey.dispose();
    }
  }

  static void _checkLength(Uint8List value, int length, String name) {
    if (value.length != length) {
      // 只报告长度要求，不回显内容。
      throw ArgumentError('$name 必须为 $length 字节');
    }
  }
}
