import 'package:decimal/decimal.dart';

/// 计价货币。
enum Quote { usd, cny }

/// 一个标准币种以某种计价货币表示的价格。
final class Price {
  const Price({
    required this.assetId,
    required this.quote,
    required this.price,
    required this.updatedAt,
    this.change24hPercent,
  });

  final String assetId;
  final Quote quote;
  final Decimal price;

  /// 24 小时涨跌百分比（如 `-2.5` 表示下跌 2.5%），价格源不提供时为 null。
  final Decimal? change24hPercent;

  /// 价格源给出的更新时间（UTC）。
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      other is Price &&
      other.assetId == assetId &&
      other.quote == quote &&
      other.price == price &&
      other.change24hPercent == change24hPercent &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      Object.hash(assetId, quote, price, change24hPercent, updatedAt);

  @override
  String toString() => 'Price($assetId, ${quote.name}, $price)';
}
