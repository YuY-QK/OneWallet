import 'chain_family.dart';

/// 地址校验和的验证与 EIP-55 转换。
///
/// 这些计算需要 Keccak-256、SHA-256、Bech32 等算法，`ow_domain` 不引入密码学库，
/// 所以由 `ow_chains` 实现本接口，经构造函数注入 [AddressCodec]。
abstract interface class AddressChecksum {
  /// [address] 的校验和是否正确。
  ///
  /// 只在 [address] 已通过 [family] 的格式判断（已去除首尾空白）之后调用。
  /// EVM：全小写地址视为合法（PRD R4），大小写混合时按 EIP-55 校验；
  /// Bitcoin：`1`、`3` 开头按 Base58Check，`bc1q` 按 Bech32，`bc1p` 按 Bech32m；
  /// Solana：解码后为 32 字节；Tron：Base58Check。
  /// 校验失败返回 false，不抛异常。
  bool verify(String address, ChainFamily family);

  /// 把规范化（全小写）的 EVM 地址转为 EIP-55 大小写混合形式。
  ///
  /// 失败时：[normalizedEvmAddress] 不是合法 EVM 地址格式时抛出 [ArgumentError]。
  String toEip55(String normalizedEvmAddress);
}
