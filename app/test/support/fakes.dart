import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:onewallet/bootstrap/providers.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';

import '../bootstrap/support.dart';

/// 带当前值的广播流：新订阅者先收到当前值，之后收到每次变化。
final class ValueFeed<T> {
  ValueFeed(this._value);

  T _value;
  final _controller = StreamController<T>.broadcast(sync: true);

  T get value => _value;

  set value(T v) {
    _value = v;
    _controller.add(v);
  }

  Stream<T> stream() {
    late StreamController<T> c;
    StreamSubscription<T>? sub;
    c = StreamController<T>(
      onListen: () {
        c.add(_value);
        sub = _controller.stream.listen(c.add);
      },
      onCancel: () {
        unawaited(sub?.cancel());
        return Future<void>.value();
      },
    );
    return c.stream;
  }
}

final class FakeAccountRepository implements AccountRepository {
  FakeAccountRepository(this.addressRepo);

  /// 与之共用存储的地址仓储，`insertWithAddresses` 写入地址用。
  final FakeAddressRepository addressRepo;
  final feed = ValueFeed<List<Account>>([]);

  @override
  Stream<List<Account>> watchAll() => feed.stream();

  @override
  Future<Account?> byId(String id) async {
    for (final a in feed.value) {
      if (a.id == id) return a;
    }
    return null;
  }

  @override
  Future<void> upsert(Account account) async {
    feed.value = [
      for (final a in feed.value)
        if (a.id != account.id) a,
      account,
    ];
  }

  @override
  Future<void> insertWithAddresses(
    Account account,
    List<WatchAddress> addresses,
  ) async {
    await upsert(account);
    for (final a in addresses) {
      await addressRepo.upsert(a);
    }
  }

  @override
  Future<void> delete(String id) async {
    feed.value = [
      for (final a in feed.value)
        if (a.id != id) a,
    ];
  }
}

final class FakeAddressRepository implements AddressRepository {
  final feed = ValueFeed<List<WatchAddress>>([]);

  /// 设置后，`upsert` 要等它完成才写入（用于停在"保存中"状态）。
  Completer<void>? upsertGate;

  @override
  Stream<List<WatchAddress>> watchAll() => feed.stream();

  @override
  Future<List<WatchAddress>> byAccount(String accountId) async => [
    for (final a in feed.value)
      if (a.accountId == accountId) a,
  ];

  @override
  Future<WatchAddress?> find(
    ChainFamily family,
    String normalizedAddress,
  ) async {
    for (final a in feed.value) {
      if (a.family == family && a.address == normalizedAddress) return a;
    }
    return null;
  }

  @override
  Future<void> upsert(WatchAddress address) async {
    await upsertGate?.future;
    feed.value = [
      for (final a in feed.value)
        if (a.id != address.id) a,
      address,
    ];
  }

  @override
  Future<void> delete(String id) async {
    feed.value = [
      for (final a in feed.value)
        if (a.id != id) a,
    ];
  }
}

final class FakeHoldingRepository implements HoldingRepository {
  final feed = ValueFeed<List<Holding>>([]);

  @override
  Stream<List<Holding>> watchAll() => feed.stream();

  @override
  Future<void> replaceForAccount(
    String accountId,
    List<Holding> holdings,
  ) async {
    feed.value = [
      for (final h in feed.value)
        if (h.accountId != accountId) h,
      ...holdings,
    ];
  }
}

final class FakePriceRepository implements PriceRepository {
  final feed = ValueFeed<Map<String, Price>>({});

  @override
  Stream<Map<String, Price>> watch(Quote quote) => feed.stream();

  @override
  Future<void> upsertAll(List<Price> prices) async {
    feed.value = {...feed.value, for (final p in prices) p.assetId: p};
  }
}

final class FakeSyncRecordRepository implements SyncRecordRepository {
  final feed = ValueFeed<List<SyncRecord>>([]);

  @override
  Stream<List<SyncRecord>> watchLatestPerAccount() => feed.stream();

  @override
  Future<void> add(SyncRecord record) async {
    feed.value = [
      for (final r in feed.value)
        if (r.accountId != record.accountId) r,
      record,
    ];
  }
}

final class FakeSettingsRepository implements SettingsRepository {
  final feed = ValueFeed<AppSettings>(const AppSettings());

  @override
  Stream<AppSettings> watch() => feed.stream();

