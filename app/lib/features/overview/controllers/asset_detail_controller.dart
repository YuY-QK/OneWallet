import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/providers.dart';
import 'asset_detail_view.dart';

/// P09 币种详情的视图模型 Provider。
final assetDetailViewProvider = Provider.autoDispose
    .family<AsyncValue<AssetDetailView>, String>((ref, assetId) {
      final accountsAsync = ref.watch(accountsProvider);
      final holdingsAsync = ref.watch(holdingsProvider);
      final pricesAsync = ref.watch(quotePricesProvider);
      final hiddenTokensAsync = ref.watch(hiddenTokensProvider);

      for (final v in <AsyncValue<Object?>>[
        accountsAsync,
        holdingsAsync,
        pricesAsync,
      ]) {
        if (v case AsyncError(:final error, :final stackTrace)) {
          return AsyncError(error, stackTrace);
        }
      }

      final accounts = accountsAsync.value;
      final holdings = holdingsAsync.value;
      final prices = pricesAsync.value;
      final hiddenTokens = hiddenTokensAsync.value ?? const <String>{};

      if (accounts == null || holdings == null || prices == null) {
        return const AsyncLoading();
      }

      final catalog = ref.watch(assetCatalogProvider);
      final builtIn = ref.watch(builtInAssetCatalogProvider);

      return AsyncData(
        buildAssetDetail(
          assetId: assetId,
          catalog: catalog,
          accounts: accounts,
          holdings: holdings,
          prices: prices,
          hiddenTokens: hiddenTokens,
          builtInContracts: builtIn.contracts,
        ),
      );
    });
