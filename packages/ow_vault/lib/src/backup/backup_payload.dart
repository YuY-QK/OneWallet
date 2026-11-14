import 'package:ow_domain/ow_domain.dart';

import '../vault/vault_item_secret.dart';

/// 加密备份的内容（解密后的载荷，PRD R39；字段定义见 tools/backup_decrypt/FORMAT.md）。
///
/// 包含：全部账户、地址、保险库条目（含明文）、可迁移的设置，以及可选的交易所凭据。
/// 不含余额、价格、快照、同步记录（R39、PRD 第 12 节 Q5）。
///
/// **敏感数据的生命周期**：保险库条目与交易所凭据中的密钥内容以 [Sensitive] 持有。
/// 传给 `BackupCodec.encode` 的对象仍归调用方，编码后由调用方 [wipe]；
/// `BackupCodec.decode` 返回的对象归调用方，恢复完成后必须 [wipe]。不得放进
/// 状态管理对象、路由参数或日志；`toString()` 只输出各部分的数量。
final class BackupPayload {
  /// 各列表被复制为不可修改的列表。
  BackupPayload({
    required DateTime exportedAt,
    required List<Account> accounts,
    required List<WatchAddress> addresses,
    required List<BackupVaultItem> vaultItems,
    required this.settings,
    List<BackupExchangeCredential>? exchangeCredentials,
    List<BackupSkipped> skipped = const [],
  }) : exportedAt = exportedAt.toUtc(),
       accounts = List.unmodifiable(accounts),
       addresses = List.unmodifiable(addresses),
       vaultItems = List.unmodifiable(vaultItems),
       exchangeCredentials = exchangeCredentials == null
           ? null
           : List.unmodifiable(exchangeCredentials),
       skipped = List.unmodifiable(skipped);

  /// 导出时间（UTC）。
  final DateTime exportedAt;
  final List<Account> accounts;
  final List<WatchAddress> addresses;
  final List<BackupVaultItem> vaultItems;
  final BackupSettings settings;

  /// 交易所凭据；null 表示备份不包含凭据（默认，R39），空列表表示包含但没有。
  final List<BackupExchangeCredential>? exchangeCredentials;

  /// 解码时因写法不认识（例如来自更新版本的链家族、派生方案）而跳过的条目。
  ///
  /// 只在 `BackupCodec.decode` 的结果中出现；编码时忽略。界面应告知用户
  /// 有几项未能恢复。
  final List<BackupSkipped> skipped;

  /// 关联了保险库条目 [itemId] 的账户 id（按 [accounts] 的顺序）。
  List<String> linkedAccountIds(String itemId) => [
    for (final a in accounts)
      if (a.vaultItemId == itemId) a.id,
  ];

  /// 清零全部密钥内容（保险库条目与交易所凭据）。可重复调用。
  void wipe() {
    for (final item in vaultItems) {
      item.wipe();
    }
    for (final c in exchangeCredentials ?? const <BackupExchangeCredential>[]) {
      c.wipe();
    }
  }

  @override
  String toString() =>
      'BackupPayload(accounts: ${accounts.length}, '
      'addresses: ${addresses.length}, vaultItems: ${vaultItems.length}, '
      'exchangeCredentials: ${exchangeCredentials?.length}, '
      'skipped: ${skipped.length})';
}

/// 备份中的一个保险库条目：数据库中的元数据（名称、创建时间）加明文 [secret]。
///
/// 关联的账户不在这里记录：以 `Account.vaultItemId` 为准，编码时据此写出
/// `linked_account_ids`（只供人阅读）。
final class BackupVaultItem {
  const BackupVaultItem({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.secret,
  });

  /// 保险库条目 id（规则同保险库文件：1–64 个 ASCII 字母、数字、`-`、`_`）。
  final String id;
  final String name;

  /// 创建时间（UTC）。
  final DateTime createdAt;

  /// 明文。由本对象的持有者负责 [wipe]。
  final VaultItemSecret secret;

  VaultItemKind get kind => secret.kind;

  void wipe() => secret.wipe();

  @override
  String toString() => 'BackupVaultItem($id, ${kind.name})';
}

/// 备份中一个交易所账户的只读 API 凭据。
final class BackupExchangeCredential {
  const BackupExchangeCredential({
    required this.accountId,
    required this.credentials,
  });

  final String accountId;

  /// 凭据内容。由本对象的持有者负责 [wipe]。
  final ExchangeCredentials credentials;

  void wipe() {
    credentials.apiKey.wipe();
    credentials.apiSecret.wipe();
    credentials.passphrase?.wipe();
  }

  @override
  String toString() => 'BackupExchangeCredential($accountId, ***)';
}

/// 备份中的设置：[AppSettings] 里适合迁移到另一台设备的项。
///
/// 不包含 PIN、应用锁与保险库的生物识别开关（与设备绑定）、上次导出时间、
/// 保险库变更时间、隐藏金额开关（临时的显示状态）。
final class BackupSettings {
  const BackupSettings({
    this.quote = Quote.usd,
    this.hideSmall = true,
    this.theme = ThemePreference.system,
    this.autoLock = AutoLock.immediately,
  });

  /// 取出 [settings] 中可迁移的项。
  factory BackupSettings.of(AppSettings settings) => BackupSettings(
    quote: settings.quote,
    hideSmall: settings.hideSmall,
    theme: settings.theme,
    autoLock: settings.autoLock,
  );

  final Quote quote;
  final bool hideSmall;
  final ThemePreference theme;
  final AutoLock autoLock;

  /// 把这些项写入 [settings]，其余项保持不变。
  AppSettings applyTo(AppSettings settings) => settings.copyWith(
    quote: quote,
    hideSmall: hideSmall,
    theme: theme,
    autoLock: autoLock,
  );

  @override
  bool operator ==(Object other) =>
      other is BackupSettings &&
      other.quote == quote &&
      other.hideSmall == hideSmall &&
      other.theme == theme &&
      other.autoLock == autoLock;

  @override
  int get hashCode => Object.hash(quote, hideSmall, theme, autoLock);
}

/// 被跳过的部分。
enum BackupSection { account, address, vaultItem, setting }

/// 解码时被跳过的一项：[section] 中 id 为 [id] 的条目（设置项时为字段名）。
///
/// 只含非敏感的标识，可以显示与记录日志。
final class BackupSkipped {
  const BackupSkipped(this.section, this.id);

  final BackupSection section;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is BackupSkipped && other.section == section && other.id == id;

  @override
  int get hashCode => Object.hash(section, id);

  @override
  String toString() => 'BackupSkipped(${section.name}, $id)';
}
