import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ow_chains/ow_chains.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:ow_pricing/ow_pricing.dart';

import '../../../bootstrap/providers.dart';

/// 数据服务商的标识（与 `SecretStore` 键名中的 `<providerId>` 一致）。
abstract final class DataSourceIds {
  static const alchemy = EvmChainAdapter.providerId;
  static const mempool = 'mempool';
  static const helius = SolanaChainAdapter.providerId;
  static const trongrid = TronChainAdapter.providerId;
  static const coingecko = CoinGeckoPriceSource.providerId;
}

/// 一个服务商的配置状态。**不含 Key 本身**：只记录是否已配置，
/// 以及（Key 足够长时）前 4 位加 `***` 的提示。
@immutable
final class DataSourceStatus {
  const DataSourceStatus({required this.configured, this.preview});

  final bool configured;

  /// 如 `abcd***`；未配置或 Key 太短时为 null。
  final String? preview;
}

/// 测试连接的结果。
sealed class TestOutcome {
  const TestOutcome();
}

final class TestPassed extends TestOutcome {
  const TestPassed();
}

final class TestFailed extends TestOutcome {
  const TestFailed(this.failure);

  final Failure failure;
}

/// P20 的状态。
@immutable
final class DataSourcesState {
  const DataSourcesState({
    required this.statuses,
    required this.endpointHosts,
    this.testing = const {},
    this.outcomes = const {},
  });

  /// 按服务商标识。
  final Map<String, DataSourceStatus> statuses;

  /// 已设置自定义端点的链及其域名（只保留域名，不保留完整地址）。
  final Map<String, String> endpointHosts;

  /// 正在测试连接的服务商。
  final Set<String> testing;

  /// 各服务商最近一次测试结果。
  final Map<String, TestOutcome> outcomes;

  DataSourceStatus statusOf(String providerId) =>
      statuses[providerId] ?? const DataSourceStatus(configured: false);

  DataSourcesState copyWith({
    Map<String, DataSourceStatus>? statuses,
    Map<String, String>? endpointHosts,
    Set<String>? testing,
    Map<String, TestOutcome>? outcomes,
  }) => DataSourcesState(
    statuses: statuses ?? this.statuses,
    endpointHosts: endpointHosts ?? this.endpointHosts,
    testing: testing ?? this.testing,
    outcomes: outcomes ?? this.outcomes,
  );
}

/// 以太坊零地址：众所周知的公开地址，测试连接时用它查询。
const String zeroAddress = '0x0000000000000000000000000000000000000000';

/// 比特币创世区块地址：众所周知的公开地址。
const String btcGenesisAddress = '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa';

/// Solana 系统程序地址：众所周知的公开地址。
const String solSystemProgram = '11111111111111111111111111111111';

/// Tron 黑洞地址：众所周知的公开地址。
const String tronZeroAddress = 'T9yD14Nj9j7xAB4dbGeiX9h8unkKHxuWwb';

/// Key 的提示至少需要这么长才显示前 4 位，避免短 Key 暴露过半。
const int _previewMinLength = 12;

/// P20 数据源设置的控制器。Key 只经过方法参数写入 `SecretStore`，
/// 不进入状态、日志与错误信息。
final dataSourcesProvider =
    AsyncNotifierProvider<DataSourcesController, DataSourcesState>(
      DataSourcesController.new,
    );

class DataSourcesController extends AsyncNotifier<DataSourcesState> {
  static const _providers = [
    DataSourceIds.alchemy,
    DataSourceIds.mempool,
    DataSourceIds.helius,
    DataSourceIds.trongrid,
    DataSourceIds.coingecko,
  ];

  @override
  Future<DataSourcesState> build() async {
    final loaded = await _load();
    return DataSourcesState(statuses: loaded.$1, endpointHosts: loaded.$2);
  }

