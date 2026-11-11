import '../core/equality.dart';
import 'backup_status.dart';
import 'exchange_id.dart';

/// 账户类型。
enum AccountType { wallet, exchange }

/// 钱包账户的来源钱包（PRD R5），只用于显示。
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
  const Account({
    required this.id,
    required this.type,
    required this.name,
    required this.colorIndex,
    required this.createdAt,
    this.note = '',
    this.walletSource,
    this.exchange,
    this.vaultItemId,
    this.backup = const BackupStatus(),
  });

  final String id;
  final AccountType type;

  /// 1–30 字。
  final String name;

  /// 0–7，对应设计规范中的头像色。
  final int colorIndex;
  final String note;

  /// 仅钱包账户。
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
    Object? walletSource = unset,
    Object? exchange = unset,
    Object? vaultItemId = unset,
    BackupStatus? backup,
  }) => Account(
    id: id,
    type: type,
    name: name ?? this.name,
    colorIndex: colorIndex ?? this.colorIndex,
    note: note ?? this.note,
    walletSource: identical(walletSource, unset)
        ? this.walletSource
        : walletSource as WalletSource?,
    exchange: identical(exchange, unset)
        ? this.exchange
        : exchange as ExchangeId?,
    vaultItemId: identical(vaultItemId, unset)
        ? this.vaultItemId
        : vaultItemId as String?,
    backup: backup ?? this.backup,
    createdAt: createdAt,
  );

  @override
  bool operator ==(Object other) =>
      other is Account &&
      other.id == id &&
      other.type == type &&
      other.name == name &&
      other.colorIndex == colorIndex &&
      other.note == note &&
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
    walletSource,
    exchange,
    vaultItemId,
    backup,
    createdAt,
  );

  @override
  String toString() => 'Account($id, $type)';
}