  @override
  Future<void> update(AppSettings Function(AppSettings) change) async {
    feed.value = change(feed.value);
  }
}

final class FakeTokenVisibilityRepository implements TokenVisibilityRepository {
  @override
  Future<Set<String>> hidden() async => {};

  @override
  Stream<Set<String>> watchHidden() => Stream.value(const {});

  @override
  Future<void> setHidden(String tokenKey, bool hidden) async {}
}

/// 脚本化的链适配器：按链家族返回预设结果，并记录调用次数。
final class FakeChainAdapter implements ChainAdapter {
  FakeChainAdapter(this.family);

  @override
  final ChainFamily family;

  /// 返回的持仓；[failure] 非空时改为返回失败。
  List<RawHolding> holdings = const [];
  Failure? failure;
  int fetchCount = 0;
  final fetched = <String>[];

  /// 非空时，只有这条链返回 [holdings]，其余链返回空。
  String? onlyChain;

  /// 设置后，`fetchHoldings` 要等它完成才返回（用于停在"同步中"）。
  Completer<void>? gate;

  @override
  Future<Result<List<RawHolding>>> fetchHoldings(
    String address,
    ChainInfo chain,
  ) async {
    fetchCount++;
    fetched.add(address);
    await gate?.future;
    final f = failure;
    if (f != null) return Err(f);
    return Ok(onlyChain == null || onlyChain == chain.id ? holdings : const []);
  }

  @override
  Future<Result<bool>> hasActivity(String address, ChainInfo chain) async {
    fetched.add(address);
    final f = failure;
    return f == null ? const Ok(true) : Err(f);
  }
}

final class FakeAdapterRegistry implements AdapterRegistry {
  final adapters = {for (final f in ChainFamily.values) f: FakeChainAdapter(f)};

  FakeChainAdapter operator [](ChainFamily f) => adapters[f]!;

  @override
  ChainAdapter chain(ChainFamily family) => adapters[family]!;

  @override
  ExchangeAdapter exchange(ExchangeId id) => throw UnimplementedError();
}

/// 对任何币种报固定价格的价格源；[failure] 非空时失败。
final class FakePriceSource implements PriceSource {
  Decimal price = Decimal.parse('2000');
  Failure? failure;
  int fetchCount = 0;
  final fetchedAssets = <String>[];

  @override
  Future<Result<List<Price>>> fetchPrices(
    Set<Asset> assets,
    Quote quote,
  ) async {
    fetchCount++;
    fetchedAssets.addAll(assets.map((a) => a.id));
    final f = failure;
    if (f != null) return Err(f);
    return Ok([
      for (final a in assets)
        Price(
          assetId: a.id,
          quote: quote,
          price: price,
          updatedAt: DateTime.utc(2026, 11, 12),
        ),
    ]);
  }

  @override
  Future<Result<Map<ContractToken, Asset>>> lookupContracts(
    Set<ContractToken> tokens,
  ) async => const Ok({});
}

final class FixedClock implements Clock {
  FixedClock(this.now);

  DateTime now;

  @override
  DateTime nowUtc() => now;
}

final class SequenceIds implements IdGenerator {
  int _n = 0;

  @override
  String newId() => 'id-${++_n}';
}

final class FakePlatformCapabilities implements PlatformCapabilities {
  @override
  bool get biometrics => false;

  @override
  bool get camera => false;

  @override
  bool get hardwareKeystore => false;

  @override
  ScreenProtection get screenProtection => ScreenProtection.none;
}

/// 页面测试的一套假依赖。`overrides` 直接用于 `ProviderScope`。
final class TestRig {
  TestRig({DateTime? now})
    : clock = FixedClock(now ?? DateTime.utc(2026, 11, 12, 12));

  late final accounts = FakeAccountRepository(addresses);
  final addresses = FakeAddressRepository();
  final holdings = FakeHoldingRepository();
  final prices = FakePriceRepository();
  final syncRecords = FakeSyncRecordRepository();
  final settings = FakeSettingsRepository();
  final registry = FakeAdapterRegistry();
  final priceSource = FakePriceSource();
  final secrets = FakeSecretStore();
  final FixedClock clock;
  final ids = SequenceIds();

  /// 剪贴板内容（假）。
  String? clipboard;

  /// 被写入剪贴板的内容。
  final copied = <String>[];

  /// 被请求用系统浏览器打开的链接。
  final opened = <Uri>[];

