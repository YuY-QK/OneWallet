import 'package:ow_domain/ow_domain.dart';

/// 地址簿搜索结果条目（PRD P10、TASKS M3-04）。
final class AddressSearchResult {
  const AddressSearchResult({
    required this.address,
    required this.account,
    this.isExactMatch = false,
  });

  final WatchAddress address;
  final Account account;

  /// 查询词是否与该地址完全匹配（用于精确回答“这个地址是不是我的”）。
  final bool isExactMatch;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AddressSearchResult &&
          runtimeType == other.runtimeType &&
          address == other.address &&
          account == other.account &&
          isExactMatch == other.isExactMatch;

  @override
  int get hashCode => Object.hash(address, account, isExactMatch);
}

/// 集中查找和管理所有地址的搜索用例（PRD P10、TASKS M3-04）。
final class SearchAddresses {
  const SearchAddresses({
    this.accounts,
    this.addresses,
    this.codec = const AddressCodec(),
  });

  final AccountRepository? accounts;
  final AddressRepository? addresses;
  final AddressCodec codec;

  /// 对内存中的数据进行过滤与搜索（同步纯函数逻辑）。
  List<AddressSearchResult> execute({
    required List<WatchAddress> addresses,
    required Map<String, Account> accountsById,
    String query = '',
    ChainFamily? family,
    String? accountId,
  }) {
    final q = query.trim();
    final qLower = q.toLowerCase();

    final results = <AddressSearchResult>[];

    for (final addr in addresses) {
      // 1. 过滤链家族
      if (family != null && addr.family != family) {
        continue;
      }

      // 2. 过滤所属账户
      if (accountId != null && addr.accountId != accountId) {
        continue;
      }

      final account = accountsById[addr.accountId];
      if (account == null) continue;

      if (q.isEmpty) {
        results.add(AddressSearchResult(address: addr, account: account));
        continue;
      }

      // 3. 匹配逻辑
      final normalizedAddr = addr.address.toLowerCase();
      final displayAddr = codec
          .display(addr.address, addr.family)
          .toLowerCase();
      final isExact = qLower == normalizedAddr || qLower == displayAddr;

      final matchAddressSnippet =
          normalizedAddr.contains(qLower) || displayAddr.contains(qLower);
      final matchAccount = account.name.toLowerCase().contains(qLower);
      final matchNote = addr.note.toLowerCase().contains(qLower);

      if (isExact || matchAddressSnippet || matchAccount || matchNote) {
        results.add(
          AddressSearchResult(
            address: addr,
            account: account,
            isExactMatch: isExact,
          ),
        );
      }
    }

    // 精确匹配排在最前面
    results.sort((a, b) {
      if (a.isExactMatch && !b.isExactMatch) return -1;
      if (!a.isExactMatch && b.isExactMatch) return 1;
      return 0;
    });

    return results;
  }

  /// 从仓储拉取最新数据并执行搜索。
  Future<List<AddressSearchResult>> call({
    String query = '',
    ChainFamily? family,
    String? accountId,
  }) async {
    assert(
      accounts != null && addresses != null,
      'accounts and addresses repositories must be provided to call()',
    );
    final accts = await accounts!.watchAll().first;
    final addrs = await addresses!.all();
    final accountsById = <String, Account>{for (final a in accts) a.id: a};
    return execute(
      addresses: addrs,
      accountsById: accountsById,
      query: query,
      family: family,
      accountId: accountId,
    );
  }
}
