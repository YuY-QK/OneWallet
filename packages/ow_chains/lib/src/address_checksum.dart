import 'package:blockchain_utils/blockchain_utils.dart' hide Err, Ok, Result;
import 'package:ow_domain/ow_domain.dart';

/// [AddressChecksum] 的实现：EIP-55、Base58Check、Bech32/Bech32m、Solana 公钥长度。
///
/// 哈希与编码全部来自 `blockchain_utils`，这里不实现任何算法，只组合调用并检查
/// 版本字节、HRP、见证版本等地址层面的规则。只处理公开地址，不接触密钥。
final class ChainAddressChecksum implements AddressChecksum {
  const ChainAddressChecksum();

  /// Bitcoin 主网 P2PKH 版本字节。
  static const _btcP2pkhVersion = 0x00;

  /// Bitcoin 主网 P2SH 版本字节。
  static const _btcP2shVersion = 0x05;

  /// Tron 主网地址版本字节。
  static const _tronVersion = 0x41;

  static const _btcHrp = 'bc';

  /// Base58Check 去掉 4 字节校验后的负载长度：1 字节版本加 20 字节哈希。
  static const _base58PayloadLen = 21;

  static const _solanaKeyLen = 32;

  static final _evmFormat = RegExp(r'^0x[0-9a-fA-F]{40}$');

  @override
  bool verify(String address, ChainFamily family) {
    try {
      return switch (family) {
        ChainFamily.evm => _verifyEvm(address),
        ChainFamily.bitcoin => _verifyBitcoin(address),
        ChainFamily.solana => _verifySolana(address),
        ChainFamily.tron => _verifyTron(address),
      };
    } on Object {
      // 第三方库对畸形输入会抛各种异常（含 RangeError）；按契约一律返回 false。
      return false;
    }
  }

  @override
  String toEip55(String normalizedEvmAddress) {
    if (!_evmFormat.hasMatch(normalizedEvmAddress)) {
      throw ArgumentError.value(
        AddressCodec.shorten(normalizedEvmAddress),
        'normalizedEvmAddress',
        '不是合法的 EVM 地址格式',
      );
    }
    return EthAddrUtils.toChecksumAddress(normalizedEvmAddress.toLowerCase());
  }

  /// 全小写或全大写（除 `0x` 外）视为无校验和；大小写混合必须通过 EIP-55。
  bool _verifyEvm(String address) {
    if (!_evmFormat.hasMatch(address)) return false;
    final body = address.substring(2);
    if (body == body.toLowerCase() || body == body.toUpperCase()) return true;
    return toEip55(address.toLowerCase()) == address;
  }

  bool _verifyBitcoin(String address) {
    final first = address[0];
    if (first == '1' || first == '3') {
      final payload = Base58Decoder.checkDecode(address);
      if (payload.length != _base58PayloadLen) return false;
      return payload[0] == (first == '1' ? _btcP2pkhVersion : _btcP2shVersion);
    }
    return _verifySegwit(address);
  }

  bool _verifySegwit(String address) {
    // BIP173：全小写或全大写合法，混用非法。
    final lower = address.toLowerCase();
    if (address != lower && address != address.toUpperCase()) return false;
    final (version, program) = SegwitBech32Decoder.decode(_btcHrp, lower);
    if (lower.startsWith('bc1q')) {
      // v0 见证程序为 20 字节（P2WPKH）或 32 字节（P2WSH）；库已按 Bech32 校验。
      return version == 0 && (program.length == 20 || program.length == 32);
    }
    if (lower.startsWith('bc1p')) {
      // v1 即 Taproot，32 字节；库已按 Bech32m 校验。
      return version == 1 && program.length == 32;
    }
    return false;
  }

  bool _verifySolana(String address) =>
      Base58Decoder.decode(address).length == _solanaKeyLen;

  bool _verifyTron(String address) {
    final payload = Base58Decoder.checkDecode(address);
    return payload.length == _base58PayloadLen && payload[0] == _tronVersion;
  }
}
