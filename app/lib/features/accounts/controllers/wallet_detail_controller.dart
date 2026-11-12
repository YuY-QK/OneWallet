import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../../bootstrap/providers.dart';
import 'wallet_detail_view.dart';

/// P07 视图模型。账户不存在时数据为 null。
final walletDetailViewProvider = Provider.autoDispose
    .family<AsyncValue<WalletDetailView?>, String>((ref, accountId) {
      final accounts = ref.watch(accountsProvider);
      final addresses = ref.watch(addressesProvider);
      final holdings = ref.watch(holdingsProvider);
      final prices = ref.watch(quotePricesProvider);
      final records = ref.watch(latestSyncRecordsProvider);
      final lastSuccess = ref.watch(lastSuccessPerAccountProvider);
      final syncing = ref.watch(syncingAccountIdsProvider);
      for (final v in <AsyncValue<Object?>>[
        accounts,
        addresses,
        holdings,
        prices,
        records,
        lastSuccess,
        syncing,
      ]) {
        if (v case AsyncError(:final error, :final stackTrace)) {
          return AsyncError(error, stackTrace);
        }
      }
      final a = accounts.value;
      final d = addresses.value;
      final h = holdings.value;
      final p = prices.value;
      final r = records.value;
      final l = lastSuccess.value;
      final y = syncing.value;
      if (a == null ||
          d == null ||
          h == null ||
          p == null ||
          r == null ||
          l == null ||
          y == null) {
        return const AsyncLoading();
      }
      final account = a.where((x) => x.id == accountId).firstOrNull;
      if (account == null) return const AsyncData(null);
      return AsyncData(
        buildWalletDetail(
          account: account,
          addresses: [
            for (final x in d)
              if (x.accountId == accountId) x,
          ],
          holdings: h,
          prices: p,
          record: r.where((x) => x.accountId == accountId).firstOrNull,
          lastSuccessAt: l[accountId],
          syncing: y.contains(accountId),
        ),
      );
    });

/// P07 的操作：同步该账户、删除地址。
///
/// 不用 autoDispose：它只持有 `Ref`，没有状态；页面用 `read` 取用时不应被回收。
final walletDetailActionsProvider =
    Provider.family<WalletDetailActions, String>(
      (ref, accountId) => WalletDetailActions(ref, accountId),
    );

class WalletDetailActions {
  WalletDetailActions(this._ref, this.accountId);

  final Ref _ref;
  final String accountId;

  /// 同步该账户（下拉刷新）；同账户已在同步时合并到进行中的那次。
  Future<void> refresh() async {
    await _ref.read(syncAccountProvider)(accountId);
  }

  /// 进入页面时：从未同步过的账户立即同步一次，页面显示加载状态直到有结果。
  Future<void> syncIfNeverSynced() async {
    // 直接读仓储的当前值：provider 的缓存可能落后于刚写入的记录，
    // 那样会在"添加账户后立即同步"之外再同步一次。
    final records = await _ref
        .read(syncRecordRepositoryProvider)
        .watchLatestPerAccount()
        .first;
    if (!_ref.mounted) return;
    if (records.any((r) => r.accountId == accountId)) return;
    await refresh();
  }

  /// 删除一个地址（账户至少保留一个）。成功返回 true 并重新同步该账户，
  /// 让已删除地址的余额缓存被清掉；账户只剩一个地址时返回 false，不删除。
  Future<bool> deleteAddress(String addressId) async {
    final result = await _ref.read(deleteAddressProvider)(addressId);
    if (result is Err) return false;
    unawaited(refresh());
    return true;
  }
}
