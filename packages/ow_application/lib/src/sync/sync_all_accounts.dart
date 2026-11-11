import 'dart:async';

import 'package:ow_domain/ow_domain.dart';

import 'retry_policy.dart';
import 'sync_account.dart';
import 'sync_all_result.dart';
import 'sync_cancellation.dart';

/// 全量同步结束（未被取消）后的回调。M3-05 在此写当日净值快照（PRD R16）。
typedef FullSyncCompletedHook = Future<void> Function(SyncAllResult result);

/// 同步全部账户并刷新价格（PRD R13、R15、R17，TECH_DESIGN 5.2）。
///
/// - 每个账户是独立任务，最多 [maxConcurrency] 个同时进行，互不影响。
/// - 账户全部结束后，汇总全部持仓涉及的标准币种，按当前计价货币拉取价格；
///   计价货币不是 USD 时另取一份 USD 价格（供快照与小额阈值使用）。
///   价格失败不改变账户结果，体现在 [SyncAllResult.priceFailure]。
/// - 进行中再次调用，返回同一个进行中的 Future。
final class SyncAllAccounts {
  SyncAllAccounts({
    required this._accounts,
    required this._holdings,
    required this._syncRecords,
    required this._settings,
    required this._prices,
    required this._priceSource,
    required this._catalog,
    required this._syncAccount,
    required this._retryPolicy,
    required this._clock,
    this.maxConcurrency = 4,
    this.autoSyncInterval = const Duration(minutes: 5),
    this._onFullSyncCompleted,
  });

  final AccountRepository _accounts;
  final HoldingRepository _holdings;
  final SyncRecordRepository _syncRecords;
  final SettingsRepository _settings;
  final PriceRepository _prices;
  final PriceSource _priceSource;
  final AssetCatalog _catalog;
  final SyncAccount _syncAccount;
  final RetryPolicy _retryPolicy;
  final Clock _clock;
  final FullSyncCompletedHook? _onFullSyncCompleted;

  /// 同时同步的账户数上限。
  final int maxConcurrency;

  /// 自动同步的最小间隔（R13：距上次同步超过 5 分钟）。
  final Duration autoSyncInterval;

  final StreamController<SyncProgress> _progress =
      StreamController<SyncProgress>.broadcast();
  Future<SyncAllResult>? _running;
  SyncCancellation? _cancellation;

  /// 进度流：开始时推送 `0/总数`，此后每结束一个账户推送一次。
  Stream<SyncProgress> get progress => _progress.stream;

  /// 是否有全量同步正在进行。
  bool get isRunning => _running != null;

  /// 执行一次全量同步。不会以 `Failure` 失败；各账户与价格的结果见返回值。
  Future<SyncAllResult> call() {
    final running = _running;
    if (running != null) return running;
    final cancellation = SyncCancellation();
    _cancellation = cancellation;
    final future = _run(cancellation).whenComplete(() {
      _running = null;
      _cancellation = null;
    });
    _running = future;
    return future;
  }

  /// 取消进行中的全量同步（离开前台时调用）。
  ///
  /// 未开始的账户不再开始；进行中的账户不再发出新请求、不写入；
  /// 已完成的账户结果保留。没有进行中的同步时什么也不做。
  void cancel() => _cancellation?.cancel();

  /// 是否应在解锁进入时自动同步（R13）。
  ///
  /// 依据各账户最近一条同步记录中最晚的一次成功；没有成功记录时返回 true；
  /// 距该次成功严格超过 [autoSyncInterval] 时返回 true。
  Future<bool> shouldAutoSync() async {
    final records = await _syncRecords.watchLatestPerAccount().first;
    DateTime? last;
    for (final r in records) {
      if (r.status != SyncStatus.success) continue;
      final at = r.finishedAt ?? r.startedAt;
      if (last == null || at.isAfter(last)) last = at;
    }
    if (last == null) return true;
    return _clock.nowUtc().difference(last) > autoSyncInterval;
  }

  Future<SyncAllResult> _run(SyncCancellation cancellation) async {
    final accounts = await _accounts.watchAll().first;
    final run = _AccountRun(accounts.map((a) => a.id).toList());
    _emit(run);
    final workerCount = maxConcurrency < run.total ? maxConcurrency : run.total;
    await Future.wait([
      for (var i = 0; i < workerCount; i++) _worker(run, cancellation),
    ]);
    run.cancelled.addAll(run.queue);

    if (cancellation.isCancelled) {
      return run.toResult(cancelled: true, pricesUpdated: false);
    }
    final priceFailure = await _refreshPrices(run.assets);
    final result = run.toResult(
      cancelled: false,
      pricesUpdated: priceFailure == null,
      priceFailure: priceFailure,
    );
    await _onFullSyncCompleted?.call(result);
    return result;
  }

  Future<void> _worker(_AccountRun run, SyncCancellation cancellation) async {
    while (run.queue.isNotEmpty && !cancellation.isCancelled) {
      final id = run.queue.removeAt(0);
      final result = await _syncAccount(id, cancellation: cancellation);
      switch (result) {
        case Ok(:final value) when value.cancelled:
          run.cancelled.add(id);
        case Ok(:final value):
          run.succeeded++;
          run.assets.addAll(value.assets);
        case Err(:final failure):
          run.failures.add(AccountSyncFailure(accountId: id, failure: failure));
      }
      run.completed++;
      _emit(run);
    }
  }

  void _emit(_AccountRun run) {
    if (_progress.hasListener) {
      _progress.add(SyncProgress(completed: run.completed, total: run.total));
    }
  }

  /// 拉取并写入价格。返回第一个失败；全部成功返回 null。
  Future<Failure?> _refreshPrices(Set<Asset> fromSync) async {
    final assets = await _assetsToPrice(fromSync);
    if (assets.isEmpty) return null;
    final quote = (await _settings.watch().first).quote;
    final quotes = {quote, Quote.usd};
    Failure? firstFailure;
    for (final q in quotes) {
      final result = await _retryPolicy(
        () => _priceSource.fetchPrices(assets, q),
      );
      switch (result) {
        case Ok(:final value):
          if (value.isNotEmpty) await _prices.upsertAll(value);
        case Err(:final failure):
          firstFailure ??= failure;
      }
    }
    return firstFailure;
  }

  /// 本次同步得到的币种，加上库中全部持仓（含失败账户保留的旧持仓）涉及的币种。
  Future<Set<Asset>> _assetsToPrice(Set<Asset> fromSync) async {
    final byId = {for (final a in fromSync) a.id: a};
    for (final h in await _holdings.watchAll().first) {
      final id = h.assetId;
      if (id == null || byId.containsKey(id)) continue;
      final asset = _catalog.byId(id);
      if (asset != null) byId[id] = asset;
    }
    return byId.values.toSet();
  }
}

/// 一次全量同步的可变中间状态，只在 [SyncAllAccounts._run] 内使用。
final class _AccountRun {
  _AccountRun(List<String> ids) : queue = ids, total = ids.length;

  final List<String> queue;
  final int total;
  int completed = 0;
  int succeeded = 0;
  final List<AccountSyncFailure> failures = [];
  final List<String> cancelled = [];
  final Set<Asset> assets = {};

  SyncAllResult toResult({
    required bool cancelled,
    required bool pricesUpdated,
    Failure? priceFailure,
  }) => SyncAllResult(
    succeededCount: succeeded,
    failures: failures,
    cancelledAccountIds: this.cancelled,
    pricesUpdated: pricesUpdated,
    cancelled: cancelled,
    priceFailure: priceFailure,
  );
}
