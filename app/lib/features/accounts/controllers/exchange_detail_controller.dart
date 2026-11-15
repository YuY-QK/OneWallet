import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:ow_exchanges/ow_exchanges.dart';

import '../../../bootstrap/providers.dart';
import 'exchange_detail_view.dart';

/// 各交易所适配器静态声明的未包含产品。
List<String> exchangeNotIncluded(ExchangeId id) => switch (id) {
  ExchangeId.binance => BinanceAdapter.notIncluded,
  ExchangeId.okx => OkxAdapter.notIncluded,
  ExchangeId.bybit => BybitAdapter.notIncluded,
  ExchangeId.bitget => const [],
};

/// 获取适配器上一次同步跳过的产品列表（Key 权限不足跳过的部分）。
List<String> exchangeLastSkipped(ExchangeAdapter adapter) => switch (adapter) {
  final BinanceAdapter a => a.lastSkipped,
  final OkxAdapter a => a.lastSkipped,
  final BybitAdapter a => a.lastSkipped,
  _ => const [],
};

/// P08 视图模型。账户不存在或非交易所账户时数据为 null。
final exchangeDetailViewProvider = Provider.autoDispose
    .family<AsyncValue<ExchangeDetailView?>, String>((ref, accountId) {
      final accounts = ref.watch(accountsProvider);
      final holdings = ref.watch(holdingsProvider);
      final prices = ref.watch(quotePricesProvider);
      final records = ref.watch(latestSyncRecordsProvider);
      final lastSuccess = ref.watch(lastSuccessPerAccountProvider);
      final syncing = ref.watch(syncingAccountIdsProvider);
      final adapters = ref.watch(adapterRegistryProvider);

      for (final v in <AsyncValue<Object?>>[
        accounts,
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
      final h = holdings.value;
      final p = prices.value;
      final r = records.value;
      final l = lastSuccess.value;
      final y = syncing.value;

      if (a == null ||
          h == null ||
          p == null ||
          r == null ||
          l == null ||
          y == null) {
        return const AsyncLoading();
      }

      final account = a.where((x) => x.id == accountId).firstOrNull;
      if (account == null || account.type != AccountType.exchange) {
        return const AsyncData(null);
      }

      final exchangeId = account.exchange;
      final List<String> notIncluded;
      final List<String> lastSkipped;
      if (exchangeId != null) {
        notIncluded = exchangeNotIncluded(exchangeId);
        final adapter = adapters.exchange(exchangeId);
        lastSkipped = exchangeLastSkipped(adapter);
      } else {
        notIncluded = const [];
        lastSkipped = const [];
      }

      return AsyncData(
        buildExchangeDetail(
          account: account,
          holdings: h,
          prices: p,
          record: r.where((x) => x.accountId == accountId).firstOrNull,
          lastSuccessAt: l[accountId],
          syncing: y.contains(accountId),
          notIncluded: notIncluded,
          lastSkipped: lastSkipped,
        ),
      );
    });

/// P08 的操作：同步该账户、删除账户。
final exchangeDetailActionsProvider =
    Provider.family<ExchangeDetailActions, String>(
      (ref, accountId) => ExchangeDetailActions(ref, accountId),
    );

class ExchangeDetailActions {
  ExchangeDetailActions(this._ref, this.accountId);

  final Ref _ref;
  final String accountId;

  /// 同步该账户（下拉刷新）；同账户已在同步时合并到进行中的那次。
  Future<void> refresh() async {
    await _ref.read(syncAccountProvider)(accountId);
  }

  /// 进入页面时：从未同步过的账户立即同步一次，页面显示加载状态直到有结果。
  Future<void> syncIfNeverSynced() async {
    final records = await _ref
        .read(syncRecordRepositoryProvider)
        .watchLatestPerAccount()
        .first;
    if (!_ref.mounted) return;
    if (records.any((r) => r.accountId == accountId)) return;
    await refresh();
  }

  /// 删除账户（R6）：级联删除持仓与同步记录，并删除存储的 API 凭据。
  Future<void> deleteAccount() async {
    await _ref.read(accountRepositoryProvider).delete(accountId);
    await _ref.read(credentialRepositoryProvider).delete(accountId);
  }
}
