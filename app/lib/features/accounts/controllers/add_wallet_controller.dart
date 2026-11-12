import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_chains/ow_chains.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../../bootstrap/providers.dart';
import 'add_wallet_state.dart';

/// P05 添加钱包账户的控制器。参数是 `accountId`：为空表示新建账户，
/// 非空表示给已有账户添加地址。
final addWalletControllerProvider = NotifierProvider.autoDispose
    .family<AddWalletController, AddWalletState, String?>(
      AddWalletController.new,
    );

/// P05 的状态与操作：实时识别家族、重复检查、保存并触发同步。
class AddWalletController extends Notifier<AddWalletState> {
  AddWalletController(this.accountId);

  final String? accountId;

  int _nextKey = 1;
  int _generation = 0;

  @override
  AddWalletState build() {
    if (accountId != null) Future.microtask(_loadExisting);
    Future.microtask(_loadKeyStatus);
    return AddWalletState(
      accountId: accountId,
      entries: const [AddressEntry(key: 0)],
    );
  }

  Future<void> _loadExisting() async {
    final account = await ref.read(accountRepositoryProvider).byId(accountId!);
    if (!ref.mounted) return;
    state = state.copyWith(existing: account, existingLoaded: true);
  }

  Future<void> _loadKeyStatus() async {
    final key = await ref
        .read(dataSourceConfigProvider)
        .apiKey(EvmChainAdapter.providerId);
    if (!ref.mounted) return;
    state = state.copyWith(alchemyKeyMissing: key == null);
  }

  void setName(String value) =>
      state = state.copyWith(name: value, saveFailure: null);

  void setSource(WalletSource value) => state = state.copyWith(source: value);

  void setBackup(BackupChoice value) => state = state.copyWith(backup: value);

  /// 新增一个空的地址输入。
  void addEntry() {
    state = state.copyWith(
      entries: [
        ...state.entries,
        AddressEntry(key: _nextKey++),
      ],
    );
  }

  /// 删除一个地址输入（至少保留一个）。
  void removeEntry(int key) {
    if (state.entries.length <= 1) return;
    state = state.copyWith(
      entries: [
        for (final e in state.entries)
          if (e.key != key) e,
      ],
      saveFailure: null,
    );
    unawaited(_validateDuplicates());
  }

  /// 用户输入或粘贴了地址：立即识别家族，随后异步检查重复。
  void setAddress(int key, String raw) {
    final codec = ref.read(addressCodecProvider);
    final trimmed = raw.trim();
    final family = trimmed.isEmpty ? null : codec.detect(trimmed);
    state = state.copyWith(
      entries: [
        for (final e in state.entries)
          if (e.key == key) _updated(e, raw, trimmed, family) else e,
      ],
      saveFailure: null,
    );
    unawaited(_validateDuplicates());
  }

  AddressEntry _updated(
    AddressEntry e,
    String raw,
    String trimmed,
    ChainFamily? family,
  ) {
    // 家族不变时保留用户已做的链选择；变了就取该家族的默认（EVM 为全部六条，R3）。
    final chains = family == null
        ? <String>{}
        : family == e.family && e.chainIds.isNotEmpty
        ? e.chainIds
        : {for (final c in Chains.ofFamily(family)) c.id};
    return e.copyWith(
      raw: raw,
      family: family,
      chainIds: chains,
      unrecognized: trimmed.isNotEmpty && family == null,
      duplicate: null,
    );
  }

  /// 从剪贴板读取公开地址填入 [key] 对应的输入。剪贴板为空返回 false。
  Future<bool> paste(int key) async {
    final text = (await ref.read(clipboardReaderProvider)())?.trim();
    if (text == null || text.isEmpty || !ref.mounted) return false;
    setAddress(key, text);
    return true;
  }

  /// 切换 EVM 链的选中状态。
  void toggleChain(int key, String chainId) {
    state = state.copyWith(
      entries: [
        for (final e in state.entries)
          if (e.key == key)
            e.copyWith(
              chainIds: e.chainIds.contains(chainId)
                  ? ({...e.chainIds}..remove(chainId))
                  : {...e.chainIds, chainId},
            )
          else
            e,
      ],
    );
  }

  /// 重新检查每个地址是否与本次输入内、库中已有的地址重复（R2）。
  Future<void> _validateDuplicates() async {
    final generation = ++_generation;
    final addresses = ref.read(addressRepositoryProvider);
    final accounts = ref.read(accountRepositoryProvider);
    final seen = <(ChainFamily, String)>{};
    final result = <int, DuplicateAddressFailure?>{};
    for (final e in state.entries) {
      final family = e.family;
      if (family == null) continue;
      final normalized = AddressCodec.normalize(e.raw, family);
      final short = AddressCodec.shorten(normalized);
      if (!seen.add((family, normalized))) {
        result[e.key] = DuplicateAddressFailure(shortAddress: short);
        continue;
      }
      final found = await addresses.find(family, normalized);
      if (found != null) {
        final owner = await accounts.byId(found.accountId);
        result[e.key] = DuplicateAddressFailure(
          shortAddress: short,
          existingAccountName: owner?.name ?? '',
        );
      }
    }
    if (!ref.mounted || generation != _generation) return;
    state = state.copyWith(
      entries: [
        for (final e in state.entries) e.copyWith(duplicate: result[e.key]),
      ],
    );
  }

  /// 保存。成功返回账户 id（并已触发该账户的同步，不等待完成）；
  /// 本地校验未通过或用例失败返回 null，原因在状态里。
  Future<String?> save() async {
    if (state.saving || state.accountMissing) return null;
    state = state.copyWith(showErrors: true, saveFailure: null);
    if (!state.nameValid || !state.entriesValid) return null;
    state = state.copyWith(saving: true);
    final inputs = [
      for (final e in state.entries)
        AddressInput(raw: e.raw, family: e.family, chainIds: e.chainIds),
    ];
    final result = await _submit(inputs);
    if (!ref.mounted) return null;
    switch (result) {
      case Err(:final failure):
        state = state.copyWith(saving: false, saveFailure: failure);
        return null;
      case Ok(:final value):
        // 不等待：同步结果由账户页根据同步记录显示。
        unawaited(ref.read(syncAccountProvider)(value));
        state = state.copyWith(saving: false);
        return value;
    }
  }

  Future<Result<String>> _submit(List<AddressInput> inputs) async {
    final id = accountId;
    if (id != null) {
      final added = await ref.read(addAddressesToAccountProvider)(
        accountId: id,
        addresses: inputs,
      );
      return added.map((_) => id);
    }
    final created = await ref.read(addWalletAccountProvider)(
      name: state.name,
      addresses: inputs,
      walletSource: state.source,
      backup: switch (state.backup) {
        BackupChoice.none => const BackupStatus(),
        BackupChoice.offline => const BackupStatus(offlineBackedUp: true),
        BackupChoice.keyless => const BackupStatus(keyless: true),
      },
    );
    return created.map((a) => a.id);
  }
}
