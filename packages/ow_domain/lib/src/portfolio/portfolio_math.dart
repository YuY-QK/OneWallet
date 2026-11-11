import 'package:decimal/decimal.dart';

/// 除法结果保留的小数位数。
///
/// `Decimal` 的 `/` 返回有理数（可能是无限小数）。本包在最后一步把有理数
/// 四舍五入（远离零）到 18 位小数再转回 `Decimal`；中间求和一律在精确分数
/// 上进行，不提前截断，因此累计误差不超过最后一步的舍入误差。
const int ratioScale = 18;

/// 精确分数（包内私有用途）。
///
/// `decimal` 包没有导出它依赖的 `Rational` 类型，领域层又不另加依赖，
/// 所以用 `BigInt` 自带一个最小实现，只提供汇总需要的运算。
final class Fraction {
  Fraction._(this._num, this._den);

  /// 把 [value] 精确转为分数。
  factory Fraction.fromDecimal(Decimal value) {
    final r = value.toRational();
    return Fraction._(r.numerator, r.denominator);
  }

  static final Fraction zero = Fraction._(BigInt.zero, BigInt.one);
  static final Fraction one = Fraction._(BigInt.one, BigInt.one);

  /// 整数 [n] 对应的分数。
  factory Fraction.fromInt(int n) => Fraction._(BigInt.from(n), BigInt.one);

  final BigInt _num;
  final BigInt _den; // 恒为正

  static Fraction _make(BigInt n, BigInt d) {
    final g = n.gcd(d);
    if (g == BigInt.zero || g == BigInt.one) return Fraction._(n, d);
    return Fraction._(n ~/ g, d ~/ g);
  }

  bool get isZero => _num == BigInt.zero;

  Fraction operator +(Fraction o) =>
      _make(_num * o._den + o._num * _den, _den * o._den);

  Fraction operator -(Fraction o) =>
      _make(_num * o._den - o._num * _den, _den * o._den);

  Fraction operator *(Fraction o) => _make(_num * o._num, _den * o._den);

  /// 除法；[o] 为 0 时抛 [ArgumentError]（调用方必须先判断）。
  Fraction operator /(Fraction o) {
    if (o.isZero) throw ArgumentError.value(o, 'o', '除数不能为 0');
    final n = _num * o._den;
    final d = _den * o._num;
    return d.isNegative ? _make(-n, -d) : _make(n, d);
  }

  /// 四舍五入（远离零）到 [ratioScale] 位小数。
  Decimal toDecimal() {
    final scaled = _num * BigInt.from(10).pow(ratioScale);
    final twice = scaled.abs() * BigInt.two + _den;
    final q = twice ~/ (_den * BigInt.two);
    return Decimal.fromBigInt(scaled.isNegative ? -q : q).shift(-ratioScale);
  }
}

/// [part] 占 [total] 的百分数（0–100），保留 18 位小数。
///
/// [total] 为 0 时返回 0（不抛除零异常）。[part] 与 [total] 的单位必须一致。
Decimal shareOf(Decimal part, Decimal total) {
  if (total == Decimal.zero) return Decimal.zero;
  return (Fraction.fromDecimal(part) /
          Fraction.fromDecimal(total) *
          Fraction.fromInt(100))
      .toDecimal();
}