  Future<(Map<String, DataSourceStatus>, Map<String, String>)> _load() async {
    final config = ref.read(dataSourceConfigProvider);
    final hosts = <String, String>{};
    for (final chain in Chains.all) {
      final uri = await config.customEndpoint(chain.id);
      if (uri != null) hosts[chain.id] = uri.host;
    }
    final statuses = <String, DataSourceStatus>{};
    for (final id in _providers) {
      if (id == DataSourceIds.mempool) {
        statuses[id] = const DataSourceStatus(configured: true);
        continue;
      }
      final key = await config.apiKey(id);
      statuses[id] = DataSourceStatus(
        configured: key != null,
        preview: (key != null && key.length >= _previewMinLength)
            ? '${key.substring(0, 4)}***'
            : null,
      );
    }
    return (statuses, hosts);
  }

  Future<void> _reload() async {
    final loaded = await _load();
    if (!ref.mounted) return;
    final current = state.value;
    state = AsyncData(
      DataSourcesState(
        statuses: loaded.$1,
        endpointHosts: loaded.$2,
        testing: current?.testing ?? const {},
        outcomes: current?.outcomes ?? const {},
      ),
    );
  }

  /// 保存 [providerId] 的 Key。空白返回 [ValidationFailure]，不写入。
  Future<Result<void>> saveKey(String providerId, String apiKey) async {
    final result = await ref
        .read(dataSourceConfigProvider)
        .setApiKey(providerId, apiKey);
    if (result.isOk) await _reload();
    return result;
  }

  /// 清除 [providerId] 的 Key。
  Future<void> clearKey(String providerId) async {
    await ref.read(dataSourceConfigProvider).clearApiKey(providerId);
    await _reload();
  }

  /// 保存 [chainId] 的自定义端点；只接受 https。
  Future<Result<void>> saveEndpoint(String chainId, String endpoint) async {
    final result = await ref
        .read(dataSourceConfigProvider)
        .setCustomEndpoint(chainId, endpoint);
    if (result.isOk) await _reload();
    return result;
  }

  /// 恢复 [chainId] 的默认端点。
  Future<void> clearEndpoint(String chainId) async {
    await ref.read(dataSourceConfigProvider).clearCustomEndpoint(chainId);
    await _reload();
  }

  /// 用已保存的配置测试连接。Alchemy：以太坊零地址调用 EVM 适配器的
  /// `hasActivity`；CoinGecko：查一次 BTC 价格。
  Future<void> testConnection(String providerId) async {
    _update((s) => s.copyWith(testing: {...s.testing, providerId}));
    final outcome = await _run(providerId);
    if (!ref.mounted) return;
    _update(
      (s) => s.copyWith(
        testing: {...s.testing}..remove(providerId),
        outcomes: {...s.outcomes, providerId: outcome},
      ),
    );
  }

  Future<TestOutcome> _run(String providerId) async {
    final Result<Object?> result;
    switch (providerId) {
      case DataSourceIds.alchemy:
        result = await ref
            .read(adapterRegistryProvider)
            .chain(ChainFamily.evm)
            .hasActivity(zeroAddress, Chains.byId('ethereum'));
      case DataSourceIds.mempool:
        result = await ref
            .read(adapterRegistryProvider)
            .chain(ChainFamily.bitcoin)
            .hasActivity(btcGenesisAddress, Chains.byId('bitcoin'));
      case DataSourceIds.helius:
        result = await ref
            .read(adapterRegistryProvider)
            .chain(ChainFamily.solana)
            .hasActivity(solSystemProgram, Chains.byId('solana'));
      case DataSourceIds.trongrid:
        result = await ref
            .read(adapterRegistryProvider)
            .chain(ChainFamily.tron)
            .hasActivity(tronZeroAddress, Chains.byId('tron'));
      case DataSourceIds.coingecko:
        final btc = ref.read(assetCatalogProvider).byId('BTC');
        if (btc == null) return const TestFailed(UnknownFailure('BTC 币种缺失'));
        final prices = await ref.read(priceSourceProvider).fetchPrices({
          btc,
        }, Quote.usd);
        result = switch (prices) {
          Ok(:final value) when value.isEmpty => const Err(
            UnknownFailure('没有返回 BTC 价格'),
          ),
          _ => prices,
        };
      default:
        return const TestFailed(UnsupportedFailure());
    }
    return switch (result) {
      Ok() => const TestPassed(),
      Err(:final failure) => TestFailed(failure),
    };
  }

  void _update(DataSourcesState Function(DataSourcesState) change) {
    final current = state.value;
    if (current != null) state = AsyncData(change(current));
  }
}
