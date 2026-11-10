/// 地址格式与派生方式相同的一组链。
enum ChainFamily {
  /// Ethereum 及兼容链：同一个地址在所有 EVM 链上通用。
  evm,
  bitcoin,
  solana,
  tron,
}
