import 'package:blockchain_utils/blockchain_utils.dart' hide Err, Ok, Result;
import 'package:ow_domain/ow_domain.dart';

/// 从助记词派生各链地址。只产生地址，不提供任何签名能力。
///
/// 密钥材料的生命周期管理（独立 isolate、用后清零）在 M4 接入保险库时
/// 由调用方负责；这里的方法都是无状态的纯计算。
abstract final class AddressDeriver {
  /// 校验 BIP39 助记词：词表、词数与校验和。
  static bool isValidMnemonic(String mnemonic) =>
      Bip39MnemonicValidator().isValid(_normalize(mnemonic));

  /// BIP39：助记词加可选 passphrase 得到 64 字节种子。
  ///
  /// 助记词无效时返回 [ValidationFailure]。
  static Result<List<int>> seedFromMnemonic(
    String mnemonic, {
    String passphrase = '',
  }) {
    final normalized = _normalize(mnemonic);
    if (!Bip39MnemonicValidator().isValid(normalized)) {
      return const Err(ValidationFailure('mnemonic'));
    }
    return Ok(
      Bip39SeedGenerator(Mnemonic.fromString(normalized)).generate(passphrase),
    );
  }

  /// 按 [scheme] 派生第 [index] 个地址。
  static String deriveAddress({
    required List<int> seed,
    required DerivationScheme scheme,
    required int index,
  }) {
    final path = scheme.pathFor(index);
    if (scheme.family == ChainFamily.solana) {
      // SLIP-0010 ed25519。公钥带 1 字节前缀，地址编码器会处理。
      final key = Bip32Slip10Ed25519.fromSeed(seed).derivePath(path);
      return SolAddrEncoder().encodeKey(key.publicKey.compressed);
    }
    final key = Bip32Slip10Secp256k1.fromSeed(seed).derivePath(path);
    final pub = key.publicKey.compressed;
    return switch (scheme) {
      DerivationScheme.evmStandard ||
      DerivationScheme.evmLedgerLive => EthAddrEncoder().encodeKey(pub),
      DerivationScheme.tronStandard => TrxAddrEncoder().encodeKey(pub),
      DerivationScheme.btcNativeSegwit => P2WPKHAddrEncoder().encodeKey(
        pub,
        hrp: _btcHrp,
      ),
      DerivationScheme.btcTaproot => P2TRAddrEncoder().encodeKey(
        pub,
        hrp: _btcHrp,
      ),
      DerivationScheme.btcNestedSegwit => P2SHAddrEncoder().encodeKey(
        pub,
        netVersion: _btcP2shVersion,
      ),
      DerivationScheme.btcLegacy => P2PKHAddrEncoder().encodeKey(
        pub,
        netVersion: _btcP2pkhVersion,
      ),
      DerivationScheme.solanaStandard ||
      DerivationScheme.solanaLegacy => throw StateError('unreachable'),
    };
  }

  static const _btcHrp = 'bc';
  static const _btcP2pkhVersion = <int>[0x00];
  static const _btcP2shVersion = <int>[0x05];

  static String _normalize(String mnemonic) =>
      mnemonic.trim().toLowerCase().split(RegExp(r'\s+')).join(' ');
}