  /// 打开链接是否成功。
  bool openSucceeds = true;

  List<Override> get overrides => [
    accountRepositoryProvider.overrideWithValue(accounts),
    addressRepositoryProvider.overrideWithValue(addresses),
    holdingRepositoryProvider.overrideWithValue(holdings),
    priceRepositoryProvider.overrideWithValue(prices),
    syncRecordRepositoryProvider.overrideWithValue(syncRecords),
    settingsRepositoryProvider.overrideWithValue(settings),
    tokenVisibilityRepositoryProvider.overrideWithValue(
      FakeTokenVisibilityRepository(),
    ),
    adapterRegistryProvider.overrideWithValue(registry),
    priceSourceProvider.overrideWithValue(priceSource),
    secretStoreProvider.overrideWithValue(secrets),
    clockProvider.overrideWithValue(clock),
    idGeneratorProvider.overrideWithValue(ids),
    retryPolicyProvider.overrideWithValue(RetryPolicy(delay: (_) async {})),
    platformCapabilitiesProvider.overrideWithValue(FakePlatformCapabilities()),
    clipboardReaderProvider.overrideWithValue(() async => clipboard),
    clipboardWriterProvider.overrideWithValue((t) async => copied.add(t)),
    externalUrlOpenerProvider.overrideWithValue((u) async {
      opened.add(u);
      return openSucceeds;
    }),
  ];

  Account addWallet(
    String id,
    String name, {
    WalletSource? source,
    BackupStatus? backup,
    String? vaultItemId,
  }) {
    final a = Account(
      id: id,
      type: AccountType.wallet,
      name: name,
      colorIndex: 0,
      createdAt: DateTime.utc(2026, 11, 1),
      walletSource: source,
      backup: backup ?? const BackupStatus(),
      vaultItemId: vaultItemId,
    );
    accounts.feed.value = [...accounts.feed.value, a];
    return a;
  }

  Account addExchange(String id, String name, ExchangeId exchange) {
    final a = Account(
      id: id,
      type: AccountType.exchange,
      name: name,
      colorIndex: 1,
      createdAt: DateTime.utc(2026, 11, 1),
      exchange: exchange,
    );
    accounts.feed.value = [...accounts.feed.value, a];
    return a;
  }

  WatchAddress addAddress(
    String id,
    String accountId,
    String address, {
    ChainFamily family = ChainFamily.evm,
    Set<String>? chains,
  }) {
    final a = WatchAddress(
      id: id,
      accountId: accountId,
      family: family,
      address: address,
      enabledChainIds:
          chains ?? {for (final c in Chains.ofFamily(family)) c.id},
    );
    addresses.feed.value = [...addresses.feed.value, a];
    return a;
  }

  /// 给账户加一笔持仓；[assetId] 非空且给了 [price] 时同时写价格。
  void addHolding(
    String accountId,
    String addressId, {
    String chainId = 'ethereum',
    String symbol = 'ETH',
    String? assetId = 'ETH',
    String amount = '1',
    String? price = '2000',
    TokenRef? token,
  }) {
    holdings.feed.value = [
      ...holdings.feed.value,
      Holding(
        accountId: accountId,
        location: OnChainLocation(chainId: chainId, addressId: addressId),
        token: token ?? NativeToken(chainId),
        assetId: assetId,
        displaySymbol: symbol,
        amount: Decimal.parse(amount),
        updatedAt: DateTime.utc(2026, 11, 12, 11, 57),
      ),
    ];
    if (assetId != null && price != null) {
      prices.feed.value = {
        ...prices.feed.value,
        assetId: Price(
          assetId: assetId,
          quote: Quote.usd,
          price: Decimal.parse(price),
          updatedAt: DateTime.utc(2026, 11, 12, 11, 57),
        ),
      };
    }
  }

  void record(
    String accountId, {
    bool success = true,
    String? failureType,
    DateTime? at,
  }) {
    final t = at ?? DateTime.utc(2026, 11, 12, 11, 57);
    syncRecords.feed.value = [
      for (final r in syncRecords.feed.value)
        if (r.accountId != accountId) r,
      SyncRecord(
        accountId: accountId,
        startedAt: t,
        finishedAt: t,
        status: success ? SyncStatus.success : SyncStatus.failed,
        failureType: success ? null : (failureType ?? 'UnknownFailure'),
      ),
    ];
  }
}
