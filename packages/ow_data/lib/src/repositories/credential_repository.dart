import 'package:ow_domain/ow_domain.dart';

/// 基于 [SecretStore] 的 [CredentialRepository] 实现。
///
/// 键名约定（见 IMPLEMENTATION_SPEC 7.5 与 docs/HANDOFF.md M2-10）：
/// - API Key：`ow.exchange.<accountId>.key`
/// - API Secret：`ow.exchange.<accountId>.secret`
/// - Passphrase：`ow.exchange.<accountId>.passphrase`
///
/// 凭据不落入数据库，也不出现在任何日志与异常中。
final class SecretStoreCredentialRepository implements CredentialRepository {
  SecretStoreCredentialRepository(this._store);

  final SecretStore _store;

  static void _checkAccountId(String accountId) {
    if (accountId.isEmpty) {
      throw ArgumentError.value(accountId, 'accountId', '不能为空');
    }
  }

  /// [accountId] 对应的 API Key 存储键。
  static String keyStoreKey(String accountId) {
    _checkAccountId(accountId);
    return 'ow.exchange.$accountId.key';
  }

  /// [accountId] 对应的 API Secret 存储键。
  static String secretStoreKey(String accountId) {
    _checkAccountId(accountId);
    return 'ow.exchange.$accountId.secret';
  }

  /// [accountId] 对应的 Passphrase 存储键。
  static String passphraseStoreKey(String accountId) {
    _checkAccountId(accountId);
    return 'ow.exchange.$accountId.passphrase';
  }

  @override
  Future<void> save(String accountId, ExchangeCredentials c) async {
    _checkAccountId(accountId);
    await c.apiKey.useString(
      (key) => _store.write(keyStoreKey(accountId), key),
    );
    await c.apiSecret.useString(
      (secret) => _store.write(secretStoreKey(accountId), secret),
    );
    final pass = c.passphrase;
    if (pass != null) {
      await pass.useString((p) async {
        if (p.isNotEmpty) {
          await _store.write(passphraseStoreKey(accountId), p);
        } else {
          await _store.delete(passphraseStoreKey(accountId));
        }
      });
    } else {
      await _store.delete(passphraseStoreKey(accountId));
    }
  }

  @override
  Future<ExchangeCredentials?> load(String accountId) async {
    _checkAccountId(accountId);
    final key = await _store.read(keyStoreKey(accountId));
    final secret = await _store.read(secretStoreKey(accountId));
    if (key == null || key.isEmpty || secret == null || secret.isEmpty) {
      return null;
    }
    final pass = await _store.read(passphraseStoreKey(accountId));
    return ExchangeCredentials(
      apiKey: Sensitive.fromString(key),
      apiSecret: Sensitive.fromString(secret),
      passphrase: (pass == null || pass.isEmpty)
          ? null
          : Sensitive.fromString(pass),
    );
  }

  @override
  Future<void> delete(String accountId) async {
    _checkAccountId(accountId);
    await _store.delete(keyStoreKey(accountId));
    await _store.delete(secretStoreKey(accountId));
    await _store.delete(passphraseStoreKey(accountId));
  }

  @override
  String toString() => 'SecretStoreCredentialRepository';
}
