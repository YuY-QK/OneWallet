import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';

import 'adapter_providers.dart';
import 'foundation_providers.dart';
import 'vault_providers.dart';

// 用例与读模型的 provider。页面通过控制器使用它们，不直接调用仓储或适配器。

final retryPolicyProvider = Provider<RetryPolicy>((ref) => const RetryPolicy());

final holdingNormalizerProvider = Provider<HoldingNormalizer>(
  (ref) => HoldingNormalizer(
    catalog: ref.watch(assetCatalogProvider),
    priceSource: ref.watch(priceSourceProvider),
    recorder: ref.watch(assetCatalogProvider),
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
    credentials: ref.watch(credentialRepositoryProvider),
  ),
);

/// 记录每日净值快照（全量同步结束后自动触发，也可手动触发）。
final recordDailySnapshotProvider = Provider<RecordDailySnapshot>(
  (ref) => RecordDailySnapshot(
    accounts: ref.watch(accountRepositoryProvider),
    holdings: ref.watch(holdingRepositoryProvider),
    prices: ref.watch(priceRepositoryProvider),
    snapshots: ref.watch(snapshotRepositoryProvider),
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
    onFullSyncCompleted: (result) =>
        ref.read(recordDailySnapshotProvider)(result),
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

final deleteAddressProvider = Provider<DeleteAddress>(
  (ref) => DeleteAddress(addresses: ref.watch(addressRepositoryProvider)),
);

final addExchangeAccountProvider = Provider<AddExchangeAccount>(
  (ref) => AddExchangeAccount(
    accounts: ref.watch(accountRepositoryProvider),
    credentials: ref.watch(credentialRepositoryProvider),
    adapters: ref.watch(adapterRegistryProvider),
    ids: ref.watch(idGeneratorProvider),
    clock: ref.watch(clockProvider),
  ),
);

final replaceExchangeCredentialsProvider = Provider<ReplaceExchangeCredentials>(
  (ref) => ReplaceExchangeCredentials(
    accounts: ref.watch(accountRepositoryProvider),
    credentials: ref.watch(credentialRepositoryProvider),
    adapters: ref.watch(adapterRegistryProvider),
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

final renameAccountProvider = Provider<RenameAccount>(
  (ref) => RenameAccount(accounts: ref.watch(accountRepositoryProvider)),
);

final deleteAccountProvider = Provider<DeleteAccount>(
  (ref) => DeleteAccount(
    accounts: ref.watch(accountRepositoryProvider),
    credentials: ref.watch(credentialRepositoryProvider),
  ),
);

final searchAddressesProvider = Provider<SearchAddresses>(
  (ref) => SearchAddresses(
    accounts: ref.watch(accountRepositoryProvider),
    addresses: ref.watch(addressRepositoryProvider),
    codec: ref.watch(addressCodecProvider),
  ),
);

final updateAddressNoteProvider = Provider<UpdateAddressNote>(
  (ref) => UpdateAddressNote(addresses: ref.watch(addressRepositoryProvider)),
);

final updateBackupStatusProvider = Provider<UpdateBackupStatus>(
  (ref) => UpdateBackupStatus(accounts: ref.watch(accountRepositoryProvider)),
);

final watchBackupChecklistProvider = Provider<WatchBackupChecklist>(
  (ref) => WatchBackupChecklist(
    accounts: ref.watch(accountRepositoryProvider),
    holdings: ref.watch(holdingRepositoryProvider),
    prices: ref.watch(priceRepositoryProvider),
    settings: ref.watch(settingsRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);

final backupChecklistProvider = StreamProvider.autoDispose<BackupChecklistData>(
  (ref) => ref.watch(watchBackupChecklistProvider)(),
);

final wipeAllDataProvider = Provider<WipeAllData>(
  (ref) => WipeAllData(
    closer: ref.watch(databaseProvider),
    databaseDeleter: ref.watch(databaseOpenerProvider),
    vaultStorage: ref.watch(vaultStorageProvider),
    secrets: ref.watch(secretStoreProvider),
    hardwareKeyStore: ref.watch(hardwareKeyStoreProvider),
  ),
);

/// 全局清除全部数据并重新执行启动流程（回到初始引导状态）。
/// 在进入应用后由 [BootstrapHost] 提供真实实现。
final wipeAndRestartProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    final wipeAll = ref.read(wipeAllDataProvider);
    await wipeAll();
  },
);
