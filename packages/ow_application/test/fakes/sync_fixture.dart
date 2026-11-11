import 'package:decimal/decimal.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';

import 'fake_adapters.dart';
import 'fake_repositories.dart';
import 'fake_services.dart';

const usdt = Asset(
  id: 'USDT',
  symbol: 'USDT',
  name: 'Tether',
  priceId: 'tether',
);
const eth = Asset(
  id: 'ETH',
  symbol: 'ETH',
  name: 'Ethereum',
  priceId: 'ethereum',
);

/// 同步用例测试的装配：全部依赖都是内存假实现。
final class SyncFixture {
  SyncFixture({int maxConcurrency = 4, FullSyncCompletedHook? onCompleted}) {
    catalog.register(const NativeToken('ethereum'), eth);
    syncAccount = SyncAccount(
      accounts: accounts,
      addresses: addresses,
      holdings: holdings,
      syncRecords: syncRecords,
      adapters: adapters,
      normalizer: HoldingNormalizer(catalog: catalog, priceSource: priceSource),
      retryPolicy: retryPolicy,
      clock: clock,
    );
    syncAll = SyncAllAccounts(
      accounts: accounts,
      holdings: holdings,
      syncRecords: syncRecords,
      settings: settings,
      prices: prices,
      priceSource: priceSource,
      catalog: catalog,
      syncAccount: syncAccount,
      retryPolicy: retryPolicy,
      clock: clock,
      maxConcurrency: maxConcurrency,
      onFullSyncCompleted: onCompleted,
    );
  }

  final accounts = InMemoryAccountRepository();
  final addresses = InMemoryAddressRepository();
  final holdings = InMemoryHoldingRepository();
  final syncRecords = InMemorySyncRecordRepository();
  final settings = InMemorySettingsRepository();
  final prices = InMemoryPriceRepository();
  final adapters = FakeAdapterRegistry();
  final catalog = FakeAssetCatalog();
  final priceSource = FakePriceSource();
  final clock = FakeClock();
  final delay = RecordingDelay();
  late final retryPolicy = RetryPolicy(delay: delay.call);
  late final SyncAccount syncAccount;
  late final SyncAllAccounts syncAll;

  /// 建一个钱包账户，地址 [address] 启用 [chainIds]，返回账户 id。
  Future<String> addWallet(
    String id,
    String address, {
    Set<String> chainIds = const {'ethereum'},
  }) async {
    await accounts.upsert(
      Account(
        id: id,
        type: AccountType.wallet,
        name: '钱包 $id',
        colorIndex: 0,
        createdAt: clock.nowUtc(),
      ),
    );
    await addresses.upsert(
      WatchAddress(
        id: 'addr-$id-${address.substring(2, 6)}',
        accountId: id,
        family: ChainFamily.evm,
        address: address,
        enabledChainIds: chainIds,
      ),
    );
    return id;
  }

  /// 在 [address] 的 [chainId] 上预设一次返回 [amount] ETH 的成功结果。
  void ethBalance(String address, String chainId, String amount) {
    adapters.evm.respond(address, chainId, [
      Ok([
        RawHolding(token: NativeToken(chainId), amount: Decimal.parse(amount)),
      ]),
    ]);
  }

  /// 预先写入一笔旧持仓。
  Future<Holding> seedOldHolding(String accountId) async {
    final old = Holding(
      accountId: accountId,
      location: const OnChainLocation(chainId: 'ethereum', addressId: 'old'),
      token: const NativeToken('ethereum'),
      assetId: 'ETH',
      displaySymbol: 'ETH',
      amount: Decimal.parse('9'),
      updatedAt: DateTime.utc(2026),
    );
    await holdings.replaceForAccount(accountId, [old]);
    holdings.replaceCalls.clear();
    return old;
  }
}
