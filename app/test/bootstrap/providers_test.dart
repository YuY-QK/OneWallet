import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/bootstrap/providers.dart';
import 'package:ow_data/ow_data.dart';
import 'package:ow_domain/ow_domain.dart';

import 'support.dart';

void main() {
  late OwDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = OwDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secretStoreProvider.overrideWithValue(FakeSecretStore()),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('逐个读取全部provider_都能构造出来且不抛异常', () async {
    final providers = <ProviderListenable<Object?>>[
      secretStoreProvider,
      platformCapabilitiesProvider,
      loggerProvider,
      clockProvider,
      idGeneratorProvider,
      databaseProvider,
      repositoriesProvider,
      accountRepositoryProvider,
      addressRepositoryProvider,
      holdingRepositoryProvider,
      priceRepositoryProvider,
      snapshotRepositoryProvider,
      syncRecordRepositoryProvider,
      vaultMetaRepositoryProvider,
      settingsRepositoryProvider,
      tokenVisibilityRepositoryProvider,
      dataSourceConfigProvider,
      netLogSinkProvider,
      addressChecksumProvider,
      addressCodecProvider,
      builtInAssetCatalogProvider,
      assetCatalogProvider,
      priceSourceProvider,
      adapterRegistryProvider,
      retryPolicyProvider,
      holdingNormalizerProvider,
      syncAccountProvider,
      syncAllAccountsProvider,
      addWalletAccountProvider,
      addAddressesToAccountProvider,
      watchPortfolioProvider,
      themeModeProvider,
    ];
    for (final p in providers) {
      expect(() => container.read(p), returnsNormally, reason: '$p');
    }

    // 两个流 provider：Riverpod 3 对无监听者的 provider 会暂停，先挂上监听再等第一个值。
    container
      ..listen(settingsProvider, (_, _) {})
      ..listen(portfolioSummaryProvider, (_, _) {});
    final settings = await container.read(settingsProvider.future);
    expect(settings, const AppSettings());
    final summary = await container.read(portfolioSummaryProvider.future);
    expect(summary.total.toString(), '0');
  });

  test('用例是单例_同一个容器里多次读取得到同一个对象', () {
    expect(
      container.read(syncAccountProvider),
      same(container.read(syncAccountProvider)),
    );
    expect(
      container.read(syncAllAccountsProvider),
      same(container.read(syncAllAccountsProvider)),
    );
  });

  test('id生成器_UUID v4_且每次不同', () {
    final ids = container.read(idGeneratorProvider);
    final a = ids.newId();
    final b = ids.newId();
    expect(a, matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(a, isNot(b));
  });

  test('时钟_返回UTC', () {
    expect(container.read(clockProvider).nowUtc().isUtc, isTrue);
  });

  test('主题模式_跟随设置', () async {
    expect(container.read(themeModeProvider), ThemePreference.system);
    container.listen(themeModeProvider, (_, _) {});
    await container
        .read(settingsRepositoryProvider)
        .update((s) => s.copyWith(theme: ThemePreference.dark));
    // 等设置流推送。
    await container.read(settingsProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(container.read(themeModeProvider), ThemePreference.dark);
  });

  test('未提供数据库_读取仓储抛出未实现错误', () {
    final bare = ProviderContainer();
    addTearDown(bare.dispose);
    expect(() => bare.read(accountRepositoryProvider), throwsA(anything));
  });
}
