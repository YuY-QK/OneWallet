import 'package:decimal/decimal.dart';

import '../l10n/app_localizations.dart';

// 显示规则的格式化函数，规则见 docs/IMPLEMENTATION_SPEC_v1.0.md 第 7.3 节。
//
// 全部是纯函数：不读取系统时间、不依赖界面上下文，便于测试。
// 金额与数量一律用 Decimal，不经过 double。

/// 隐藏金额时显示的占位。
const String hiddenAmountMask = '****';

/// 美元符号。
const String fiatSymbolUsd = r'$';

/// 人民币符号。
const String fiatSymbolCny = '¥';

/// 数量的有效数字上限。
const int _quantitySignificantDigits = 8;

/// 数量能显示的最小非零值，比它小的显示为 `<0.00000001`。
final Decimal _quantityFloor = Decimal.parse('0.00000001');

/// 估值：货币符号加两位小数，千分位分隔，如 `$128,450.32`、`¥921,330.10`。
///
/// 第三位小数四舍五入（远离零）。负数把负号放在货币符号前：`-$12.50`。
/// [hidden] 为真时返回 [hiddenAmountMask]。
String formatFiat(
  Decimal value, {
  required String symbol,
  bool hidden = false,
}) {
  if (hidden) return hiddenAmountMask;
  final fixed = value.toStringAsFixed(2);
  final negative = fixed.startsWith('-');
  final unsigned = negative ? fixed.substring(1) : fixed;
  final dot = unsigned.indexOf('.');
  final grouped = _groupThousands(unsigned.substring(0, dot));
  return '${negative ? '-' : ''}$symbol$grouped${unsigned.substring(dot)}';
}

/// 数量：最多 8 位有效数字，去掉尾随零；非零且小于 `0.00000001` 显示
/// `<0.00000001`；零显示 `0`。
///
/// 超出 8 位有效数字的部分**截断**（向零取整）而不是四舍五入，避免显示出
/// 比实际持有更多的数量。整数部分本身超过 8 位时不动整数部分，只是不再
/// 显示小数。不加千分位（规格 7.3 只对估值要求千分位）。
/// [hidden] 为真时返回 [hiddenAmountMask]。
String formatQuantity(Decimal value, {bool hidden = false}) {
  if (hidden) return hiddenAmountMask;
  if (value.sign == 0) return '0';
  final abs = value.abs();
  final sign = value.sign < 0 ? '-' : '';
  if (abs < _quantityFloor) return '<$_quantityFloor';

  final parts = abs.toString().split('.');
  final intPart = parts[0];
  final frac = parts.length > 1 ? parts[1] : '';
  final int allowed;
  if (intPart != '0') {
    allowed = _quantitySignificantDigits - intPart.length;
  } else {
    // 小于 1：前导零不算有效数字。
    final leadingZeros =
        frac.length - frac.replaceFirst(RegExp('^0+'), '').length;
    allowed = leadingZeros + _quantitySignificantDigits;
  }
  var kept = allowed <= 0
      ? ''
      : (frac.length > allowed ? frac.substring(0, allowed) : frac);
  kept = kept.replaceFirst(RegExp(r'0+$'), '');
  return kept.isEmpty ? '$sign$intPart' : '$sign$intPart.$kept';
}

/// 百分比：带正负号，默认两位小数，[fractionDigits] 只能是 1 或 2。
///
/// [percent] 是已经乘过 100 的数值：`1.234` 表示 1.234%，显示 `+1.23%`。
/// 四舍五入后为零的显示为不带符号的 `0.00%`。
String formatPercent(Decimal percent, {int fractionDigits = 2}) {
  assert(fractionDigits == 1 || fractionDigits == 2, '百分比只显示一位或两位小数');
  final rounded = percent.round(scale: fractionDigits);
  final text = rounded.abs().toStringAsFixed(fractionDigits);
  if (rounded.sign == 0) return '$text%';
  return '${rounded.sign > 0 ? '+' : '-'}$text%';
}

/// 地址缩略：前 [head] 位加 `…` 加后 [tail] 位，默认前 6 后 4。
///
/// 地址不比缩略结果长时原样返回。详情面板显示完整地址，不调用本函数。
String shortenAddress(String address, {int head = 6, int tail = 4}) {
  if (address.length <= head + tail + 1) return address;
  return '${address.substring(0, head)}…${address.substring(address.length - tail)}';
}

/// 隐藏金额：[hidden] 为真时返回 [hiddenAmountMask]，否则原样返回 [text]。
String maskIfHidden(String text, {required bool hidden}) =>
    hidden ? hiddenAmountMask : text;

/// 相对时间。
///
/// - 不足 1 分钟（含 [time] 晚于 [now] 的时钟误差）：`刚刚`
/// - 不足 1 小时：`N 分钟前`
/// - 超过 1 小时但与 [now] 同一天：`HH:mm`
/// - 更早：`MM-DD HH:mm`
///
/// 当前时间由调用方传入（来自注入的 `Clock`），这里不读取系统时间。
/// 两个时间都先转为本地时间再判断"当天"。
String formatRelativeTime(
  DateTime time, {
  required DateTime now,
  required AppLocalizations l10n,
}) {
  final diff = now.difference(time);
  if (diff < const Duration(minutes: 1)) return l10n.timeJustNow;
  if (diff < const Duration(hours: 1)) {
    return l10n.timeMinutesAgo(diff.inMinutes);
  }
  final t = time.toLocal();
  final n = now.toLocal();
  final hm = '${_two(t.hour)}:${_two(t.minute)}';
  final sameDay = t.year == n.year && t.month == n.month && t.day == n.day;
  return sameDay ? hm : '${_two(t.month)}-${_two(t.day)} $hm';
}

String _two(int v) => v.toString().padLeft(2, '0');

/// 给整数部分的数字串加千分位逗号。
String _groupThousands(String digits) {
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return buf.toString();
}
