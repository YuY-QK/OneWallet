import 'package:decimal/decimal.dart';
import 'package:ow_domain/ow_domain.dart';

import '../util/stream_combine.dart';

/// 备份清单中的钱包项。
final class BackupChecklistItem {
  const BackupChecklistItem({
    required this.account,
    required this.valuation,
    required this.isOverdue,
    this.daysSinceVerification,
  });

  /// 钱包账户。
  final Account account;

  /// 该账户当前估值（当前计价货币下）。
  final Decimal valuation;

  /// 是否超过 180 天未核对（R36）。仅当标记了离线备份时可能为真。
  final bool isOverdue;

  /// 距上次核对的天数（未核对过或非离线备份为 null）。
  final int? daysSinceVerification;

  @override
  bool operator ==(Object other) =>
      other is BackupChecklistItem &&
      other.account == account &&
      other.valuation == valuation &&
      other.isOverdue == isOverdue &&
      other.daysSinceVerification == daysSinceVerification;

  @override
  int get hashCode =>
      Object.hash(account, valuation, isOverdue, daysSinceVerification);
}

/// 备份清单只读聚合数据（PRD R34–R38、P11）。
final class BackupChecklistData {
  const BackupChecklistData({
    required this.pendingWallets,
    required this.completedWallets,
    required this.totalWallets,
    required this.backedUpWallets,
    this.lastBackupExportedAt,
    required this.hasUnexportedVaultChanges,
  });

  /// 待处理组（未备份 none 或无助记词 keyless），按估值降序排列。
  final List<BackupChecklistItem> pendingWallets;

  /// 已完成组（已入库、已离线备份或两者兼具）。
  final List<BackupChecklistItem> completedWallets;

  /// 钱包总数。
  final int totalWallets;

  /// 已备份钱包数。
  final int backedUpWallets;

  /// 上次导出加密备份的时间（UTC）。
  final DateTime? lastBackupExportedAt;

  /// 之后保险库是否有更改尚未导出备份（R38）。
  final bool hasUnexportedVaultChanges;

  /// 是否没有任何钱包账户。
  bool get isEmpty => totalWallets == 0;

  /// 是否全部钱包都已备份。
  bool get allBackedUp => totalWallets > 0 && pendingWallets.isEmpty;

  /// 待处理（未备份或无助记词）钱包数量。
  int get pendingCount => pendingWallets.length;
}

/// 纯函数：根据钱包账户、估值、设置与当前时间构建 [BackupChecklistData]（无 IO、便于测试）。
BackupChecklistData buildBackupChecklistData({
  required List<Account> accounts,
  required Map<String, Decimal> accountValuations,
  required AppSettings settings,
  required DateTime now,
}) {
  final pending = <BackupChecklistItem>[];
  final completed = <BackupChecklistItem>[];

  for (final account in accounts) {
    if (account.type != AccountType.wallet) continue; // R37: 排除交易所账户

    final val = accountValuations[account.id] ?? Decimal.zero;
    final level = account.backupLevel;

    final bool isOverdue;
    final int? daysSince;
    if (account.backup.offlineBackedUp) {
      final verifiedAt = account.backup.offlineVerifiedAt;
      if (verifiedAt == null) {
        isOverdue = true;
        daysSince = null;
      } else {
        final diff = now.difference(verifiedAt);
        daysSince = diff.inDays;
        isOverdue = diff >= const Duration(days: 180);
      }
    } else {
      isOverdue = false;
      daysSince = null;
    }

    final item = BackupChecklistItem(
      account: account,
      valuation: val,
      isOverdue: isOverdue,
      daysSinceVerification: daysSince,
    );

    if (level == BackupLevel.none || level == BackupLevel.keyless) {
      pending.add(item);
    } else {
      completed.add(item);
    }
  }

  // 待处理组按估值降序；金额相同按名称升序（PRD P11, TASKS M3-06）
  pending.sort((a, b) {
    final c = b.valuation.compareTo(a.valuation);
    return c != 0 ? c : a.account.name.compareTo(b.account.name);
  });

  // 已完成组按创建时间倒序
  completed.sort((a, b) => b.account.createdAt.compareTo(a.account.createdAt));

  final total = pending.length + completed.length;
  final backedUp = completed.length;

  final vaultChanged = settings.vaultChangedAt;
  final lastExported = settings.lastBackupExportedAt;
  final hasUnexported =
      vaultChanged != null &&
      (lastExported == null || vaultChanged.isAfter(lastExported));

  return BackupChecklistData(
    pendingWallets: pending,
    completedWallets: completed,
    totalWallets: total,
    backedUpWallets: backedUp,
    lastBackupExportedAt: lastExported,
    hasUnexportedVaultChanges: hasUnexported,
  );
}

/// 备份清单只读聚合流用例（PRD R34–R38）。
final class WatchBackupChecklist {
  const WatchBackupChecklist({
    required this.accounts,
    required this.holdings,
    required this.prices,
    required this.settings,
    required this.clock,
  });

  final AccountRepository accounts;
  final HoldingRepository holdings;
  final PriceRepository prices;
  final SettingsRepository settings;
  final Clock clock;

  Stream<BackupChecklistData> call() {
    final settingsWithPrices = switchLatest(
      settings.watch(),
      (AppSettings s) => prices.watch(s.quote).map((p) => (s, p)),
    );

    return combineLatest3(
      accounts.watchAll(),
      holdings.watchAll(),
      settingsWithPrices,
      (accounts, holdings, sp) {
        final (settings, prices) = sp;
        final summary = PortfolioCalculator.summarize(
          accounts: accounts,
          holdings: holdings,
          prices: prices,
          hideSmall: false,
          smallThreshold: Decimal.zero,
          hiddenTokens: const {},
        );
        final valuations = {
          for (final a in summary.byAccount) a.accountId: a.value,
        };
        return buildBackupChecklistData(
          accounts: accounts,
          accountValuations: valuations,
          settings: settings,
          now: clock.nowUtc(),
        );
      },
    );
  }
}
