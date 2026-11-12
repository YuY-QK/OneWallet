import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ow_chains/ow_chains.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:ow_net/ow_net.dart';
import 'package:ow_pricing/ow_pricing.dart';

import 'data_source_config.dart';
import 'foundation_providers.dart';
import 'unsupported_adapters.dart';

// 数据源配置与适配器的 provider。

/// 数据源配置（API Key、自定义端点），存于 [SecretStore]。
/// 同一个对象也提供写入方法，供 P20 页面使用。
final dataSourceConfigProvider = Provider<SecretStoreDataSourceConfig>(
  (ref) => SecretStoreDataSourceConfig(ref.watch(secretStoreProvider)),
);

/// 网络日志出口：仅调试构建启用，写入统一的 [OwLogger]。
/// 收到的每一行都已由 `ow_net` 脱敏，且不含请求体与响应体。
final netLogSinkProvider = Provider<OwLogSink?>((ref) {
  if (!kDebugMode) return null;
  final logger = ref.watch(loggerProvider);
  return (line) => logger.debug('net', line);
});

final addressChecksumProvider = Provider<AddressChecksum>(
  (ref) => const ChainAddressChecksum(),
);

final addressCodecProvider = Provider<AddressCodec>(
  (ref) => AddressCodec(checksum: ref.watch(addressChecksumProvider)),
);

/// 内置币种映射表。价格源需要它的具体类型（读取价格源标识与链平台映射）。
final builtInAssetCatalogProvider = Provider<BuiltInAssetCatalog>(
  (ref) => BuiltInAssetCatalog(),
);

/// 币种目录。M1-18 加入"已查到币种的持久化"后，这里换成"内置表加数据库"的组合实现。
final assetCatalogProvider = Provider<AssetCatalog>(
  (ref) => ref.watch(builtInAssetCatalogProvider),
);

final priceSourceProvider = Provider<PriceSource>(
  (ref) => CoinGeckoPriceSource(
    config: ref.watch(dataSourceConfigProvider),
    clock: ref.watch(clockProvider),
    catalog: ref.watch(builtInAssetCatalogProvider),
    onLog: ref.watch(netLogSinkProvider),
  ),
);

/// 适配器注册表。EVM 已实现，其余家族与全部交易所是占位（返回
/// [UnsupportedFailure]）。TODO(M2-01..03)、TODO(M2-06..09)：随适配器完成替换。
final adapterRegistryProvider = Provider<AdapterRegistry>(
  (ref) => AppAdapterRegistry(
    evm: EvmChainAdapter(
      config: ref.watch(dataSourceConfigProvider),
      onLog: ref.watch(netLogSinkProvider),
    ),
  ),
);
