/// TronGrid `/v1/accounts/{地址}` 中与余额相关的部分（单位 sun）。
final class TronAccountBalance {
  const TronAccountBalance({required this.available, required this.staked});

  /// 可用 TRX（`balance`）。
  final BigInt available;

  /// 已质押及解锁等待中的 TRX，见 [parseTronAccount]。
  final BigInt staked;

  BigInt get total => available + staked;
}

BigInt? _sun(Object? v) {
  if (v == null) return BigInt.zero; // 接口常常省略为 0 的字段
  if (v is! int || v < 0) return null;
  return BigInt.from(v);
}

/// 解析 `/v1/accounts/{地址}` 的响应。
///
/// 返回 `(账户, 是否已激活)`；响应结构无效返回 null。`data` 为空数组表示地址
/// 未激活：视为零余额而不是错误。
///
/// 质押口径（只计 Stake 2.0）：
/// - `frozenV2[].amount`：已质押且未委托出去的 TRX（条目可能省略 `amount`，按 0）；
/// - `delegated_frozenV2_balance_for_bandwidth` 与
///   `account_resource.delegated_frozenV2_balance_for_energy`：委托给其他账户使用的
///   质押 TRX，所有权仍在本账户；
/// - `unfrozenV2[].unfreeze_amount`：已申请解锁、等待提取的 TRX。
/// 不计：Stake 1.0 的旧字段（`frozen` 等，已弃用，且文档未说明委托部分是否重复计入）、
/// `allowance`（未领取的投票奖励）。
(TronAccountBalance, bool)? parseTronAccount(Object? body) {
  if (body is! Map<String, Object?>) return null;
  final data = body['data'];
  if (data is! List<Object?>) return null;
  if (data.isEmpty) {
    return (
      TronAccountBalance(available: BigInt.zero, staked: BigInt.zero),
      false,
    );
  }
  final acc = data.first;
  if (acc is! Map<String, Object?>) return null;

  final available = _sun(acc['balance']);
  if (available == null) return null;

  var staked = BigInt.zero;
  for (final entry in _list(acc['frozenV2'])) {
    if (entry is! Map<String, Object?>) return null;
    final v = _sun(entry['amount']);
    if (v == null) return null;
    staked += v;
  }
  for (final entry in _list(acc['unfrozenV2'])) {
    if (entry is! Map<String, Object?>) return null;
    final v = _sun(entry['unfreeze_amount']);
    if (v == null) return null;
    staked += v;
  }
  final resource = acc['account_resource'];
  final delegated = <BigInt?>[
    _sun(acc['delegated_frozenV2_balance_for_bandwidth']),
    if (resource is Map<String, Object?>)
      _sun(resource['delegated_frozenV2_balance_for_energy']),
  ];
  for (final v in delegated) {
    if (v == null) return null;
    staked += v;
  }
  return (TronAccountBalance(available: available, staked: staked), true);
}

List<Object?> _list(Object? v) => v is List<Object?> ? v : const [];

/// 解析 `/v1/accounts/{地址}/trc20/balance` 的一页：把非零余额累加进 [out]
/// （合约 Base58 地址 → 最小单位整数）。返回下一页的 fingerprint（没有则空串），
/// 结构无效返回 null。余额串不是非负整数的条目跳过。
String? parseTrc20Page(Object? body, Map<String, BigInt> out) {
  if (body is! Map<String, Object?>) return null;
  final data = body['data'];
  if (data is! List<Object?>) return null;
  for (final item in data) {
    if (item is! Map<String, Object?>) continue;
    for (final e in item.entries) {
      final v = e.value;
      if (v is! String) continue;
      final amount = BigInt.tryParse(v);
      if (amount == null || amount.isNegative || amount == BigInt.zero) {
        continue;
      }
      out[e.key] = (out[e.key] ?? BigInt.zero) + amount;
    }
  }
  final meta = body['meta'];
  final fp = meta is Map<String, Object?> ? meta['fingerprint'] : null;
  return fp is String ? fp : '';
}

/// TRC-20 合约信息（来自 `/v1/trc20/info`）。
final class Trc20Info {
  const Trc20Info(this.decimals, this.symbol, this.name);
  final int decimals;
  final String? symbol;
  final String? name;
}

/// 解析 `/v1/trc20/info`：合约地址 → 信息。`decimals` 是字符串，缺失或越界的
/// 条目跳过。结构无效返回 null。
Map<String, Trc20Info>? parseTrc20Info(Object? body) {
  if (body is! Map<String, Object?>) return null;
  final data = body['data'];
  if (data is! List<Object?>) return null;
  final out = <String, Trc20Info>{};
  String? text(Object? v) => v is String && v.trim().isNotEmpty ? v : null;
  for (final item in data) {
    if (item is! Map<String, Object?>) continue;
    final contract = item['contract_address'];
    final d = item['decimals'];
    final decimals = d is String ? int.tryParse(d) : (d is int ? d : null);
    if (contract is! String || decimals == null) continue;
    if (decimals < 0 || decimals > 77) continue;
    out[contract] = Trc20Info(
      decimals,
      text(item['symbol']),
      text(item['name']),
    );
  }
  return out;
}
