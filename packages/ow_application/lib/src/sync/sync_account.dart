import 'dart:async';

import 'package:ow_domain/ow_domain.dart';

import 'failure_type_name.dart';
import 'holding_normalizer.dart';
import 'retry_policy.dart';
import 'sync_cancellation.dart';

/// 单个账户同步成功（或被取消）的结果。
final class SyncAccountOutcome {
  const SyncAccountOutcome.synced(this.assets) : cancelled = false;

  /// 同步在写入之前被取消：未写持仓、未写同步记录，旧数据保持不变。
  const SyncAccountOutcome.cancelled() : cancelled = true, assets = const {};

  /// 是否被取消。
  final bool cancelled;

  /// 本次写入的持仓涉及的标准币种，供随后拉取价格。被取消时为空。
  final Set<Asset> assets;
}

/// 同步一个账户的余额（PRD R13、R15、R17，TECH_DESIGN 5.2）。
///
/// - 钱包账户：对每个地址 × 每条启用的链调用 [ChainAdapter.fetchHoldings]
///   （经 [RetryPolicy]，账户内串行）。全部成功才在一个事务内替换该账户的全部持仓；
///   任何一个失败，整个账户记为失败并保留旧数据（R15）。
/// - 交易所账户：M2-10 接入，目前返回 [UnsupportedFailure]。
///
/// 每次同步（被取消的除外）结束时写一条 [SyncRecord]。
/// 同一账户正在同步时再次调用，返回同一个进行中的 Future。
final class SyncAccount {
  SyncAccount({
    required this._accounts,
    required this._addresses,
    required this._holdings,
    required this._syncRecords,
    required this._adapters,
    required this._normalizer,
    required this._retryPolicy,
    required this._clock,
  });

  final AccountRepository _accounts;
  final AddressRepository _addresses;
  final HoldingRepository _holdings;
  final SyncRecordRepository _syncRecords;
  final AdapterRegistry _adapters;
  final HoldingNormalizer _normalizer;
  final RetryPolicy _retryPolicy;
  final Clock _clock;

  final Map<String, Future<Result<SyncAccountOutcome>>> _inFlight = {};

  /// 同步 [accountId]。
  ///
  /// 失败时：账户不存在返回 [ValidationFailure]（不写记录）；数据源失败返回
  /// 对应的 `Failure`，并写失败记录。[cancellation] 被取消后，尚未发出的请求
  /// 不再发出，返回 `Ok(SyncAccountOutcome.cancelled())`。
  /// 合并到进行中的调用时，本次传入的 [cancellation] 不生效。
  Future<Result<SyncAccountOutcome>> call(
    String accountId, {
    SyncCancellation? cancellation,
  }) {
    final running = _inFlight[accountId];
    if (running != null) return running;
    // 回调必须用代码块：箭头函数会返回被移除的 Future 本身，
    // whenComplete 会等待它，即自己等待自己而永不完成。
    final future = _run(accountId, cancellation).whenComplete(() {
      _inFlight.remove(accountId);
    });
    _inFlight[accountId] = future;
    return future;
  }

  Future<Result<SyncAccountOutcome>> _run(
    String accountId,
    SyncCancellation? cancellation,
  ) async {
    final account = await _accounts.byId(accountId);
    if (account == null) {
      return const Err(ValidationFailure('账户不存在'));
    }
    final startedAt = _clock.nowUtc();
    final fetched = await switch (account.type) {
      AccountType.wallet => _fetchWallet(account, cancellation),
      AccountType.exchange => _fetchExchange(account, cancellation),
    };
    if (cancellation?.isCancelled ?? false) {
      return const Ok(SyncAccountOutcome.cancelled());
    }
    switch (fetched) {
      case Err<List<LocatedRawHolding>>(:final failure):
        await _record(accountId, startedAt, failure);
        return Err(failure);
      case Ok<List<LocatedRawHolding>>(:final value):
        final normalized = await _normalizer(
          accountId: accountId,
          raw: value,
          updatedAt: _clock.nowUtc(),
        );
        if (cancellation?.isCancelled ?? false) {
          return const Ok(SyncAccountOutcome.cancelled());
        }
        await _holdings.replaceForAccount(accountId, normalized.holdings);
        await _record(accountId, startedAt, null);
        return Ok(SyncAccountOutcome.synced(normalized.assets));
    }
  }

  /// 钱包账户：逐个 地址 × 链 查询；遇到第一个失败即停止，整个账户失败。
  Future<Result<List<LocatedRawHolding>>> _fetchWallet(
    Account account,
    SyncCancellation? cancellation,
  ) async {
    final all = <LocatedRawHolding>[];
    for (final address in await _addresses.byAccount(account.id)) {
      final adapter = _adapters.chain(address.family);
      for (final chainId in address.enabledChainIds) {
        // 链 id 来自数据库；未知 id（如旧版本写入的链）跳过，不当作失败。
        final chain = Chains.tryById(chainId);
        if (chain == null || chain.family != address.family) continue;
        if (cancellation?.isCancelled ?? false) return Ok(all);
        final result = await _retryPolicy(
          () => adapter.fetchHoldings(address.address, chain),
          cancellation: cancellation,
        );
        switch (result) {
          case Err(:final failure):
            return Err(failure);
          case Ok(:final value):
            final location = OnChainLocation(
              chainId: chain.id,
              addressId: address.id,
            );
            all.addAll([for (final r in value) (location: location, raw: r)]);
        }
      }
    }
    return Ok(all);
  }

  /// 交易所账户：M2-10 在此接入 `CredentialRepository.load` 与
  /// `ExchangeAdapter.fetchHoldings`，把子账户映射为 [ExchangeLocation]。
  Future<Result<List<LocatedRawHolding>>> _fetchExchange(
    Account account,
    SyncCancellation? cancellation,
  ) async => const Err(UnsupportedFailure.notIntegrated('交易所同步在 M2-10 接入'));

  Future<void> _record(
    String accountId,
    DateTime startedAt,
    Failure? failure,
  ) => _syncRecords.add(
    SyncRecord(
      accountId: accountId,
      startedAt: startedAt,
      finishedAt: _clock.nowUtc(),
      status: failure == null ? SyncStatus.success : SyncStatus.failed,
      failureType: failure == null ? null : failureTypeName(failure),
    ),
  );
}
