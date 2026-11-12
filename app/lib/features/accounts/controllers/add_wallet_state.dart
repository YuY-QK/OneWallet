import 'package:flutter/foundation.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';

const Object _unset = Object();

/// P05 初始备份状态的三选一（PRD P05 元素 6）。
enum BackupChoice { none, offline, keyless }

/// P05 中的一个地址输入。
@immutable
final class AddressEntry {
  const AddressEntry({
    required this.key,
    this.raw = '',
    this.family,
    this.chainIds = const {},
    this.unrecognized = false,
    this.duplicate,
  });

  /// 稳定的标识，用于列表项的 key 与定位（不是地址本身）。
  final int key;

  /// 用户输入的原文（公开地址）。
  final String raw;

  /// 实时识别出的链家族；未识别或为空时为 null。
  final ChainFamily? family;

  /// 选中的链 id。
  final Set<String> chainIds;

  /// 有内容但无法识别（R4）。
  final bool unrecognized;

  /// 与库中或本次输入中的地址重复（R2）。
  final DuplicateAddressFailure? duplicate;

  /// 输入框是否为空。
  bool get isEmpty => raw.trim().isEmpty;

  /// 可以提交：已识别、不重复、至少选了一条链。
  bool get isValid =>
      family != null &&
      !unrecognized &&
      duplicate == null &&
      chainIds.isNotEmpty;

  AddressEntry copyWith({
    String? raw,
    Object? family = _unset,
    Set<String>? chainIds,
    bool? unrecognized,
    Object? duplicate = _unset,
  }) => AddressEntry(
    key: key,
    raw: raw ?? this.raw,
    family: identical(family, _unset) ? this.family : family as ChainFamily?,
    chainIds: chainIds ?? this.chainIds,
    unrecognized: unrecognized ?? this.unrecognized,
    duplicate: identical(duplicate, _unset)
        ? this.duplicate
        : duplicate as DuplicateAddressFailure?,
  );
}

/// P05 的页面状态。只含公开信息（名称、地址），不含任何密钥类数据。
@immutable
final class AddWalletState {
  const AddWalletState({
    required this.accountId,
    required this.entries,
    this.existing,
    this.existingLoaded = false,
    this.name = '',
    this.source = WalletSource.other,
    this.backup = BackupChoice.none,
    this.saving = false,
    this.showErrors = false,
    this.saveFailure,
    this.alchemyKeyMissing = false,
  });

  /// 非空表示"给已有账户添加地址"。
  final String? accountId;

  /// 已有账户（只读展示名称与来源）；尚未读到或不存在时为 null。
  final Account? existing;

  /// 已有账户是否已读取完毕（用于区分"加载中"与"找不到"）。
  final bool existingLoaded;

  final String name;
  final WalletSource source;
  final List<AddressEntry> entries;
  final BackupChoice backup;

  /// 正在保存：保存按钮禁用。
  final bool saving;

  /// 点过保存后为真：此后才显示名称、空地址等"必填"错误。
  final bool showErrors;

  /// 保存时用例返回的失败。
  final Failure? saveFailure;

  /// 尚未配置 EVM 数据源 Key（P20 的引导提示）。
  final bool alchemyKeyMissing;

  /// 是否为"给已有账户添加地址"模式。
  bool get isAppendMode => accountId != null;

  /// 已有账户不存在（被删除）。
  bool get accountMissing => isAppendMode && existingLoaded && existing == null;

  /// 名称合法（追加模式不需要）。
  bool get nameValid {
    if (isAppendMode) return true;
    final length = name.trim().runes.length;
    return length >= 1 && length <= maxAccountNameLength;
  }

  /// 全部地址合法且至少一个。
  bool get entriesValid =>
      entries.isNotEmpty && entries.every((e) => !e.isEmpty && e.isValid);

  /// 是否存在 EVM 地址（决定是否显示 Key 缺失的提示）。
  bool get hasEvmEntry => entries.any((e) => e.family == ChainFamily.evm);

  AddWalletState copyWith({
    Account? existing,
    bool? existingLoaded,
    String? name,
    WalletSource? source,
    List<AddressEntry>? entries,
    BackupChoice? backup,
    bool? saving,
    bool? showErrors,
    Object? saveFailure = _unset,
    bool? alchemyKeyMissing,
  }) => AddWalletState(
    accountId: accountId,
    existing: existing ?? this.existing,
    existingLoaded: existingLoaded ?? this.existingLoaded,
    name: name ?? this.name,
    source: source ?? this.source,
    entries: entries ?? this.entries,
    backup: backup ?? this.backup,
    saving: saving ?? this.saving,
    showErrors: showErrors ?? this.showErrors,
    saveFailure: identical(saveFailure, _unset)
        ? this.saveFailure
        : saveFailure as Failure?,
    alchemyKeyMissing: alchemyKeyMissing ?? this.alchemyKeyMissing,
  );
}
