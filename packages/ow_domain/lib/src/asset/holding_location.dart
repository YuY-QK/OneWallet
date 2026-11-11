/// 交易所账户内的子账户（PRD R7）。
enum ExchangeSubAccount { spot, funding, futures, margin, earn, other }

/// 一笔持仓所在的位置：链上为某条链上的某个地址，交易所为某个子账户。
sealed class HoldingLocation {
  const HoldingLocation();
}

/// 链上位置。
final class OnChainLocation extends HoldingLocation {
  const OnChainLocation({required this.chainId, required this.addressId});

  final String chainId;

  /// [WatchAddress] 的 id，不是地址本身。
  final String addressId;

  @override
  bool operator ==(Object other) =>
      other is OnChainLocation &&
      other.chainId == chainId &&
      other.addressId == addressId;

  @override
  int get hashCode => Object.hash(OnChainLocation, chainId, addressId);

  @override
  String toString() => 'OnChainLocation($chainId, $addressId)';
}

/// 交易所子账户。
final class ExchangeLocation extends HoldingLocation {
  const ExchangeLocation(this.sub);

  final ExchangeSubAccount sub;

  @override
  bool operator ==(Object other) =>
      other is ExchangeLocation && other.sub == sub;

  @override
  int get hashCode => Object.hash(ExchangeLocation, sub);

  @override
  String toString() => 'ExchangeLocation(${sub.name})';
}
