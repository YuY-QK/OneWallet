import 'dart:convert';
import 'dart:typed_data';

import 'package:ow_domain/ow_domain.dart';
import 'package:ow_vault/ow_vault.dart';
import 'package:ow_vault/src/backup/backup_format.dart';
import 'package:test/test.dart';

import 'vault_fixtures.dart';

// 备份测试的公共数据。全部是公开测试向量或明显的假数据：
// 助记词取自 BIP39 官方测试向量，"TREZOR" 是这些向量统一使用的附加密码；
// 地址是 abandon…about 这组助记词在各链标准路径上的公开派生结果；
// 私钥、交易所凭据是一眼可见的假值。

/// 测试用的备份密码（假）。
const backupPassword = 'fake-backup-password';

/// 文本形式的假 EVM 私钥：`0x` 加 64 个 `2`。
const fakeTextPrivateKey =
    '0x2222222222222222222222222222222222222222222222222222222222222222';

final t0 = DateTime.utc(2026, 11, 13, 8, 30);

/// 账户、地址、四个保险库条目、设置的完整载荷；[withCredentials] 时附带交易所凭据。
BackupPayload samplePayload({bool withCredentials = false}) => BackupPayload(
  exportedAt: t0,
  accounts: [
    Account(
      id: 'acc-main',
      type: AccountType.wallet,
      name: '主钱包',
      colorIndex: 2,
      createdAt: DateTime.utc(2026, 1, 2, 3, 4, 5, 6),
      note: '日常使用 "引号" 与 \\ 反斜杠',
      walletSource: WalletSource.metamask,
      vaultItemId: 'item-abandon',
      backup: BackupStatus(
        offlineBackedUp: true,
        offlineVerifiedAt: DateTime.utc(2026, 6, 1),
      ),
    ),
    Account(
      id: 'acc-cold',
      type: AccountType.wallet,
      name: 'Cold',
      colorIndex: 0,
      createdAt: DateTime.utc(2026, 2, 1),
      walletSource: WalletSource.okxWeb3,
      vaultItemId: 'item-key-hex',
      backup: const BackupStatus(keyless: true),
    ),
    Account(
      id: 'acc-binance',
      type: AccountType.exchange,
      name: 'Binance',
      colorIndex: 7,
      createdAt: DateTime.utc(2026, 3, 1),
      exchange: ExchangeId.binance,
    ),
  ],
  addresses: [
    WatchAddress(
      id: 'addr-eth',
      accountId: 'acc-main',
      family: ChainFamily.evm,
      address: '0x9858effd232b4033e47d90003d41ec34ecaeda94',
      enabledChainIds: {'ethereum', 'base', 'arbitrum'},
      scheme: DerivationScheme.evmStandard,
      derivationIndex: 0,
    ),
    WatchAddress(
      id: 'addr-btc',
      accountId: 'acc-main',
      family: ChainFamily.bitcoin,
      address: 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
      enabledChainIds: {'bitcoin'},
      scheme: DerivationScheme.btcNativeSegwit,
      derivationIndex: 0,
      note: '找零',
    ),
    WatchAddress(
      id: 'addr-manual',
      accountId: 'acc-cold',
      family: ChainFamily.evm,
      address: '0x000000000000000000000000000000000000dead',
      enabledChainIds: {'bsc'},
    ),
  ],
  vaultItems: [
    BackupVaultItem(
      id: 'item-abandon',
      name: '测试助记词（带附加密码）',
      createdAt: DateTime.utc(2026, 1, 2),
      secret: mnemonicSecret(abandon, passphrase: 'TREZOR'),
    ),
    BackupVaultItem(
      id: 'item-legal',
      name: 'legal',
      createdAt: DateTime.utc(2026, 1, 3),
      secret: mnemonicSecret(legal),
    ),
    BackupVaultItem(
      id: 'item-key-hex',
      name: '二进制私钥',
      createdAt: DateTime.utc(2026, 1, 4),
      secret: privateKeySecret(),
    ),
    BackupVaultItem(
      id: 'item-key-text',
      name: '文本私钥',
      createdAt: DateTime.utc(2026, 1, 5),
      secret: PrivateKeySecret(
        family: ChainFamily.evm,
        key: sensitive(fakeTextPrivateKey),
      ),
    ),
  ],
  settings: const BackupSettings(
    quote: Quote.cny,
    hideSmall: false,
    theme: ThemePreference.dark,
    autoLock: AutoLock.after5Min,
  ),
  exchangeCredentials: withCredentials
      ? [
          BackupExchangeCredential(
            accountId: 'acc-binance',
            credentials: ExchangeCredentials(
              apiKey: sensitive('test-api-key'),
              apiSecret: sensitive('test-api-secret'),
              passphrase: sensitive('test-passphrase'),
            ),
          ),
        ]
      : null,
);

Uint8List bytesOf(Sensitive s) => s.use(Uint8List.fromList);

