import 'dart:convert';
import 'dart:typed_data';

import 'package:blockchain_utils/blockchain_utils.dart' hide Err, Ok, Result;
import 'package:ow_domain/ow_domain.dart';

/// 私钥文本的校验、规范化与地址派生（规格 3.5 节）。
///
/// 私钥保存导入时的文本形式（UTF-8 字节），派生地址时再从文本解码。
/// 失败时返回 [ValidationFailure]，detail 不得包含任何私钥内容。
abstract final class PrivateKeyFormat {
  /// 校验并规范化用户输入的私钥文本。
  ///
  /// 成功返回规范化后的 UTF-8 字节（新的 [Sensitive]，归调用方负责 wipe）。
  static Result<Sensitive> normalize(ChainFamily family, Sensitive raw) {
    final text = raw.use((bytes) {
      try {
        return utf8.decode(bytes).trim();
      } catch (_) {
        return null;
      }
    });

    if (text == null || text.isEmpty) {
      return const Err(ValidationFailure('private_key_invalid'));
    }

    return switch (family) {
      ChainFamily.evm || ChainFamily.tron => _normalizeSecp256k1Hex(text),
      ChainFamily.bitcoin => _normalizeBitcoinWif(text),
      ChainFamily.solana => _normalizeSolanaBase58(text),
    };
  }

  /// 由已规范化的私钥文本派生该链的地址（EVM 返回 EIP-55 形式）。
  static String addressOf(
    ChainFamily family,
    Sensitive normalized, {
    DerivationScheme? bitcoinScheme,
  }) {
    final text = normalized.use((bytes) => utf8.decode(bytes).trim());
    return switch (family) {
      ChainFamily.evm => _addressOfEvm(text),
      ChainFamily.tron => _addressOfTron(text),
      ChainFamily.bitcoin => _addressOfBitcoin(
        text,
        scheme: bitcoinScheme ?? DerivationScheme.btcNativeSegwit,
      ),
      ChainFamily.solana => _addressOfSolana(text),
    };
  }

  // --- EVM & Tron ---

  static Result<Sensitive> _normalizeSecp256k1Hex(String input) {
    var hexStr = input;
    if (hexStr.startsWith('0x') || hexStr.startsWith('0X')) {
      hexStr = hexStr.substring(2);
    }
    if (hexStr.length != 64 || !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(hexStr)) {
      return const Err(ValidationFailure('private_key_invalid'));
    }
    final lower = hexStr.toLowerCase();
    try {
      final bytes = BytesUtils.fromHexString(lower);
      if (!Secp256k1PrivateKey.isValidBytes(bytes)) {
        return const Err(ValidationFailure('private_key_invalid'));
      }
      return Ok(Sensitive(Uint8List.fromList(utf8.encode(lower))));
    } catch (_) {
      return const Err(ValidationFailure('private_key_invalid'));
    }
  }

  static String _addressOfEvm(String hexStr) {
    final bytes = BytesUtils.fromHexString(hexStr);
    final key = Secp256k1PrivateKey.fromBytes(bytes);
    return EthAddrEncoder().encodeKey(key.publicKey.compressed);
  }

  static String _addressOfTron(String hexStr) {
    final bytes = BytesUtils.fromHexString(hexStr);
    final key = Secp256k1PrivateKey.fromBytes(bytes);
    return TrxAddrEncoder().encodeKey(key.publicKey.compressed);
  }

  // --- Bitcoin ---

  static Result<Sensitive> _normalizeBitcoinWif(String input) {
    try {
      WifDecoder.decode(input, netVer: const [0x80]);
      return Ok(Sensitive(Uint8List.fromList(utf8.encode(input))));
    } catch (_) {
      return const Err(ValidationFailure('private_key_invalid'));
    }
  }

  static String _addressOfBitcoin(
    String wif, {
    required DerivationScheme scheme,
  }) {
    if (scheme.family != ChainFamily.bitcoin) {
      throw ArgumentError('Scheme must be for Bitcoin: $scheme');
    }
    final (privBytes, mode) = WifDecoder.decode(wif, netVer: const [0x80]);
    if (mode == PubKeyModes.uncompressed &&
        scheme != DerivationScheme.btcLegacy) {
      throw ArgumentError('非压缩 WIF 只允许传统地址 (btcLegacy)');
    }
    final key = Secp256k1PrivateKey.fromBytes(privBytes);
    final pub = mode == PubKeyModes.compressed
        ? key.publicKey.compressed
        : key.publicKey.uncompressed;

    return switch (scheme) {
      DerivationScheme.btcNativeSegwit => P2WPKHAddrEncoder().encodeKey(
        pub,
        hrp: 'bc',
      ),
      DerivationScheme.btcTaproot => P2TRAddrEncoder().encodeKey(
        pub,
        hrp: 'bc',
      ),
      DerivationScheme.btcNestedSegwit => P2SHAddrEncoder().encodeKey(
        pub,
        netVersion: const [0x05],
      ),
      DerivationScheme.btcLegacy => P2PKHAddrEncoder().encodeKey(
        pub,
        netVersion: const [0x00],
      ),
      _ => throw ArgumentError('Unsupported Bitcoin scheme: $scheme'),
    };
  }

  // --- Solana ---

  static Result<Sensitive> _normalizeSolanaBase58(String input) {
    try {
      final decoded = Base58Decoder.decode(input);
      if (decoded.length == 32) {
        if (!Ed25519PrivateKey.isValidBytes(decoded)) {
          return const Err(ValidationFailure('private_key_invalid'));
        }
      } else if (decoded.length == 64) {
        final seed = decoded.sublist(0, 32);
        final pubBytes = decoded.sublist(32, 64);
        if (!Ed25519PrivateKey.isValidBytes(seed)) {
          return const Err(ValidationFailure('private_key_invalid'));
        }
        final key = Ed25519PrivateKey.fromBytes(seed);
        if (!BytesUtils.bytesEqual(key.publicKey.point.toBytes(), pubBytes)) {
          return const Err(ValidationFailure('private_key_invalid'));
        }
      } else {
        return const Err(ValidationFailure('private_key_invalid'));
      }
      return Ok(Sensitive(Uint8List.fromList(utf8.encode(input))));
    } catch (_) {
      return const Err(ValidationFailure('private_key_invalid'));
    }
  }

  static String _addressOfSolana(String base58Key) {
    final decoded = Base58Decoder.decode(base58Key);
    final seed = decoded.length == 64 ? decoded.sublist(0, 32) : decoded;
    final key = Ed25519PrivateKey.fromBytes(seed);
    return SolAddrEncoder().encodeKey(key.publicKey.point.toBytes());
  }
}
