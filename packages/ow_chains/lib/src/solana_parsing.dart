/// 一个 mint 在某地址下的合并余额（可能来自多个代币账户）。
final class MintBalance {
  MintBalance(this.amount, this.decimals);

  /// 最小单位的整数数量。
  BigInt amount;

  /// 该 mint 的小数位数（mint 级属性，同一 mint 的各账户一致）。
  final int decimals;
}

/// 解析 `getBalance` 的 `result`：`{"context": {...}, "value": <lamports>}`。
/// 无效返回 null。
BigInt? parseBalanceResult(Object? result) {
  if (result is! Map<String, Object?>) return null;
  final v = result['value'];
  if (v is! int || v < 0) return null;
  return BigInt.from(v);
}

/// 解析 `getTokenAccountsByOwner`（`jsonParsed`）的 `result`，把每个代币账户的
/// 余额累加到 [out]（按 mint 合并）。
///
/// 整体结构无效（不是 `{value: [...]}`）返回 false。单个账户不是可解析的
/// 代币账户（缺字段、`amount` 不是非负整数串、`decimals` 越界）时跳过该账户：
/// 例如 Token-2022 下偶有未能解析为 `account` 的条目。
/// 数量只用 `amount` 字符串，不使用 `uiAmount`（浮点）。
bool parseTokenAccounts(Object? result, Map<String, MintBalance> out) {
  if (result is! Map<String, Object?>) return false;
  final value = result['value'];
  if (value is! List<Object?>) return false;
  for (final item in value) {
    final info = _accountInfo(item);
    if (info == null) continue;
    final mint = info['mint'];
    final tokenAmount = info['tokenAmount'];
    if (mint is! String || mint.isEmpty) continue;
    if (tokenAmount is! Map<String, Object?>) continue;
    final amountText = tokenAmount['amount'];
    final decimals = tokenAmount['decimals'];
    if (amountText is! String || decimals is! int) continue;
    if (decimals < 0 || decimals > 77) continue;
    final amount = BigInt.tryParse(amountText);
    if (amount == null || amount.isNegative) continue;
    final existing = out[mint];
    if (existing == null) {
      out[mint] = MintBalance(amount, decimals);
    } else if (existing.decimals == decimals) {
      existing.amount += amount;
    }
    // 同一 mint 的小数位不一致属于异常数据，忽略后来者。
  }
  return true;
}

Map<String, Object?>? _accountInfo(Object? item) {
  if (item is! Map<String, Object?>) return null;
  final account = item['account'];
  if (account is! Map<String, Object?>) return null;
  final data = account['data'];
  if (data is! Map<String, Object?>) return null;
  final parsed = data['parsed'];
  if (parsed is! Map<String, Object?>) return null;
  final info = parsed['info'];
  return info is Map<String, Object?> ? info : null;
}

/// 合并后 `decimals == 0` 且数量恰为 1 的 mint 视为 NFT（每个 NFT 是独立的 mint，
/// 供应量为 1、不可分）。代价：持有恰好 1 个最小单位的 0 位小数同质化代币时会被
/// 当作 NFT 过滤，v1 接受。
bool isLikelyNft(MintBalance b) => b.decimals == 0 && b.amount == BigInt.one;
