import 'database/ow_database.dart';
import 'repositories/account_repositories.dart';
import 'repositories/asset_repositories.dart';
import 'repositories/market_repositories.dart';
import 'repositories/misc_repositories.dart';

/// 把基于同一个 [OwDatabase] 的全部仓储装配在一起，供 app 的依赖装配使用。
///
/// `CredentialRepository` 基于 SecretStore，不在这里。
final class OwRepositories {
  OwRepositories(OwDatabase db)
    : accounts = DriftAccountRepository(db),
      addresses = DriftAddressRepository(db),
      holdings = DriftHoldingRepository(db),
      prices = DriftPriceRepository(db),
      snapshots = DriftSnapshotRepository(db),
      syncRecords = DriftSyncRecordRepository(db),
      vaultMeta = DriftVaultMetaRepository(db),
      settings = DriftSettingsRepository(db),
      tokenVisibility = DriftTokenVisibilityRepository(db),
      assets = DriftAssetRepository(db);

  final DriftAccountRepository accounts;
  final DriftAddressRepository addresses;
  final DriftHoldingRepository holdings;
  final DriftPriceRepository prices;
  final DriftSnapshotRepository snapshots;
  final DriftSyncRecordRepository syncRecords;
  final DriftVaultMetaRepository vaultMeta;
  final DriftSettingsRepository settings;
  final DriftTokenVisibilityRepository tokenVisibility;
  final DriftAssetRepository assets;
}
