import 'package:ow_domain/ow_domain.dart';

import '../util/stream_combine.dart';

/// 密钥条目摘要（规格 4.9 节）。
final class VaultItemSummary {
  const VaultItemSummary({
    required this.meta,
    required this.linkedAccountIds,
    required this.linkedAccountNames,
  });

  final VaultItemMeta meta;
  final List<String> linkedAccountIds;
  final List<String> linkedAccountNames;

  @override
  bool operator ==(Object other) =>
      other is VaultItemSummary &&
      other.meta == meta &&
      _listEquals(other.linkedAccountIds, linkedAccountIds) &&
      _listEquals(other.linkedAccountNames, linkedAccountNames);

  @override
  int get hashCode => Object.hash(
    meta,
    Object.hashAll(linkedAccountIds),
    Object.hashAll(linkedAccountNames),
  );

  @override
  String toString() =>
      'VaultItemSummary(${meta.id}, name: ${meta.name}, linked: ${linkedAccountIds.length})';
}

bool _listEquals<E>(List<E> a, List<E> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// 监听密钥条目列表（规格 4.9 节）。
///
/// 组合元数据与账户信息，按创建时间升序排列，不触发解锁。
final class WatchVaultItems {
  WatchVaultItems({required this.vaultMetaRepo, required this.accountRepo});

  final VaultMetaRepository vaultMetaRepo;
  final AccountRepository accountRepo;

  Stream<List<VaultItemSummary>> call() {
    return combineLatest2(vaultMetaRepo.watchAll(), accountRepo.watchAll(), (
      metas,
      accounts,
    ) {
      final sortedMetas = [...metas]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      return [
        for (final meta in sortedMetas)
          VaultItemSummary(
            meta: meta,
            linkedAccountIds: [
              for (final a in accounts)
                if (a.vaultItemId == meta.id) a.id,
            ],
            linkedAccountNames: [
              for (final a in accounts)
                if (a.vaultItemId == meta.id) a.name,
            ],
          ),
      ];
    });
  }
}
