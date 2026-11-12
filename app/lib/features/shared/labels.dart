import 'package:ow_domain/ow_domain.dart';

import '../../l10n/app_localizations.dart';
import '../../widgets/ow_pill.dart';

// 枚举到界面文案的映射，供多个页面共用。

/// 来源钱包的显示名；未设置时返回 null。
String? walletSourceLabel(AppLocalizations l, WalletSource? source) =>
    switch (source) {
      null => null,
      WalletSource.uniswap => l.walletSourceUniswap,
      WalletSource.metamask => l.walletSourceMetamask,
      WalletSource.okxWeb3 => l.walletSourceOkxWeb3,
      WalletSource.bitgetWallet => l.walletSourceBitgetWallet,
      WalletSource.trustWallet => l.walletSourceTrustWallet,
      WalletSource.other => l.walletSourceOther,
    };

/// 交易所的显示名。
String exchangeLabel(AppLocalizations l, ExchangeId id) => switch (id) {
  ExchangeId.binance => l.exchangeBinance,
  ExchangeId.okx => l.exchangeOkx,
  ExchangeId.bybit => l.exchangeBybit,
  ExchangeId.bitget => l.exchangeBitget,
};

/// 链家族的显示名。
String chainFamilyLabel(AppLocalizations l, ChainFamily family) =>
    switch (family) {
      ChainFamily.evm => l.chainFamilyEvm,
      ChainFamily.bitcoin => l.chainFamilyBitcoin,
      ChainFamily.solana => l.chainFamilySolana,
      ChainFamily.tron => l.chainFamilyTron,
    };

/// 备份状态的文字与胶囊颜色（PRD R34、R35）。
(String, OwPillTone) backupLabel(AppLocalizations l, BackupLevel level) =>
    switch (level) {
      BackupLevel.inVault => (l.backupStatusInVault, OwPillTone.green),
      BackupLevel.offlineOnly => (l.backupStatusOffline, OwPillTone.green),
      BackupLevel.inVaultAndOffline => (
        l.backupStatusInVaultAndOffline,
        OwPillTone.green,
      ),
      BackupLevel.keyless => (l.backupStatusKeyless, OwPillTone.orange),
      BackupLevel.none => (l.backupStatusNone, OwPillTone.red),
    };

/// 账户的显示名首字，用作头像标记；名称为空时用 `?`。
String avatarMark(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  return String.fromCharCode(trimmed.runes.first).toUpperCase();
}
