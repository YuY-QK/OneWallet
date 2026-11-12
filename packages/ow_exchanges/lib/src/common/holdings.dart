import 'package:decimal/decimal.dart';
import 'package:ow_domain/ow_domain.dart';

import 'exact_json.dart';

/// 把接口返回的金额（字符串，个别为 JSON 数字）转成 [Decimal]。
/// 缺失、空串、非数字返回 null；空串在 Bitget 等接口里表示 0，由调用方用 [amountOrZero] 处理。
Decimal? parseAmount(Object? value) => decimalFromJson(value);

/// 同 [parseAmount]，但缺失或空串按 0 处理；非法数字仍返回 null。
Decimal? amountOrZero(Object? value) {
  if (value == null) return Decimal.zero;
  if (value is String && value.trim().isEmpty) return Decimal.zero;
  return decimalFromJson(value);
}

/// 累加 `(子账户, 币种)` 的数量，最后输出 `List<(ExchangeSubAccount, RawHolding)>`。
///
/// - 同一子账户里同一币种的多笔记录求和（例如多个合约账户的同一结算币）；
/// - 合计为 0 的丢弃，负数保留（杠杆账户的净资产可以为负）；
/// - 币种符号统一大写；输出顺序为首次出现的顺序。
final class HoldingsAccumulator {
  HoldingsAccumulator(this.exchange);

  final ExchangeId exchange;
  final Map<(ExchangeSubAccount, String), Decimal> _sums = {};

  /// 累加一笔；[symbol] 为空串时忽略。
  void add(ExchangeSubAccount sub, String symbol, Decimal amount) {
    final key = (sub, symbol.toUpperCase());
    if (key.$2.isEmpty) return;
    _sums[key] = (_sums[key] ?? Decimal.zero) + amount;
  }

  List<(ExchangeSubAccount, RawHolding)> build() => [
    for (final e in _sums.entries)
      if (e.value != Decimal.zero)
        (
          e.key.$1,
          RawHolding(
            token: ExchangeToken(exchange, e.key.$2),
            amount: e.value,
            symbolHint: e.key.$2,
          ),
        ),
  ];
}

/// 返回 [requested] 中不在 [allowed] 里的路径（去重）。
///
/// 供适配器测试断言"发出的请求都在只读路径白名单里"：
/// `expect(pathsOutsideAllowlist(fake.paths, binanceReadOnlyPaths), isEmpty)`。
List<String> pathsOutsideAllowlist(
  Iterable<String> requested,
  Set<String> allowed,
) => {
  for (final p in requested)
    if (!allowed.contains(p)) p,
}.toList();
