import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../../bootstrap/providers.dart';

/// 地址簿的过滤状态（PRD P10）。
@immutable
final class AddressBookFilter {
  const AddressBookFilter({this.query = '', this.family, this.accountId});

  /// 搜索词（地址片段、账户名、备注、完整地址）。
  final String query;

  /// 过滤的链家族（null 表示全部链）。
  final ChainFamily? family;

  /// 过滤的账户 id（null 表示全部账户）。
  final String? accountId;

  AddressBookFilter copyWith({
    String? query,
    ChainFamily? family,
    bool clearFamily = false,
    String? accountId,
    bool clearAccount = false,
  }) => AddressBookFilter(
    query: query ?? this.query,
    family: clearFamily ? null : (family ?? this.family),
    accountId: clearAccount ? null : (accountId ?? this.accountId),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AddressBookFilter &&
          runtimeType == other.runtimeType &&
          query == other.query &&
          family == other.family &&
          accountId == other.accountId;

  @override
  int get hashCode => Object.hash(query, family, accountId);
}

/// 过滤器状态控制器。
class AddressBookFilterController extends Notifier<AddressBookFilter> {
  @override
  AddressBookFilter build() => const AddressBookFilter();

  void setQuery(String query) => state = state.copyWith(query: query);

  void setFamily(ChainFamily? family) =>
      state = state.copyWith(family: family, clearFamily: family == null);

  void setAccountId(String? accountId) => state = state.copyWith(
    accountId: accountId,
    clearAccount: accountId == null,
  );

  void reset() => state = const AddressBookFilter();
}

final addressBookFilterProvider =
    NotifierProvider.autoDispose<
      AddressBookFilterController,
      AddressBookFilter
    >(AddressBookFilterController.new);

/// 地址簿视图状态（PRD P10）。
@immutable
final class AddressBookState {
  const AddressBookState({
    required this.entries,
    required this.allAddresses,
    required this.walletAccounts,
    required this.filter,
  });

  /// 过滤和搜索后的条目列表。
  final List<AddressSearchResult> entries;

  /// 全部观察地址（用于统计账户包含的地址数以判断是否可删除）。
  final List<WatchAddress> allAddresses;

  /// 全部钱包账户（用于账户筛选）。
  final List<Account> walletAccounts;

  /// 当前过滤器状态。
  final AddressBookFilter filter;

  /// 是否没有任何观察地址（空状态）。
  bool get isCompletelyEmpty => allAddresses.isEmpty;

  /// 是否在有地址的情况下搜索与筛选结果为空。
  bool get isSearchEmpty => !isCompletelyEmpty && entries.isEmpty;
}

/// 地址簿的视图模型 provider。
final addressBookProvider = Provider.autoDispose<AsyncValue<AddressBookState>>((
  ref,
) {
  final accountsAsync = ref.watch(accountsProvider);
  final addressesAsync = ref.watch(addressesProvider);
  final filter = ref.watch(addressBookFilterProvider);
  final searchAddresses = ref.watch(searchAddressesProvider);

  if (accountsAsync case AsyncError(:final error, :final stackTrace)) {
    return AsyncError(error, stackTrace);
  }
  if (addressesAsync case AsyncError(:final error, :final stackTrace)) {
    return AsyncError(error, stackTrace);
  }

  final accounts = accountsAsync.value;
  final addresses = addressesAsync.value;
  if (accounts == null || addresses == null) {
    return const AsyncLoading();
  }

  final walletAccounts = accounts
      .where((a) => a.type == AccountType.wallet)
      .toList();
  final accountsById = {for (final a in accounts) a.id: a};

  final entries = searchAddresses.execute(
    addresses: addresses,
    accountsById: accountsById,
    query: filter.query,
    family: filter.family,
    accountId: filter.accountId,
  );

  return AsyncData(
    AddressBookState(
      entries: entries,
      allAddresses: addresses,
      walletAccounts: walletAccounts,
      filter: filter,
    ),
  );
});
