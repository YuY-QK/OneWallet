/// 标准币种：不同链、不同交易所的同一种币归一化后的结果（PRD R8）。
final class Asset {
  const Asset({
    required this.id,
    required this.symbol,
    required this.name,
    this.priceId,
  });

  /// 大写符号，如 `USDT`；符号冲突时加后缀。
  final String id;
  final String symbol;
  final String name;

  /// 价格源中的标识（CoinGecko id），没有价格源时为 null。
  final String? priceId;

  @override
  bool operator ==(Object other) =>
      other is Asset &&
      other.id == id &&
      other.symbol == symbol &&
      other.name == name &&
      other.priceId == priceId;

  @override
  int get hashCode => Object.hash(id, symbol, name, priceId);

  @override
  String toString() => 'Asset($id)';
}
