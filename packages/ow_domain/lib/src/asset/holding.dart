import 'package:decimal/decimal.dart';

import 'holding_location.dart';
import 'token_ref.dart';

/// 适配器的输出：一笔尚未归一化的余额。
final class RawHolding {
  const RawHolding({
    required this.token,
    required this.amount,
    this.symbolHint,
    this.nameHint,
  });

  final TokenRef token;

  /// 以代币为单位的数量（已按小数位换算）。
  final Decimal amount;

  /// 数据源给出的符号，仅用于显示未识别代币。
  final String? symbolHint;

  /// 数据源给出的名称，仅用于显示未识别代币。
  final String? nameHint;

  @override
  bool operator ==(Object other) =>
      other is RawHolding &&
      other.token == token &&
      other.amount == amount &&
      other.symbolHint == symbolHint &&
      other.nameHint == nameHint;

  @override
  int get hashCode => Object.hash(token, amount, symbolHint, nameHint);

  @override
  String toString() => 'RawHolding($token, $amount)';
}

/// 归一化之后、存入数据库的一笔持仓：账户 → 位置 → 币种（PRD R7）。
final class Holding {
  const Holding({
    required this.accountId,
    required this.location,
    required this.token,
    required this.displaySymbol,
    required this.amount,
    required this.updatedAt,
    this.assetId,
  });

  final String accountId;
  final HoldingLocation location;
  final TokenRef token;

  /// 归一化成功时为标准币种 id；未识别代币为 null（R8）。
  final String? assetId;
  final String displaySymbol;
  final Decimal amount;

  /// 数据更新时间（UTC）。
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      other is Holding &&
      other.accountId == accountId &&
      other.location == location &&
      other.token == token &&
      other.assetId == assetId &&
      other.displaySymbol == displaySymbol &&
      other.amount == amount &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    accountId,
    location,
    token,
    assetId,
    displaySymbol,
    amount,
    updatedAt,
  );

  @override
  String toString() => 'Holding($accountId, $location, $token, $amount)';
}
