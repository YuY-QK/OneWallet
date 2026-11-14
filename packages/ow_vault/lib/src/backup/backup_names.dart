import 'package:ow_domain/ow_domain.dart';

import '../vault/vault_format.dart';

// 备份载荷中枚举的写法（tools/backup_decrypt/FORMAT.md 第 5 节）。
//
// 这些字符串是公开、长期稳定的格式的一部分，所以逐个写死，不用 `enum.name`：
// Dart 里改了枚举名，格式也不会跟着变。新增枚举值时这里的 switch 会编译失败，
// 须补上写法并同步 FORMAT.md。读取时不认识的写法返回 null，由调用方跳过该条目。

String accountTypeName(AccountType v) => switch (v) {
  AccountType.wallet => 'wallet',
  AccountType.exchange => 'exchange',
};

String walletSourceName(WalletSource v) => switch (v) {
  WalletSource.uniswap => 'uniswap',
  WalletSource.metamask => 'metamask',
  WalletSource.okxWeb3 => 'okxWeb3',
  WalletSource.bitgetWallet => 'bitgetWallet',
  WalletSource.trustWallet => 'trustWallet',
  WalletSource.other => 'other',
};

String exchangeIdName(ExchangeId v) => switch (v) {
  ExchangeId.binance => 'binance',
  ExchangeId.okx => 'okx',
  ExchangeId.bybit => 'bybit',
  ExchangeId.bitget => 'bitget',
};

String chainFamilyName(ChainFamily v) => switch (v) {
  ChainFamily.evm => 'evm',
  ChainFamily.bitcoin => 'bitcoin',
  ChainFamily.solana => 'solana',
  ChainFamily.tron => 'tron',
};

String derivationSchemeName(DerivationScheme v) => switch (v) {
  DerivationScheme.evmStandard => 'evmStandard',
  DerivationScheme.evmLedgerLive => 'evmLedgerLive',
  DerivationScheme.btcNativeSegwit => 'btcNativeSegwit',
  DerivationScheme.btcTaproot => 'btcTaproot',
  DerivationScheme.btcNestedSegwit => 'btcNestedSegwit',
  DerivationScheme.btcLegacy => 'btcLegacy',
  DerivationScheme.solanaStandard => 'solanaStandard',
  DerivationScheme.solanaLegacy => 'solanaLegacy',
  DerivationScheme.tronStandard => 'tronStandard',
};

String quoteName(Quote v) => switch (v) {
  Quote.usd => 'usd',
  Quote.cny => 'cny',
};

String themeName(ThemePreference v) => switch (v) {
  ThemePreference.system => 'system',
  ThemePreference.light => 'light',
  ThemePreference.dark => 'dark',
};

String autoLockName(AutoLock v) => switch (v) {
  AutoLock.immediately => 'immediately',
  AutoLock.after1Min => 'after1Min',
  AutoLock.after5Min => 'after5Min',
};

/// 条目类型的写法与保险库文件一致：`mnemonic`、`private_key`。
String itemKindName(VaultItemKind v) => vaultItemKindName(v);

/// 在 [values] 中找写法为 [name] 的值；[name] 不是字符串或不认识时返回 null。
T? enumByName<T>(List<T> values, String Function(T) nameOf, String? name) {
  if (name == null) return null;
  for (final v in values) {
    if (nameOf(v) == name) return v;
  }
  return null;
}
