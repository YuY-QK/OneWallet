import '../core/equality.dart';
import 'backup_status.dart';
import 'exchange_id.dart';
import 'wallet_source_mapping.dart';

/// 账户类型。
enum AccountType { wallet, exchange }

/// 钱包账户的来源钱包（PRD R5），只用于显示与向后兼容。
///
/// 在应用内以 [Account.walletSourceId]（`ow_directory` 中的条目 ID）为准，
/// [walletSource] 为其派生值，保持与备份格式一致。
enum WalletSource {
  uniswap,
  metamask,
  okxWeb3,
  bitgetWallet,
  trustWallet,
  other,
}

/// 一个钱包账户或交易所账户。
///
/// 字段取值范围（名称 1–30 字、颜色序号 0–7）由用例校验，本类不检查。
final class Account {
  Account({
    required this.id,
    required this.type,
    required this.name,
    required this.colorIndex,
    required this.createdAt,
    this.note = '',
    String? walletSourceId,
    WalletSource? walletSource,
    this.exchange,
    this.vaultItemId,
    this.backup = const BackupStatus(),
  }) : walletSourceId =
           walletSourceId ??
           (walletSource != null
               ? WalletSourceMapping.toDirectoryId(walletSource)
               : null),
       walletSource = walletSourceId != null
           ? WalletSourceMapping.toWalletSource(walletSourceId)
           : walletSource;

  /// 便捷工厂：创建钱包账户。
  ///
  /// [walletSourceId] 为 `ow_directory` 中的钱包条目 ID，null 表示"其他"。
  /// 对应的 [walletSource] 将根据双向映射表自动派生。
  factory Account.wallet({
    required String id,
    required String name,
    required int colorIndex,
    required DateTime createdAt,
    String note = '',
    String? walletSourceId,
    String? vaultItemId,
    BackupStatus backup = const BackupStatus(),
  }) => Account(
    id: id,
    type: AccountType.wallet,
    name: name,
    colorIndex: colorIndex,
    createdAt: createdAt,
    note: note,
    walletSourceId: walletSourceId,
    walletSource: WalletSourceMapping.toWalletSource(walletSourceId),
    vaultItemId: vaultItemId,
    backup: backup,
  );

  final String id;
  final AccountType type;

  /// 1–30 字。
  final String name;

  /// 0–7，对应设计规范中的头像色。
  final int colorIndex;
  final String note;

  /// 仅钱包账户：第三方目录中的钱包条目 ID（null 表示"其他"）。
  final String? walletSourceId;

  /// 仅钱包账户：由 [walletSourceId] 派生的枚举值，供备份载荷读写与向后兼容。
  final WalletSource? walletSource;

  /// 仅交易所账户。
  final ExchangeId? exchange;

  /// 仅钱包账户：关联的保险库密钥条目。
  final String? vaultItemId;

  /// 仅钱包账户有意义。
  final BackupStatus backup;

  /// 创建时间（UTC）。
  final DateTime createdAt;

  /// 由 [vaultItemId] 与 [backup] 推出的备份状态（PRD R34、R35）。
  ///
  /// 已入库与已离线备份可同时成立；只要有其中之一，即使同时标记了无助记词，
  /// 也按实际的备份情况显示。两者皆无时，标记了无助记词为 [BackupLevel.keyless]，
  /// 否则为 [BackupLevel.none]。只对钱包账户有意义。
  BackupLevel get backupLevel {
    final inVault = vaultItemId != null;
    final offline = backup.offlineBackedUp;
    if (inVault && offline) return BackupLevel.inVaultAndOffline;
    if (inVault) return BackupLevel.inVault;
    if (offline) return BackupLevel.offlineOnly;
    if (backup.keyless) return BackupLevel.keyless;
    return BackupLevel.none;
  }

  /// 返回替换了指定字段的副本。可空字段显式传 null 可清除（如解除保险库关联）。
  Account copyWith({
    String? name,
    int? colorIndex,
    String? note,
    Object? walletSourceId = unset,
    Object? walletSource = unset,
    Object? exchange = unset,
    Object? vaultItemId = unset,
    BackupStatus? backup,
  }) {
    final nextWalletSourceId = !identical(walletSourceId, unset)
        ? walletSourceId as String?
        : (!identical(walletSource, unset)
              ? WalletSourceMapping.toDirectoryId(walletSource as WalletSource?)
              : this.walletSourceId);
    final nextWalletSource = !identical(walletSourceId, unset)
        ? (type == AccountType.wallet
              ? WalletSourceMapping.toWalletSource(walletSourceId as String?)
              : null)
        : (!identical(walletSource, unset)
              ? walletSource as WalletSource?
              : this.walletSource);
    return Account(
      id: id,
      type: type,
      name: name ?? this.name,
      colorIndex: colorIndex ?? this.colorIndex,
      note: note ?? this.note,
      walletSourceId: nextWalletSourceId,
      walletSource: nextWalletSource,
      exchange: identical(exchange, unset)
          ? this.exchange
          : exchange as ExchangeId?,
      vaultItemId: identical(vaultItemId, unset)
          ? this.vaultItemId
          : vaultItemId as String?,
      backup: backup ?? this.backup,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Account &&
      other.id == id &&
      other.type == type &&
      other.name == name &&
      other.colorIndex == colorIndex &&
      other.note == note &&
      other.walletSourceId == walletSourceId &&
      other.walletSource == walletSource &&
      other.exchange == exchange &&
      other.vaultItemId == vaultItemId &&
      other.backup == backup &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    type,
    name,
    colorIndex,
    note,
    walletSourceId,
    walletSource,
    exchange,
    vaultItemId,
    backup,
    createdAt,
  );

  @override
  String toString() => 'Account($id, $type)';
}
