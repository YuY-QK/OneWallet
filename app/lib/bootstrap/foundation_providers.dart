import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ow_data/ow_data.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:ow_platform/ow_platform.dart';

import 'base_services.dart';
import 'logger.dart';

// 平台、基础服务与数据层的 provider。全部可在测试中 override。

/// 系统安全存储。默认是设备上的真实实现；测试换成内存假实现。
final secretStoreProvider = Provider<ClearableSecretStore>(
  (ref) => SecureSecretStore(),
);

/// 平台能力。界面只读它，不判断平台名称。
final platformCapabilitiesProvider = Provider<PlatformCapabilities>(
  (ref) => DevicePlatformCapabilities(),
);

final loggerProvider = Provider<OwLogger>((ref) => OwLogger());

final clockProvider = Provider<Clock>((ref) => const SystemClock());

final idGeneratorProvider = Provider<IdGenerator>((ref) => UuidIdGenerator());

/// 主数据库。必须在启动流程中 override；未 override 时读取会抛出
/// [UnimplementedError]（属于程序缺陷）。
final databaseProvider = Provider<OwDatabase>(
  (ref) => throw UnimplementedError('databaseProvider 必须由启动流程提供'),
);

final repositoriesProvider = Provider<OwRepositories>(
  (ref) => OwRepositories(ref.watch(databaseProvider)),
);

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => ref.watch(repositoriesProvider).accounts,
);

final addressRepositoryProvider = Provider<AddressRepository>(
  (ref) => ref.watch(repositoriesProvider).addresses,
);

final holdingRepositoryProvider = Provider<HoldingRepository>(
  (ref) => ref.watch(repositoriesProvider).holdings,
);

final priceRepositoryProvider = Provider<PriceRepository>(
  (ref) => ref.watch(repositoriesProvider).prices,
);

final snapshotRepositoryProvider = Provider<SnapshotRepository>(
  (ref) => ref.watch(repositoriesProvider).snapshots,
);

final syncRecordRepositoryProvider = Provider<SyncRecordRepository>(
  (ref) => ref.watch(repositoriesProvider).syncRecords,
);

final vaultMetaRepositoryProvider = Provider<VaultMetaRepository>(
  (ref) => ref.watch(repositoriesProvider).vaultMeta,
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => ref.watch(repositoriesProvider).settings,
);

final tokenVisibilityRepositoryProvider = Provider<TokenVisibilityRepository>(
  (ref) => ref.watch(repositoriesProvider).tokenVisibility,
);

final assetRepositoryProvider = Provider<AssetRepository>(
  (ref) => ref.watch(repositoriesProvider).assets,
);
