import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';

import 'adapter_providers.dart';
import 'foundation_providers.dart';

// 用例与读模型的 provider。页面通过控制器使用它们，不直接调用仓储或适配器。

final retryPolicyProvider = Provider<RetryPolicy>((ref) => const RetryPolicy());

final holdingNormalizerProvider = Provider<HoldingNormalizer>(
  (ref) => HoldingNormalizer(
    catalog: ref.watch(assetCatalogProvider),
    priceSource: ref.watch(priceSourceProvider),
  ),
);

/// 同步单个账户。持有"同账户去重"的在途状态，所以全应用共用一个实例。
final syncAccountProvider = Provider<SyncAccount>(
  (ref) => SyncAccount(
    accounts: ref.watch(accountRepositoryProvider),
    addresses: ref.watch(addressRepositoryProvider),
    holdings: ref.watch(holdingRepositoryProvider),
    syncRecords: ref.watch(syncRecordRepositoryProvider),
    adapters: ref.watch(adapterRegistryProvider),
    normalizer: ref.watch(holdingNormalizerProvider),
    retryPolicy: ref.watch(retryPolicyProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// 同步全部账户并刷新价格。全应用共用一个实例（"同时只跑一轮"）。
final syncAllAccountsProvider = Provider<SyncAllAccounts>(
  (ref) => SyncAllAccounts(
    accounts: ref.watch(accountRepositoryProvider),
    holdings: ref.watch(holdingRepositoryProvider),
    syncRecords: ref.watch(syncRecordRepositoryProvider),
    settings: ref.watch(settingsRepositoryProvider),
    prices: ref.watch(priceRepositoryProvider),
    priceSource: ref.watch(priceSourceProvider),
    catalog: ref.watch(assetCatalogProvider),
    syncAccount: ref.watch(syncAccountProvider),
    retryPolicy: ref.watch(retryPolicyProvider),
    clock: ref.watch(clockProvider),
  ),
);

final addWalletAccountProvider = Provider<AddWalletAccount>(
  (ref) => AddWalletAccount(
    accounts: ref.watch(accountRepositoryProvider),
    addresses: ref.watch(addressRepositoryProvider),
    codec: ref.watch(addressCodecProvider),
    ids: ref.watch(idGeneratorProvider),
    clock: ref.watch(clockProvider),
  ),
);

final addAddressesToAccountProvider = Provider<AddAddressesToAccount>(
  (ref) => AddAddressesToAccount(
    accounts: ref.watch(accountRepositoryProvider),
    addresses: ref.watch(addressRepositoryProvider),
    codec: ref.watch(addressCodecProvider),
    ids: ref.watch(idGeneratorProvider),
  ),
);

final watchPortfolioProvider = Provider<WatchPortfolio>(
  (ref) => WatchPortfolio(
    accounts: ref.watch(accountRepositoryProvider),
    holdings: ref.watch(holdingRepositoryProvider),
    prices: ref.watch(priceRepositoryProvider),
    settings: ref.watch(settingsRepositoryProvider),
    tokenVisibility: ref.watch(tokenVisibilityRepositoryProvider),
  ),
);

/// 总览汇总，随账户、持仓、价格、设置、代币显示状态的变化推送。
final portfolioSummaryProvider = StreamProvider<PortfolioSummary>(
  (ref) => ref.watch(watchPortfolioProvider)(),
);

/// 应用设置，随修改推送；从未保存过时推送默认值。
final settingsProvider = StreamProvider<AppSettings>(
  (ref) => ref.watch(settingsRepositoryProvider).watch(),
);

/// 主题模式：跟随 [AppSettings.theme]。设置未就绪（加载中、出错）时跟随系统。
final themeModeProvider = Provider<ThemePreference>(
  (ref) => switch (ref.watch(settingsProvider)) {
    AsyncData(:final value) => value.theme,
    _ => ThemePreference.system,
  },
);
