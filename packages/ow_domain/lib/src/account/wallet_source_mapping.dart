import 'account.dart';

/// 目录钱包 ID 与 [WalletSource] 的双向固定对应表（纯常量，不依赖 `ow_directory`）。
///
/// 用于保持与已固化的备份载荷格式（FORMAT.md 第 5.2 节）及已有接口兼容：
/// 备份载荷中继续写入并读取 [WalletSource] 的枚举字面量，
/// 应用内部以 [Account.walletSourceId]（`ow_directory` 条目 ID）为准，
/// [Account.walletSource] 始终由其派生。
abstract final class WalletSourceMapping {
  /// 目录 ID → [WalletSource] 枚举。
  static const Map<String, WalletSource> directoryIdToSource = {
    'uniswap-wallet': WalletSource.uniswap,
    'metamask': WalletSource.metamask,
    'okx-web3-wallet': WalletSource.okxWeb3,
    'bitget-wallet': WalletSource.bitgetWallet,
    'trust-wallet': WalletSource.trustWallet,
  };

  /// [WalletSource] 枚举 → 目录 ID（other 对应 null，表示未在对应表中的其他钱包）。
  static const Map<WalletSource, String> sourceToDirectoryId = {
    WalletSource.uniswap: 'uniswap-wallet',
    WalletSource.metamask: 'metamask',
    WalletSource.okxWeb3: 'okx-web3-wallet',
    WalletSource.bitgetWallet: 'bitget-wallet',
    WalletSource.trustWallet: 'trust-wallet',
  };

  /// 将目录钱包 ID [directoryId]（null 表示"其他"）映射为 [WalletSource]。
  ///
  /// 若 [directoryId] 为 null 或未在对应表中的目录条目，返回 [WalletSource.other]。
  static WalletSource toWalletSource(String? directoryId) {
    if (directoryId == null) return WalletSource.other;
    return directoryIdToSource[directoryId] ?? WalletSource.other;
  }

  /// 将 [WalletSource] 映射为目录钱包 ID。
  ///
  /// [WalletSource.other] 或未知枚举反推为 null。
  static String? toDirectoryId(WalletSource? source) {
    if (source == null || source == WalletSource.other) return null;
    return sourceToDirectoryId[source];
  }
}
