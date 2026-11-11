import 'token_ref.dart';

/// [TokenRef] 的稳定字符串标识，用作"手动隐藏代币"集合的元素（见 `TokenVisibilityRepository`）。
extension TokenKey on TokenRef {
  /// 格式：
  /// - 链上合约代币：`"<chainId>:<合约规范化形式>"`；
  /// - 原生币：`"<chainId>:native"`；
  /// - 交易所币种：`"<exchange 枚举名>:<符号大写>"`。
  ///
  /// 合约地址原样拼接，不做大小写转换（规范化由调用方在构造
  /// [ContractToken] 时完成）；交易所符号转为大写，使 `usdt` 与 `USDT` 同键。
  String get tokenKey => switch (this) {
    NativeToken(:final chainId) => '$chainId:native',
    ContractToken(:final chainId, :final contract) => '$chainId:$contract',
    ExchangeToken(:final exchange, :final symbol) =>
      '${exchange.name}:${symbol.toUpperCase()}',
  };
}
