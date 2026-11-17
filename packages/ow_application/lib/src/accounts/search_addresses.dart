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
    required this.accounts,
    required this.addresses,
    this.codec = const AddressCodec(),
  });

  final AccountRepository accounts;
  final AddressRepository addresses;
  final AddressCodec codec;

  /// 对内存中的数据进行过滤与搜索（同步纯函数逻辑）。
  List<AddressSearchResult> execute({
    required List<WatchAddress> addresses,
    required Map<String, Account> accountsById,
    String query = '',
    ChainFamily? family,
    String? accountId,
  }) => executeSearchAddresses(
    addresses: addresses,
    accountsById: accountsById,
    query: query,
    family: family,
    accountId: accountId,
    codec: codec,
  );

  /// 从仓储拉取最新数据并执行搜索。
  Future<List<AddressSearchResult>> call({
    String query = '',
    ChainFamily? family,
    String? accountId,
  }) async {
    final accts = await accounts.watchAll().first;
    final addrs = await addresses.all();
    final accountsById = <String, Account>{for (final a in accts) a.id: a};
    return executeSearchAddresses(
      addresses: addrs,
      accountsById: accountsById,
      query: query,
      family: family,
      accountId: accountId,
      codec: codec,
    );
  }
}

/// 对内存中的数据进行过滤与搜索（同步纯函数逻辑，无 IO）。
List<AddressSearchResult> executeSearchAddresses({
  required List<WatchAddress> addresses,
  required Map<String, Account> accountsById,
  String query = '',
  ChainFamily? family,
  String? accountId,
  AddressCodec codec = const AddressCodec(),
}) {
  final q = query.trim();
  final qLower = q.toLowerCase();

  if (q.isEmpty) {
    final results = <AddressSearchResult>[];
    for (final addr in addresses) {
      if (family != null && addr.family != family) continue;
      if (accountId != null && addr.accountId != accountId) continue;
      final account = accountsById[addr.accountId];
      if (account == null) continue;
      results.add(AddressSearchResult(address: addr, account: account));
    }
    return results;
  }

  final exactMatches = <AddressSearchResult>[];
  final otherMatches = <AddressSearchResult>[];

  for (final addr in addresses) {
    if (family != null && addr.family != family) continue;
    if (accountId != null && addr.accountId != accountId) continue;
    final account = accountsById[addr.accountId];
    if (account == null) continue;

    // 1. 精确匹配：必须通过 AddressCodec.normalize 规范化后与库中存储的规范地址完全一致。
    // Base58 链（Solana、Tron、Bitcoin 1/3）大小写有意义；EVM 与全大写 Bech32 会规范化为小写。
    final isExact = AddressCodec.normalize(q, addr.family) == addr.address;
    if (isExact) {
      exactMatches.add(
        AddressSearchResult(
          address: addr,
          account: account,
          isExactMatch: true,
        ),
      );
      continue;
    }

    // 2. 片段模糊匹配（不区分大小写）
    final normalizedAddr = addr.address.toLowerCase();
    final displayAddr = codec.display(addr.address, addr.family).toLowerCase();
    final matchAddressSnippet =
        normalizedAddr.contains(qLower) || displayAddr.contains(qLower);
    final matchAccount = account.name.toLowerCase().contains(qLower);
    final matchNote = addr.note.toLowerCase().contains(qLower);

    if (matchAddressSnippet || matchAccount || matchNote) {
      otherMatches.add(
        AddressSearchResult(
          address: addr,
          account: account,
          isExactMatch: false,
        ),
      );
    }
  }

  // 稳定顺序：精确匹配放前面，其余匹配按原有顺序追加在后
  return [...exactMatches, ...otherMatches];
}
