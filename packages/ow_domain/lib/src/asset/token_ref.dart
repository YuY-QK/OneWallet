import '../account/exchange_id.dart';

/// 数据源返回的原始代币标识。值相等，可用作 Map 的键与 Set 的元素。
sealed class TokenRef {
  const TokenRef();
}

/// 某条链的原生币。
final class NativeToken extends TokenRef {
  const NativeToken(this.chainId);

  final String chainId;

  @override
  bool operator ==(Object other) =>
      other is NativeToken && other.chainId == chainId;

  @override
  int get hashCode => Object.hash(NativeToken, chainId);

  @override
  String toString() => 'NativeToken($chainId)';
}

/// 某条链上的合约代币（ERC-20、SPL、TRC-20 等）。
final class ContractToken extends TokenRef {
  /// 调用方负责先把 [contract] 规范化（EVM 合约转小写等，见 `AddressCodec.normalize`）。
  const ContractToken(this.chainId, this.contract);

  final String chainId;

  /// 合约地址的规范化形式。
  ///
  /// 相等比较按传入的字符串逐字符进行，不做大小写或空白处理：
  /// 调用方负责先规范化，否则同一合约的不同写法会被视为不同代币。
  final String contract;

  @override
  bool operator ==(Object other) =>
      other is ContractToken &&
      other.chainId == chainId &&
      other.contract == contract;

  @override
  int get hashCode => Object.hash(ContractToken, chainId, contract);

  @override
  String toString() => 'ContractToken($chainId, $contract)';
}

/// 交易所账户里的币种，按交易所给出的符号标识。
final class ExchangeToken extends TokenRef {
  const ExchangeToken(this.exchange, this.symbol);

  final ExchangeId exchange;

  /// 交易所返回的原始符号。
  final String symbol;

  @override
  bool operator ==(Object other) =>
      other is ExchangeToken &&
      other.exchange == exchange &&
      other.symbol == symbol;

  @override
  int get hashCode => Object.hash(ExchangeToken, exchange, symbol);

  @override
  String toString() => 'ExchangeToken(${exchange.name}, $symbol)';
}
