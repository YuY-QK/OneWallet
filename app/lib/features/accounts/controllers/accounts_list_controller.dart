import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../../bootstrap/providers.dart';

/// P03 的一行。
@immutable
final class AccountRowData {
  const AccountRowData({
    required this.account,
    required this.value,
    required this.syncFailed,
  });

  final Account account;

  /// 账户估值（有估值部分的合计）。
  final Decimal value;

  /// 最近一次同步失败。
  final bool syncFailed;
}

/// P03 的分组数据：钱包与交易所各一组，组内按估值降序（同值按名称）。
@immutable
final class AccountsListData {
  const AccountsListData({required this.wallets, required this.exchanges});

  final List<AccountRowData> wallets;
  final List<AccountRowData> exchanges;

  bool get isEmpty => wallets.isEmpty && exchanges.isEmpty;
}

/// P03 账户列表的视图模型。
final accountsListProvider = Provider.autoDispose<AsyncValue<AccountsListData>>(
  (ref) {
    final accounts = ref.watch(accountsProvider);
    final summary = ref.watch(portfolioSummaryProvider);
    final records = ref.watch(latestSyncRecordsProvider);
    for (final v in <AsyncValue<Object?>>[accounts, summary, records]) {
      if (v case AsyncError(:final error, :final stackTrace)) {
        return AsyncError(error, stackTrace);
      }
    }
    final a = accounts.value;
    final s = summary.value;
    final r = records.value;
    if (a == null || s == null || r == null) return const AsyncLoading();
    final values = {for (final x in s.byAccount) x.accountId: x.value};
    final failed = {
      for (final x in r)
        if (x.status == SyncStatus.failed) x.accountId,
    };
    List<AccountRowData> group(AccountType type) =>
        [
          for (final x in a)
            if (x.type == type)
              AccountRowData(
                account: x,
                value: values[x.id] ?? Decimal.zero,
                syncFailed: failed.contains(x.id),
              ),
        ]..sort((p, q) {
          final c = q.value.compareTo(p.value);
          return c != 0 ? c : p.account.name.compareTo(q.account.name);
        });
    return AsyncData(
      AccountsListData(
        wallets: group(AccountType.wallet),
        exchanges: group(AccountType.exchange),
      ),
    );
  },
);
