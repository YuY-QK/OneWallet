import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../../bootstrap/providers.dart';

/// P03 组内排序方式（PRD P03）。
enum AccountSortOrder {
  /// 默认按估值降序（同值按名称升序）。
  valuation,

  /// 按名称升序（同名按估值降序）。
  name,
}

/// 账户列表当前的排序方式。
final accountSortOrderProvider =
    NotifierProvider.autoDispose<AccountSortOrderController, AccountSortOrder>(
      AccountSortOrderController.new,
    );

class AccountSortOrderController extends Notifier<AccountSortOrder> {
  @override
  AccountSortOrder build() => AccountSortOrder.valuation;

  void setOrder(AccountSortOrder order) => state = order;
}

/// P03 的一行。
@immutable
final class AccountRowData {
  const AccountRowData({
    required this.account,
    required this.value,
    required this.syncFailed,
    required this.syncing,
  });

  final Account account;

  /// 账户估值（有估值部分的合计）。
  final Decimal value;

  /// 最近一次同步失败。
  final bool syncFailed;

  /// 正在同步。
  final bool syncing;
}

/// P03 的分组数据：钱包与交易所各一组，组内按指定规则排序。
@immutable
final class AccountsListData {
  const AccountsListData({required this.wallets, required this.exchanges});

  final List<AccountRowData> wallets;
  final List<AccountRowData> exchanges;

  bool get isEmpty => wallets.isEmpty && exchanges.isEmpty;
}

/// P03 账户列表的操作。
final class AccountsListActions {
  AccountsListActions({
    required this.renameAccount,
    required this.deleteAccount,
  });

  final RenameAccount renameAccount;
  final DeleteAccount deleteAccount;

  Future<Result<Account>> rename({
    required String accountId,
    required String newName,
  }) => renameAccount(accountId: accountId, newName: newName);

  Future<Result<void>> delete(String accountId) => deleteAccount(accountId);
}

final accountsListActionsProvider = Provider<AccountsListActions>((ref) {
  return AccountsListActions(
    renameAccount: ref.watch(renameAccountProvider),
    deleteAccount: ref.watch(deleteAccountProvider),
  );
});

/// P03 账户列表的视图模型。
final accountsListProvider = Provider.autoDispose<AsyncValue<AccountsListData>>(
  (ref) {
    final accounts = ref.watch(accountsProvider);
    final summary = ref.watch(portfolioSummaryProvider);
    final records = ref.watch(latestSyncRecordsProvider);
    final syncing = ref.watch(syncingAccountIdsProvider);
    final sortOrder = ref.watch(accountSortOrderProvider);

    for (final v in <AsyncValue<Object?>>[
      accounts,
      summary,
      records,
      syncing,
    ]) {
      if (v case AsyncError(:final error, :final stackTrace)) {
        return AsyncError(error, stackTrace);
      }
    }
    final a = accounts.value;
    final s = summary.value;
    final r = records.value;
    final y = syncing.value;
    if (a == null || s == null || r == null || y == null) {
      return const AsyncLoading();
    }
    final values = {for (final x in s.byAccount) x.accountId: x.value};
    final failed = {
      for (final x in r)
        if (x.status == SyncStatus.failed) x.accountId,
    };

    List<AccountRowData> group(AccountType type) {
      final list = [
        for (final x in a)
          if (x.type == type)
            AccountRowData(
              account: x,
              value: values[x.id] ?? Decimal.zero,
              syncFailed: failed.contains(x.id),
              syncing: y.contains(x.id),
            ),
      ];
      list.sort((p, q) {
        if (sortOrder == AccountSortOrder.name) {
          final c = p.account.name.compareTo(q.account.name);
          return c != 0 ? c : q.value.compareTo(p.value);
        } else {
          final c = q.value.compareTo(p.value);
          return c != 0 ? c : p.account.name.compareTo(q.account.name);
        }
      });
      return list;
    }

    return AsyncData(
      AccountsListData(
        wallets: group(AccountType.wallet),
        exchanges: group(AccountType.exchange),
      ),
    );
  },
);
