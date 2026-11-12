// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'OneWallet';

  @override
  String get tabOverview => '总览';

  @override
  String get tabAccounts => '账户';

  @override
  String get tabVault => '保险库';

  @override
  String get tabSettings => '设置';

  @override
  String get overviewEmptyTitle => '还没有账户';

  @override
  String get overviewEmptyBody => '添加一个链上地址或交易所，就能在这里看到总资产。';

  @override
  String get overviewEmptyAction => '添加第一个账户';

  @override
  String get accountsEmptyTitle => '还没有账户';

  @override
  String get accountsEmptyBody => '钱包和交易所账户会显示在这里。';

  @override
  String get vaultIntroTitle => '保险库尚未启用';

  @override
  String get vaultIntroBody => '保险库把助记词和私钥加密保存在这台设备上，不会联网。';

  @override
  String get vaultIntroAction => '启用保险库';

  @override
  String get settingsPlaceholder => '设置项将在后续里程碑加入。';

  @override
  String get notAvailableYet => '此功能尚未实现';

  @override
  String get bootstrapLoading => '正在打开本地数据…';

  @override
  String get bootstrapErrorTitle => '无法打开本地数据';

  @override
  String get bootstrapErrorSecureStorage => '无法访问系统安全存储。请确认设备已解锁后重试。';

  @override
  String get bootstrapErrorKeyMissing =>
      '本地数据库还在，但找不到它的密钥，可能是应用数据被清理或从备份恢复到了新设备。为避免丢失数据，应用不会自动重建数据库。';

  @override
  String get bootstrapErrorOpenFailed =>
      '本地数据库无法打开，文件可能已损坏。应用不会自动删除或重建它。请重试；仍然失败请联系开发者。';

  @override
  String get bootstrapRetry => '重试';

  @override
  String get timeJustNow => '刚刚';

  @override
  String timeMinutesAgo(int minutes) {
    return '$minutes 分钟前';
  }

  @override
  String get failureNetwork => '网络不可用或请求超时。请检查网络连接后重试。';

  @override
  String get failureRateLimited => '请求太频繁，被数据服务暂时限制了。请等一两分钟再刷新。';

  @override
  String get failureUnauthorized => 'API Key 或 Secret 不正确，服务商拒绝了请求。请检查后重新填写。';

  @override
  String get failureKeyExpired => 'API Key 已失效，请到交易所重新创建并更换。';

  @override
  String get failureClockSkew => '设备时间与服务器相差过大，请求被拒绝。请在系统设置中开启自动校时后重试。';

  @override
  String get failureServiceDown => '数据服务暂时出了问题。请稍后重试，已有的数据不受影响。';

  @override
  String get failureValidation => '输入的内容格式不正确。请检查后重新输入。';

  @override
  String get failureWrongPassword => '密码不正确。请重新输入。';

  @override
  String get failureUnsupported => '当前设备不支持这个功能。';

  @override
  String get failureUnknown => '出现了未知问题。请稍后重试，反复出现时可在「同步状态」中查看记录。';

  @override
  String failureDuplicateAddress(String kind, String address, String account) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'existing': '地址 $address 已在账户「$account」中，同一地址不能重复添加。',
      'other': '地址 $address 在本次输入中出现了不止一次，请删除重复的一项。',
    });
    return '$_temp0';
  }

  @override
  String get walletSourceUniswap => 'Uniswap Wallet';

  @override
  String get walletSourceMetamask => 'MetaMask';

  @override
  String get walletSourceOkxWeb3 => 'OKX Web3';

  @override
  String get walletSourceBitgetWallet => 'Bitget Wallet';

  @override
  String get walletSourceTrustWallet => 'Trust Wallet';

  @override
  String get walletSourceOther => '其他';

  @override
  String get exchangeBinance => 'Binance';

  @override
  String get exchangeOkx => 'OKX';

  @override
  String get exchangeBybit => 'Bybit';

  @override
  String get exchangeBitget => 'Bitget';

  @override
  String get chainFamilyEvm => 'EVM';

  @override
  String get chainFamilyBitcoin => 'Bitcoin';

  @override
  String get chainFamilySolana => 'Solana';

  @override
  String get chainFamilyTron => 'Tron';

  @override
  String get backupStatusInVault => '已入库';

  @override
  String get backupStatusOffline => '已离线备份';

  @override
  String get backupStatusInVaultAndOffline => '已入库并离线备份';

  @override
  String get backupStatusKeyless => '无助记词钱包';

  @override
  String get backupStatusNone => '未备份';

  @override
  String get syncFailureUnsupported => '暂不支持：这类地址的余额读取将在后续版本提供，已有数据不受影响。';

  @override
  String get comingSoonTitle => '即将推出';

  @override
  String get comingSoonBody => '此功能将在后续版本提供。';

  @override
  String get accountAddTitle => '添加账户';

  @override
  String get accountAddWatchTitle => '观察链上地址';

  @override
  String get accountAddWatchBody => '只需粘贴地址，不需要私钥';

  @override
  String get accountAddExchangeTitle => '连接交易所';

  @override
  String get accountAddExchangeBody => '使用只读 API Key';

  @override
  String get accountAddImportTitle => '导入助记词或私钥';

  @override
  String get accountAddImportBody => '存入加密保险库，并自动生成观察地址';

  @override
  String get walletAddTitle => '观察链上地址';

  @override
  String get walletAddExtraTitle => '添加地址';

  @override
  String get walletAddName => '账户名称';

  @override
  String get walletAddNameHint => '例如：主钱包';

  @override
  String get walletAddNameRequired => '请输入账户名称，最多 30 个字。';

  @override
  String get walletAddSource => '来源钱包';

  @override
  String get walletAddAddress => '地址';

  @override
  String walletAddAddressN(int n) {
    return '地址 $n';
  }

  @override
  String get walletAddAddressHint => '粘贴要观察的地址';

  @override
  String get walletAddAddressRequired => '请输入地址。';

  @override
  String get walletAddPaste => '粘贴';

  @override
  String get walletAddClipboardEmpty => '剪贴板里没有文字。';

  @override
  String walletAddRecognized(String family) {
    return '识别为 $family 地址';
  }

  @override
  String get walletAddUnrecognized => '无法识别的地址格式。请检查是否复制完整。';

  @override
  String get walletAddChains => '链（可多选）';

  @override
  String walletAddChainAuto(String chain) {
    return '链：$chain（自动确定）';
  }

  @override
  String get walletAddChainRequired => '至少选择一条链。';

  @override
  String get walletAddAnother => '再添加一个地址';

  @override
  String get walletAddRemove => '删除这个地址';

  @override
  String get walletAddBackup => '备份状态';

  @override
  String get walletAddBackupNone => '未备份';

  @override
  String get walletAddBackupOffline => '已离线备份';

  @override
  String get walletAddBackupKeyless => '无助记词钱包';

  @override
  String get walletAddSave => '保存';

  @override
  String get walletAddSaving => '保存中…';

  @override
  String get walletAddAccountMissing => '找不到这个账户，它可能已被删除。';

  @override
  String get walletAddKeyMissing =>
      '尚未配置 Alchemy Key，EVM 地址的余额可能查不到。可在「设置 → 数据源」中填写。';

  @override
  String get overviewHideAmounts => '隐藏金额';

  @override
  String get overviewShowAmounts => '显示金额';

  @override
  String get overviewAddAccount => '添加账户';

  @override
  String overviewTotalLabel(String quote) {
    return '总资产（$quote）';
  }

  @override
  String get overviewChange24h => '24 小时';

  @override
  String get overviewChangeUnknown => '24 小时变化 —';

  @override
  String overviewLastSynced(String time) {
    return '上次同步 $time';
  }

  @override
  String get overviewNeverSynced => '尚未同步';

  @override
  String get overviewDistCoin => '按币种';

  @override
  String get overviewDistAccount => '按账户';

  @override
  String get overviewDistType => '按类型';

  @override
  String get overviewTypeOnChain => '链上钱包';

  @override
  String get overviewTypeExchange => '交易所';

  @override
  String get overviewDistEmpty => '暂时没有可显示的资产。';

  @override
  String overviewFooterUnpriced(int count) {
    return '$count 个币种无估值';
  }

  @override
  String overviewFooterHidden(int count) {
    return '已隐藏 $count 个小额币种';
  }

  @override
  String get overviewSyncingLabel => '正在同步';

  @override
  String overviewPartialFailed(int count) {
    return '$count 个账户同步失败';
  }

  @override
  String overviewOffline(String time) {
    return '当前离线，显示的是 $time 的数据';
  }

  @override
  String get overviewAllFailedTitle => '同步失败';

  @override
  String get overviewAllFailedBody => '所有账户都没能同步，也没有可显示的缓存数据。请检查数据源设置后重试。';

  @override
  String get overviewRetry => '重试';

  @override
  String get overviewFailureListTitle => '同步失败的账户';

  @override
  String get overviewFailureClose => '关闭';

  @override
  String get accountsAdd => '添加账户';

  @override
  String get accountsGroupWallet => '钱包';

  @override
  String get accountsGroupExchange => '交易所';

  @override
  String get accountsSyncFailed => '同步失败';

  @override
  String get accountsLoadFailed => '无法读取账户列表。请重启应用后重试。';
}
