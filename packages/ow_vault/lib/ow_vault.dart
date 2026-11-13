/// OneWallet 保险库核心：加解密、地址派生、备份格式。
///
/// 本包禁止任何网络依赖，也不导入 `dart:io`（由 tools/ci/check_deps.dart 检查）。
library;

export 'src/crypto/sodium_crypto.dart' show SodiumVaultCrypto;
export 'src/crypto/vault_crypto.dart';
export 'src/derivation/address_deriver.dart';
export 'src/vault/vault.dart';
export 'src/vault/vault_item_secret.dart';
export 'src/vault/vault_session.dart' show VaultSession;
