import 'dart:async';

import 'package:ow_domain/ow_domain.dart';

/// 持有当前值的可观察值：监听时先推送当前值，之后每次变化推送一次。
final class Watchable<T> {
  Watchable(this._value);

  T _value;
  final _changes = StreamController<T>.broadcast(sync: true);

  T get value => _value;

  set value(T v) {
    _value = v;
    _changes.add(v);
  }

  Stream<T> watch() {
    late final StreamController<T> out;
    StreamSubscription<T>? sub;
    out = StreamController<T>(
      onListen: () {
        out.add(_value);
        sub = _changes.stream.listen(out.add);
      },
      onCancel: () => sub?.cancel(),
    );
    return out.stream;
  }
}

final class InMemoryAccountRepository implements AccountRepository {
  final store = Watchable<List<Account>>(const []);

  @override
  Stream<List<Account>> watchAll() => store.watch();

  @override
  Future<Account?> byId(String id) async {
    for (final a in store.value) {
      if (a.id == id) return a;
    }
    return null;
  }

  @override
  Future<void> upsert(Account account) async {
    store.value = [
      for (final a in store.value)
        if (a.id != account.id) a,
      account,
    ];
  }

  @override
  Future<void> delete(String id) async {
    store.value = [
      for (final a in store.value)
        if (a.id != id) a,
    ];
  }
}

final class InMemoryAddressRepository implements AddressRepository {
  final store = Watchable<List<WatchAddress>>(const []);

  @override
  Stream<List<WatchAddress>> watchAll() => store.watch();

  @override
  Future<List<WatchAddress>> byAccount(String accountId) async => [
    for (final a in store.value)
      if (a.accountId == accountId) a,
  ];

  @override
  Future<WatchAddress?> find(ChainFamily family, String normalized) async {
    for (final a in store.value) {
      if (a.family == family && a.address == normalized) return a;
    }
    return null;
  }

  @override
  Future<void> upsert(WatchAddress address) async {
    final clash = await find(address.family, address.address);
    if (clash != null && clash.id != address.id) {
      throw StateError('违反 (family, address) 唯一约束');
    }
    store.value = [
      for (final a in store.value)
        if (a.id != address.id) a,
      address,
    ];
  }

  @override
  Future<void> delete(String id) async {
    store.value = [
      for (final a in store.value)
        if (a.id != id) a,
    ];
  }
}

final class InMemoryHoldingRepository implements HoldingRepository {
  final store = Watchable<List<Holding>>(const []);
  final replaceCalls = <String>[];

  List<Holding> forAccount(String accountId) => [
    for (final h in store.value)
      if (h.accountId == accountId) h,
  ];

  @override
  Stream<List<Holding>> watchAll() => store.watch();

  @override
  Future<void> replaceForAccount(String accountId, List<Holding> holdings) {
    replaceCalls.add(accountId);
    store.value = [
      for (final h in store.value)
        if (h.accountId != accountId) h,
      ...holdings,
    ];
    return Future.value();
  }
}

final class InMemoryPriceRepository implements PriceRepository {
  final store = Watchable<List<Price>>(const []);
  final upsertCalls = <List<Price>>[];

  @override
  Stream<Map<String, Price>> watch(Quote quote) => store.watch().map(
    (all) => {
      for (final p in all)
        if (p.quote == quote) p.assetId: p,
    },
  );

  @override
  Future<void> upsertAll(List<Price> prices) async {
    upsertCalls.add(prices);
    bool replaced(Price p) =>
        prices.any((n) => n.assetId == p.assetId && n.quote == p.quote);
    store.value = [
      for (final p in store.value)
        if (!replaced(p)) p,
      ...prices,
    ];
  }
}

final class InMemorySyncRecordRepository implements SyncRecordRepository {
  final _store = Watchable<List<SyncRecord>>(const []);

  List<SyncRecord> get records => _store.value;

  static List<SyncRecord> _latest(List<SyncRecord> all) {
    final byAccount = <String, SyncRecord>{};
    for (final r in all) {
      byAccount[r.accountId] = r;
    }
    return byAccount.values.toList();
  }

  @override
  Stream<List<SyncRecord>> watchLatestPerAccount() =>
      _store.watch().map(_latest);

  @override
  Future<void> add(SyncRecord record) async {
    final all = [..._store.value, record];
    _store.value = all.length > 50 ? all.sublist(all.length - 50) : all;
  }
}

final class InMemorySettingsRepository implements SettingsRepository {
  InMemorySettingsRepository([AppSettings initial = const AppSettings()])
    : store = Watchable(initial);

  final Watchable<AppSettings> store;

  @override
  Stream<AppSettings> watch() => store.watch();

  @override
  Future<void> update(AppSettings Function(AppSettings) change) async {
    store.value = change(store.value);
  }
}

final class InMemoryTokenVisibilityRepository
    implements TokenVisibilityRepository {
  final hiddenKeys = <String>{};

  @override
  Future<Set<String>> hidden() async => Set.of(hiddenKeys);

  @override
  Future<void> setHidden(String tokenKey, bool hidden) async {
    hidden ? hiddenKeys.add(tokenKey) : hiddenKeys.remove(tokenKey);
  }
}
