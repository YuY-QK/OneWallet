import 'dart:typed_data';

import 'package:ow_domain/ow_domain.dart';
import 'package:ow_vault/ow_vault.dart';

import 'fake_repositories.dart';

/// 极小 KDF 参数，供单元测试快速执行（单次 Argon2id < 1ms）。
final testKdfParams = KdfParams(memKib: 8, iterations: 1);

/// 包装真实 [VaultCrypto] 的计数器，用于断言 Argon2id 调用的次数。
final class CountingVaultCrypto implements VaultCrypto {
  CountingVaultCrypto(this.delegate);

  final VaultCrypto delegate;
  int argon2idCalls = 0;

  @override
  Uint8List randomBytes(int length) => delegate.randomBytes(length);

  @override
  Future<Uint8List> argon2id(
    Sensitive password,
    Uint8List salt,
    KdfParams params,
  ) {
    argon2idCalls++;
    return delegate.argon2id(password, salt, params);
  }

  @override
  Uint8List aeadEncrypt(
    Uint8List key,
    Uint8List nonce,
    Uint8List plaintext,
    Uint8List aad,
  ) => delegate.aeadEncrypt(key, nonce, plaintext, aad);

  @override
  Result<Uint8List> aeadDecrypt(
    Uint8List key,
    Uint8List nonce,
    Uint8List ciphertext,
    Uint8List aad,
  ) => delegate.aeadDecrypt(key, nonce, ciphertext, aad);

  @override
  Uint8List deriveSubkey(Uint8List masterKey, String context8, int subkeyId) =>
      delegate.deriveSubkey(masterKey, context8, subkeyId);

  @override
  Uint8List keyedHash(Uint8List key, Uint8List message, int outputLength) =>
      delegate.keyedHash(key, message, outputLength);

  @override
  bool constantTimeEquals(Uint8List a, Uint8List b) =>
      delegate.constantTimeEquals(a, b);
}

/// 内存 [SecretStore] 实现。
final class MemorySecretStore implements SecretStore {
  final map = <String, String>{};

  @override
  Future<void> write(String key, String value) async {
    map[key] = value;
  }

  @override
  Future<String?> read(String key) async => map[key];

  @override
  Future<void> delete(String key) async {
    map.remove(key);
  }
}

/// 假平台能力，可配置硬件密钥等支持情况。
final class FakePlatformCapabilities implements PlatformCapabilities {
  FakePlatformCapabilities({
    this.hardwareKeystore = true,
    this.biometrics = true,
    this.camera = false,
    this.screenProtection = ScreenProtection.none,
  });

  @override
  bool hardwareKeystore;

  @override
  bool biometrics;

  @override
  bool camera;

  @override
  ScreenProtection screenProtection;
}

/// 假硬件密钥存储。
final class FakeHardwareKeyStore implements HardwareKeyStore {
  final wrappedData = <String, Uint8List>{};
  bool failUnwrap = false;
  bool cancelUnwrap = false;
  bool unwrapThrows = false;

  @override
  Future<Result<Uint8List>> wrap(String keyAlias, Uint8List plaintext) async {
    // 模拟加密包装
    final wrapped = Uint8List.fromList([1, 2, 3, ...plaintext]);
    wrappedData[keyAlias] = wrapped;
    return Ok(Uint8List.fromList(wrapped));
  }

  @override
  Future<Result<Uint8List>> unwrap(
    String keyAlias,
    Uint8List wrapped, {
    required String reason,
  }) async {
    if (unwrapThrows) throw Exception('HardwareKeyStore unwrap exception');
    if (cancelUnwrap) {
      return const Err(BiometricUnavailableFailure('user_canceled'));
    }
    if (failUnwrap) return const Err(UnsupportedFailure('生物识别失败'));
    if (wrapped.length < 3 ||
        wrapped[0] != 1 ||
        wrapped[1] != 2 ||
        wrapped[2] != 3) {
      return const Err(ValidationFailure('invalid_wrapped_bytes'));
    }
    // 解包
    final pt = Uint8List.fromList(wrapped.sublist(3));
    return Ok(pt);
  }

  @override
  Future<void> delete(String keyAlias) async {
    wrappedData.remove(keyAlias);
  }
}

/// 内存中的 [VaultStorage]。
final class MemoryVaultStorage implements VaultStorage {
  Uint8List? bytes;
  int writes = 0;
  bool failBeforeStore = false;
  bool failRead = false;

  @override
  Future<Uint8List?> read() async {
    if (failRead) throw Exception('读取失败（测试）');
    final b = bytes;
    return b == null ? null : Uint8List.fromList(b);
  }

  @override
  Future<void> writeAtomic(Uint8List data) async {
    if (failBeforeStore) throw Exception('写入失败（测试）');
    bytes = Uint8List.fromList(data);
    writes++;
  }

  @override
  Future<void> delete() async {
    bytes = null;
  }
}

/// 内存中的 [VaultMetaRepository]。
final class InMemoryVaultMetaRepository implements VaultMetaRepository {
  final store = Watchable<List<VaultItemMeta>>(const []);

  @override
  Stream<List<VaultItemMeta>> watchAll() => store.watch();

  @override
  Future<VaultItemMeta?> byFingerprint(String fingerprint) async {
    for (final m in store.value) {
      if (m.fingerprint == fingerprint) return m;
    }
    return null;
  }

  @override
  Future<void> upsert(VaultItemMeta meta) async {
    store.value = [
      for (final m in store.value)
        if (m.id != meta.id) m,
      meta,
    ];
  }

  @override
  Future<void> delete(String id) async {
    store.value = [
      for (final m in store.value)
        if (m.id != id) m,
    ];
  }
}

/// 内存中的 [CredentialRepository]。
final class InMemoryCredentialRepository implements CredentialRepository {
  final _creds = <String, ExchangeCredentials>{};

  @override
  Future<void> save(String accountId, ExchangeCredentials c) async {
    _creds[accountId] = c;
  }

  @override
  Future<ExchangeCredentials?> load(String accountId) async {
    return _creds[accountId];
  }

  @override
  Future<void> delete(String accountId) async {
    _creds.remove(accountId);
  }
}