/// 逐字段断言两份载荷相等（密钥内容按字节比较）。
void expectSamePayload(BackupPayload actual, BackupPayload expected) {
  expect(actual.exportedAt, expected.exportedAt);
  expect(actual.accounts, expected.accounts);
  expect(actual.addresses, expected.addresses);
  expect(actual.settings, expected.settings);
  expect(actual.vaultItems.length, expected.vaultItems.length);
  for (var i = 0; i < expected.vaultItems.length; i++) {
    final a = actual.vaultItems[i];
    final e = expected.vaultItems[i];
    expect(
      (a.id, a.name, a.createdAt, a.kind),
      (e.id, e.name, e.createdAt, e.kind),
    );
    switch ((a.secret, e.secret)) {
      case (final MnemonicSecret x, final MnemonicSecret y):
        expect(bytesOf(x.mnemonic), bytesOf(y.mnemonic));
        expect(
          x.passphrase == null ? null : bytesOf(x.passphrase!),
          y.passphrase == null ? null : bytesOf(y.passphrase!),
        );
      case (final PrivateKeySecret x, final PrivateKeySecret y):
        expect(x.family, y.family);
        expect(bytesOf(x.key), bytesOf(y.key));
      default:
        fail('条目 ${e.id} 的类型不同');
    }
  }
  final ac = actual.exchangeCredentials;
  final ec = expected.exchangeCredentials;
  expect(ac?.length, ec?.length);
  for (var i = 0; i < (ec?.length ?? 0); i++) {
    final x = ac![i];
    final y = ec![i];
    expect(x.accountId, y.accountId);
    expect(bytesOf(x.credentials.apiKey), bytesOf(y.credentials.apiKey));
    expect(bytesOf(x.credentials.apiSecret), bytesOf(y.credentials.apiSecret));
    final xp = x.credentials.passphrase;
    final yp = y.credentials.passphrase;
    expect(xp == null ? null : bytesOf(xp), yp == null ? null : bytesOf(yp));
  }
}

/// 包装真实的 [VaultCrypto]：统计 Argon2id 调用次数；可以预置 [randomBytes] 的
/// 返回值（按顺序取用），用于生成字节固定的样本文件。
final class RecordingCrypto implements VaultCrypto {
  RecordingCrypto(this._inner, {List<Uint8List>? fixedRandom})
    : _fixed = [...?fixedRandom];

  final VaultCrypto _inner;
  final List<Uint8List> _fixed;
  int argon2idCalls = 0;

  @override
  Uint8List randomBytes(int length) {
    if (_fixed.isEmpty) return _inner.randomBytes(length);
    final next = _fixed.removeAt(0);
    if (next.length != length) throw StateError('预置随机数长度不符');
    return Uint8List.fromList(next);
  }

  @override
  Future<Uint8List> argon2id(Sensitive p, Uint8List salt, KdfParams params) {
    argon2idCalls++;
    return _inner.argon2id(p, salt, params);
  }

  @override
  Uint8List aeadEncrypt(Uint8List k, Uint8List n, Uint8List m, Uint8List a) =>
      _inner.aeadEncrypt(k, n, m, a);

  @override
  Result<Uint8List> aeadDecrypt(
    Uint8List k,
    Uint8List n,
    Uint8List c,
    Uint8List a,
  ) => _inner.aeadDecrypt(k, n, c, a);

  @override
  Uint8List deriveSubkey(Uint8List k, String c, int id) =>
      _inner.deriveSubkey(k, c, id);

  @override
  Uint8List keyedHash(Uint8List k, Uint8List m, int n) =>
      _inner.keyedHash(k, m, n);

  @override
  bool constantTimeEquals(Uint8List a, Uint8List b) =>
      _inner.constantTimeEquals(a, b);
}

/// 用任意的载荷明文 [plaintext] 构造备份文件（绕过 `PayloadWriter`），用于测试
/// 载荷解析：未知字段、未知枚举、缺失字段、高版本等。
Future<Uint8List> sealRaw(
  VaultCrypto crypto,
  List<int> plaintext, {
  String password = backupPassword,
  KdfParams? params,
}) async {
  final p = params ?? fastParams;
  final salt = crypto.randomBytes(16);
  final nonce = crypto.randomBytes(24);
  final prefix = encodeBackupPrefix(
    salt: salt,
    nonce: nonce,
    params: p,
    createdAt: t0,
    appVersion: 'test',
  );
  final key = await crypto.argon2id(sensitive(password), salt, p);
  final ct = crypto.aeadEncrypt(
    key,
    nonce,
    Uint8List.fromList(plaintext),
    prefix,
  );
  return Uint8List.fromList([...prefix, ...ct]);
}

/// 把 JSON 对象编码后封装成备份文件。
Future<Uint8List> sealJson(VaultCrypto crypto, Map<String, Object?> json) =>
    sealRaw(crypto, utf8.encode(jsonEncode(json)));

/// 最小的合法载荷 JSON（可修改的副本）。
Map<String, Object?> minimalPayloadJson() => {
  'format': 'onewallet-backup',
  'payload_version': 1,
  'exported_at': '2026-11-13T08:30:00.000Z',
  'accounts': <Object?>[],
  'addresses': <Object?>[],
  'vault_items': <Object?>[],
  'settings': {
    'quote': 'usd',
    'hide_small': true,
    'theme': 'system',
    'auto_lock': 'immediately',
  },
};
