import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ow_domain/ow_domain.dart';

import 'foundation_providers.dart';
import 'usecase_providers.dart';

// 页面共用的读模型 provider：把仓储的变化流交给界面，页面不直接碰仓储。

/// 全部账户。
final accountsProvider = StreamProvider<List<Account>>(
  (ref) => ref.watch(accountRepositoryProvider).watchAll(),
);

/// 全部观察地址。
final addressesProvider = StreamProvider<List<WatchAddress>>(
  (ref) => ref.watch(addressRepositoryProvider).watchAll(),
);

/// 全部持仓。
final holdingsProvider = StreamProvider<List<Holding>>(
  (ref) => ref.watch(holdingRepositoryProvider).watchAll(),
);

/// 每个账户最近一条同步记录。
final latestSyncRecordsProvider = StreamProvider<List<SyncRecord>>(
  (ref) => ref.watch(syncRecordRepositoryProvider).watchLatestPerAccount(),
);

/// 每个账户最近一次成功同步的时间（账户 id → 时间）。
final lastSuccessPerAccountProvider = StreamProvider<Map<String, DateTime>>(
  (ref) => ref.watch(syncRecordRepositoryProvider).watchLastSuccessPerAccount(),
);

/// 正在同步的账户 id 集合。
final syncingAccountIdsProvider = StreamProvider<Set<String>>(
  (ref) => ref.watch(syncAccountProvider).watchSyncingAccountIds(),
);

/// 当前计价货币；设置未就绪时为 USD。
final quoteProvider = Provider<Quote>(
  (ref) =>
      ref.watch(settingsProvider.select((s) => s.value?.quote)) ?? Quote.usd,
);

/// "隐藏金额"开关；设置未就绪时为关。
final hideAmountsProvider = Provider<bool>(
  (ref) =>
      ref.watch(settingsProvider.select((s) => s.value?.hideAmounts)) ?? false,
);

/// 当前计价货币下的价格，按标准币种 id 索引。
final quotePricesProvider = StreamProvider<Map<String, Price>>((ref) {
  final quote = ref.watch(quoteProvider);
  return ref.watch(priceRepositoryProvider).watch(quote);
});
