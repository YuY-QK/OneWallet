import 'package:decimal/decimal.dart';
import 'package:ow_domain/ow_domain.dart';

import '../sync/sync_all_result.dart';

/// 纯函数：根据当前持仓与 USD 价格计算当日净值快照（无 IO、无浮点数计算）。
Snapshot buildDailySnapshot({
  required DateTime now,
  required bool complete,
  required List<Account> accounts,
  required List<Holding> holdings,
  required Map<String, Price> usdPrices,
}) {
  final date = DateTime.utc(now.year, now.month, now.day);
  final byAccountUsd = <String, Decimal>{
    for (final a in accounts) a.id: Decimal.zero,
  };
  final byAssetUsd = <String, Decimal>{};
  var totalUsd = Decimal.zero;

  for (final h in holdings) {
    if (!byAccountUsd.containsKey(h.accountId)) continue;
    final assetId = h.assetId;
    if (assetId == null) continue;
    final price = usdPrices[assetId];
    if (price == null) continue;

    final value = h.amount * price.price;
    totalUsd += value;
    byAccountUsd[h.accountId] = byAccountUsd[h.accountId]! + value;
    byAssetUsd[assetId] = (byAssetUsd[assetId] ?? Decimal.zero) + value;
  }

  return Snapshot(
    date: date,
    totalUsd: totalUsd,
    complete: complete,
    byAccountUsd: byAccountUsd,
    byAssetUsd: byAssetUsd,
  );
}

/// 全量同步结束后的每日快照记录用例（PRD R16、TASKS M3-05）。
///
/// - 每天第一次全量同步成功后写入一条净值快照；当天之后的同步覆盖当天快照（以 date 为主键）。
/// - 有账户同步失败或取消时，该账户沿用上次余额计入快照，并在快照上记录 `complete = false`。
/// - 全部账户同步成功且价格更新成功时，记录 `complete = true`。
/// - 若库中没有任何账户，不记录快照并返回 null。
final class RecordDailySnapshot {
  const RecordDailySnapshot({
    required this.accounts,
    required this.holdings,
    required this.prices,
    required this.snapshots,
    required this.clock,
  });

  final AccountRepository accounts;
  final HoldingRepository holdings;
  final PriceRepository prices;
  final SnapshotRepository snapshots;
  final Clock clock;

  Future<Snapshot?> call([SyncAllResult? result]) async {
    final accountList = await accounts.watchAll().first;
    if (accountList.isEmpty) return null;

    final holdingList = await holdings.watchAll().first;
    final priceMap = await prices.watch(Quote.usd).first;

    final complete = result == null
        ? true
        : (result.allAccountsSucceeded &&
              result.pricesUpdated &&
              result.priceFailure == null);
    final now = clock.nowUtc();

    final snapshot = buildDailySnapshot(
      now: now,
      complete: complete,
      accounts: accountList,
      holdings: holdingList,
      usdPrices: priceMap,
    );

    await snapshots.upsert(snapshot);
    return snapshot;
  }
}
