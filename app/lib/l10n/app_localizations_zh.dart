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
  String get failureVaultCorrupted => '保险库文件已损坏或被改动，无法读取。请不要删除它，可用加密备份恢复。';

  @override
  String get failureVaultVersionUnsupported =>
      '这个保险库文件来自更新版本的 OneWallet，当前版本无法读取。请先升级应用，文件未被改动。';

  @override
  String get failureVaultNotFound => '找不到保险库文件。如果之前创建过保险库，请用加密备份恢复。';

  @override
  String get failureVaultAlreadyExists => '保险库已经存在，不能重复创建。';

  @override
  String get failureVaultItemNotFound => '保险库中找不到这个密钥，它可能已被删除。';

  @override
  String get failureBackupCorrupted =>
      '这不是 OneWallet 的备份文件，或文件已损坏，无法读取。请换一份备份文件再试。';

  @override
  String get failureBackupVersionUnsupported =>
      '这个备份文件来自更新版本的 OneWallet，当前版本无法读取。请先升级应用再恢复。';

  @override
  String get failureUnsupported => '当前设备不支持这个功能。';

  @override
  String get failureUnsupportedNotIntegrated =>
      '暂不支持这条链或这家交易所，将在后续版本提供，已有数据不受影响。';

  @override
  String get failureUnknown => '出现了未知问题。请稍后重试，反复出现时可在「同步状态」中查看记录。';

  @override
  String failureDuplicateAddress(String kind, String address, String account) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'existing': '地址 $address 已在账户「$account」中，同一地址不能重复添加。',
      'ownerMissing': '该地址已存在于本应用中。',
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
  String get accountsSyncing => '同步中';

  @override
  String get accountsLoadFailed => '无法读取账户列表。请重启应用后重试。';

  @override
  String get accountsSelectHint => '选择一个账户查看详情。';

  @override
  String get walletDetailTotal => '账户总估值';

  @override
  String get walletDetailTabAssets => '资产';

  @override
  String get walletDetailTabAddresses => '地址';

  @override
  String get walletDetailNoAssets => '该钱包目前没有可显示的资产';

  @override
  String get walletDetailNotFound => '找不到这个账户，它可能已被删除。';

  @override
  String get walletDetailFailedTitle => '同步失败';

  @override
  String walletDetailLastSuccess(String time) {
    return '上次成功同步：$time';
  }

  @override
  String get walletDetailNeverSucceeded => '还没有成功同步过，下面没有缓存数据。';

  @override
  String walletDetailUnpriced(int count) {
    return '$count 个未识别或无估值的币种';
  }

  @override
  String get walletDetailAddAddress => '添加地址';

  @override
  String get walletDetailAddressesHint => '点击地址可查看二维码、复制、在浏览器中打开';

  @override
  String walletDetailChainCount(int count) {
    return '$count 条链';
  }

  @override
  String addressSheetTitle(String family) {
    return '$family 地址';
  }

  @override
  String get addressSheetCopy => '复制地址';

  @override
  String get addressSheetCopied => '已复制';

  @override
  String get addressSheetExplorerHeader => '在区块浏览器中打开';

  @override
  String addressSheetExplorerRow(String chain, String host) {
    return '$chain · $host';
  }

  @override
  String get addressSheetExplorerNote => '将用系统浏览器打开所示网站，请确认域名无误。';

  @override
  String get addressSheetOpenFailed => '无法打开系统浏览器。';

  @override
  String get addressSheetDelete => '删除地址';

  @override
  String get addressSheetDeleteLast => '账户至少要保留一个地址，所以不能删除最后一个地址。';

  @override
  String get addressSheetDeleteTitle => '删除这个地址？';

  @override
  String get addressSheetDeleteBody => '删除后，这个地址的余额缓存也会清除；链上资产不受影响，之后可以重新添加。';

  @override
  String get addressSheetCancel => '取消';

  @override
  String get addressSheetExcludedBtc => '口径说明：只含已确认余额，未确认交易不计入。';

  @override
  String get addressSheetExcludedSol => '口径说明：不含质押在验证者上的 SOL 与 NFT。';

  @override
  String get addressSheetExcludedTron => '口径说明：不含 Stake 1.0 质押与未领取的投票奖励。';

  @override
  String get settingsSectionData => '数据';

  @override
  String get settingsSources => '数据源';

  @override
  String get settingsSourcesBody => '配置链上数据与价格服务的 API Key';

  @override
  String get settingsSync => '同步状态';

  @override
  String get settingsSyncBody => '各账户同步情况与日志';

  @override
  String settingsSyncFailedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个账户失败',
    );
    return '$_temp0';
  }

  @override
  String get sourcesTitle => '数据源';

  @override
  String get sourcesAlchemyName => 'Alchemy';

  @override
  String get sourcesAlchemyBody => 'EVM 六条链的余额';

  @override
  String get sourcesMempoolName => 'mempool.space';

  @override
  String get sourcesMempoolBody => 'Bitcoin · 只含已确认余额';

  @override
  String get sourcesHeliusName => 'Helius';

  @override
  String get sourcesHeliusBody => 'Solana · 不含质押在验证者上的 SOL 与 NFT';

  @override
  String get sourcesTrongridName => 'TronGrid';

  @override
  String get sourcesTrongridBody => 'Tron · 不含 Stake 1.0 与未领取的奖励';

  @override
  String get sourcesCoingeckoName => 'CoinGecko';

  @override
  String get sourcesCoingeckoBody => '价格（Key 可选）';

  @override
  String get sourcesComingSoon => '即将支持';

  @override
  String get sourcesConfigured => '已配置';

  @override
  String get sourcesNotConfigured => '未配置';

  @override
  String sourcesConfiguredPreview(String preview) {
    return '已配置 · $preview';
  }

  @override
  String get sourcesPrivacy => '查询余额时，你的地址和 IP 会被发送给所选的数据服务商。';

  @override
  String sourcesEditTitle(String name) {
    return '$name 设置';
  }

  @override
  String get sourcesKeyLabel => 'API Key';

  @override
  String get sourcesKeyHint => '粘贴 API Key';

  @override
  String get sourcesKeyHintReplace => '输入新的 Key 以替换已保存的';

  @override
  String get sourcesKeyShow => '显示';

  @override
  String get sourcesKeyHide => '隐藏';

  @override
  String get sourcesKeyEmpty => '请输入 API Key。';

  @override
  String get sourcesAlchemyRequired => '读取 EVM 余额需要 Alchemy 的 API Key。';

  @override
  String get sourcesMempoolRequired =>
      'mempool.space 公共实例无需 API Key。如需自建实例，可在下方配置自定义端点。';

  @override
  String get sourcesHeliusRequired => 'Solana 余额与代币查询；未配置时使用公共节点（限制较严）。';

  @override
  String get sourcesTrongridRequired => 'Tron 余额与 TRC-20 查询；未配置时易受限频。';

  @override
  String get sourcesCoingeckoOptional =>
      'CoinGecko 的 Key 可不填，但免费额度较紧，价格刷新可能被限频。';

  @override
  String get sourcesSave => '保存';

  @override
  String get sourcesSaved => '已保存';

  @override
  String get sourcesClear => '清除 Key';

  @override
  String get sourcesTest => '测试连接';

  @override
  String get sourcesTesting => '正在测试…';

  @override
  String get sourcesTestSaveFirst => '输入的 Key 还没有保存。请先保存，再测试连接。';

  @override
  String get sourcesTestOk => '连接正常。';

  @override
  String get sourcesAdvanced => '高级：自定义 RPC 端点';

  @override
  String get sourcesEndpointNote => '自定义端点会收到你的地址与 IP，请只填写可信的服务。';

  @override
  String get sourcesEndpointHint => 'https://…';

  @override
  String get sourcesEndpointInvalid => '只接受 https 地址，且不能包含用户名或密码。';

  @override
  String sourcesEndpointSet(String host) {
    return '已设置自定义端点：$host';
  }

  @override
  String get sourcesEndpointDefault => '使用默认端点';

  @override
  String get sourcesEndpointSave => '保存端点';

  @override
  String get sourcesEndpointClear => '恢复默认';

  @override
  String get sourcesDone => '完成';

  @override
  String get sourcesCoingeckoAttribution => '价格数据来自 CoinGecko';

  @override
  String get externalLinkConfirmTitle => '即将离开 OneWallet';

  @override
  String externalLinkConfirmBody(String url) {
    return '将用系统浏览器打开以下网址，请核对域名：\n\n$url';
  }

  @override
  String get externalLinkConfirmOpen => '继续访问';

  @override
  String get externalLinkCancel => '取消';

  @override
  String get directoryLinkWebsite => '官网';

  @override
  String get directoryLinkDocs => '帮助文档';

  @override
  String get directoryLinkApiKey => '获取 API Key';

  @override
  String get walletAddSourceSearch => '搜索钱包…';

  @override
  String get walletAddSourceOther => '其他';

  @override
  String get exchangeAddTitle => '连接交易所';

  @override
  String get exchangeReplaceKeyTitle => '更换 API Key';

  @override
  String get exchangeAddExchange => '交易所';

  @override
  String get exchangeAddAccountName => '账户名称';

  @override
  String get exchangeAddAccountNameHint => '例如：Binance 主账户';

  @override
  String get exchangeAddAccountNameRequired => '请输入账户名称，最多 30 个字。';

  @override
  String get exchangeAddApiKey => 'API Key';

  @override
  String get exchangeAddApiKeyHint => '粘贴或输入 API Key';

  @override
  String get exchangeAddApiKeyRequired => '请输入 API Key。';

  @override
  String get exchangeAddApiSecret => 'API Secret';

  @override
  String get exchangeAddApiSecretHint => '粘贴或输入 API Secret';

  @override
  String get exchangeAddApiSecretRequired => '请输入 API Secret。';

  @override
  String get exchangeAddPassphrase => 'Passphrase';

  @override
  String get exchangeAddPassphraseHint => '创建 API Key 时设置的口令';

  @override
  String get exchangeAddPassphraseRequired => '请输入 Passphrase。';

  @override
  String get exchangeAddPaste => '粘贴';

  @override
  String get exchangeAddSecurityNote =>
      '请只勾选「读取」权限，不要开启交易和提现。保存前会检查这个 Key 的权限。';

  @override
  String get exchangeAddGuideTitle => '如何创建只读 API Key';

  @override
  String get exchangeAddGuideSubtitle => '分步图文与官方指引';

  @override
  String get exchangeAddGuideOfficialLink => '前往官方创建指引';

  @override
  String get exchangeAddGuideApiManagementLink => '前往 API 管理';

  @override
  String get exchangeAddTestAndSave => '测试并保存';

  @override
  String get exchangeAddVerifying => '正在验证凭据…';

  @override
  String get exchangeAddSaving => '正在保存…';

  @override
  String get exchangeAddComingSoon => '即将支持';

  @override
  String get exchangeAddBitgetNotice => 'Bitget 暂未接入，即将支持。';

  @override
  String get exchangeAddPermWarningTitle => '权限超出只读';

  @override
  String get exchangeAddPermWarningBody =>
      '检测到此 Key 包含交易或提现权限，存在资金安全风险。建议在交易所后台重新创建只读 Key。';

  @override
  String get exchangeAddPermWarningModify => '返回修改';

  @override
  String get exchangeAddPermWarningProceed => '仍然保存';

  @override
  String get exchangeAddErrCredential =>
      'API Key、Secret 或 Passphrase 不正确，服务商拒绝了请求。';

  @override
  String get exchangeAddErrNetwork => '网络不可用或请求超时。请检查网络连接后重试。';

  @override
  String get exchangeAddErrClockSkew => '设备时间与服务器相差过大，请求被拒绝。请在系统设置中开启自动校时后重试。';

  @override
  String get exchangeAddErrIpRestricted =>
      '该 API Key 限制了访问 IP，请检查交易所后台的 IP 白名单设置。';

  @override
  String get exchangeAddErrAccountMissing => '找不到这个账户，它可能已被删除。';

  @override
  String exchangeAddErrUnknown(String detail) {
    return '验证失败：$detail';
  }

  @override
  String get exchangeDetailTotal => '账户总估值';

  @override
  String get exchangeDetailTabAssets => '按币种';

  @override
  String get exchangeDetailTabSubAccounts => '按子账户';

  @override
  String get exchangeDetailKeyStatusNormal => 'API Key 正常 · 只读';

  @override
  String get exchangeDetailKeyStatusExpired => 'API Key 已失效';

  @override
  String get exchangeDetailKeyExpiredNotice => 'API Key 已失效，无法同步最新资产，请尽快更换。';

  @override
  String get exchangeDetailNoAssets => '该交易所目前没有可显示的资产';

  @override
  String get exchangeDetailNotFound => '找不到这个交易所账户，它可能已被删除。';

  @override
  String get exchangeDetailFailedTitle => '同步失败';

  @override
  String exchangeDetailLastSuccess(String time) {
    return '上次成功同步：$time';
  }

  @override
  String get exchangeDetailNeverSucceeded => '还没有成功同步过，下面没有缓存数据。';

  @override
  String exchangeDetailUnpriced(int count) {
    return '$count 个未识别或无估值的币种';
  }

  @override
  String exchangeDetailNotIncluded(String items) {
    return '未包含：$items';
  }

  @override
  String get exchangeDetailDepositAddressesTitle => '充值地址';

  @override
  String get exchangeDetailDepositAddressesSubtitle => '由交易所控制，仅供查看';

  @override
  String get exchangeDetailDepositAddressesNotice =>
      '此地址由交易所控制，仅供查看。为避免在交易所自动创建新地址，仅展示已有地址。';

  @override
  String get exchangeDetailDepositAddressesEmpty => '暂无充值地址';

  @override
  String exchangeDetailDepositAddressMemo(String memo) {
    return '备注/Tag: $memo';
  }

  @override
  String get exchangeDetailReplaceKey => '更换 API Key';

  @override
  String get exchangeDetailDeleteAccount => '删除账户';

  @override
  String get exchangeDetailDeleteConfirmTitle => '删除交易所账户';

  @override
  String get exchangeDetailDeleteConfirmBody =>
      '确定删除此交易所账户？删除后将同时清除存储的 API 凭据，本地持仓与同步记录也将被移除。';

  @override
  String get exchangeDetailDeleteConfirmAction => '删除';

  @override
  String get exchangeDetailDeleteCancelAction => '取消';

  @override
  String get subAccountSpot => '现货';

  @override
  String get subAccountFunding => '资金';

  @override
  String get subAccountFutures => '合约';

  @override
  String get subAccountMargin => '杠杆';

  @override
  String get subAccountEarn => '理财';

  @override
  String get subAccountOther => '其他';

  @override
  String get assetDetailTitle => '币种详情';

  @override
  String get assetDetailCurrentPrice => '当前价格';

  @override
  String get assetDetailHoldings => '持有';

  @override
  String get assetDetailValuation => '估值';

  @override
  String get assetDetailDistributionTitle => '分布';

  @override
  String get assetDetailDistributionEmpty => '暂无账户持有该币种';

  @override
  String get assetDetailContractsTitle => '合约地址';

  @override
  String get assetDetailCopyContract => '复制';

  @override
  String get assetDetailCopied => '已复制合约地址';

  @override
  String get assetDetailNoPrice => '估值缺失';

  @override
  String get assetDetailNotFound => '未找到该币种信息';

  @override
  String get assetDetailViewDistribution => '查看币种分布';

  @override
  String get syncStatusTitle => '同步状态';

  @override
  String get syncStatusLastFullSync => '上次全量同步';

  @override
  String get syncStatusNeverFullSynced => '尚未进行过全量同步';

  @override
  String get syncStatusSyncNow => '立即同步';

  @override
  String get syncStatusSyncing => '正在同步...';

  @override
  String syncStatusDurationSeconds(String seconds) {
    return '用时 $seconds 秒';
  }

  @override
  String syncStatusDurationMs(int ms) {
    return '用时 $ms 毫秒';
  }

  @override
  String get syncStatusAccountsSection => '各账户状态';

  @override
  String get syncStatusLogsSection => '最近同步记录（最多 50 条）';

  @override
  String get syncStatusLogsEmpty => '暂无同步记录';

  @override
  String get syncStatusSuccess => '成功';

  @override
  String get syncStatusFailed => '失败';

  @override
  String get syncStatusRunning => '同步中';

  @override
  String syncStatusLastSuccess(String time) {
    return '上次成功 $time';
  }

  @override
  String get syncStatusNeverSuccess => '从未成功同步';

  @override
  String get syncStatusKeyExpiredHint => 'API Key 已失效，请更换';

  @override
  String get syncStatusViewFullStatus => '查看完整同步状态';

  @override
  String get syncStatusDeletedAccount => '已删除的账户';

  @override
  String get accountsTabAccounts => '账户';

  @override
  String get accountsTabAddressBook => '地址簿';

  @override
  String get accountsSort => '排序';

  @override
  String get accountsSortByValuation => '按估值排序';

  @override
  String get accountsSortByName => '按名称排序';

  @override
  String get accountsMoreActions => '更多操作';

  @override
  String get accountsMenuRename => '重命名';

  @override
  String get accountsMenuDelete => '删除';

  @override
  String get accountsRenameTitle => '重命名账户';

  @override
  String get accountsRenameHint => '请输入账户名称';

  @override
  String get accountsRenameCancel => '取消';

  @override
  String get accountsRenameSave => '保存';

  @override
  String get accountsDeleteWalletTitle => '删除钱包账户';

  @override
  String get accountsDeleteWalletMessage =>
      '确定删除此账户？将删除其地址、持仓缓存与历史快照中的该账户明细。如果关联了保险库密钥，密钥不会被删除，仅解除关联。此操作无法撤销。';

  @override
  String get accountsDeleteExchangeTitle => '删除交易所账户';

  @override
  String get accountsDeleteExchangeMessage =>
      '确定删除此交易所账户？删除后将同时清除存储的 API 凭据，本地持仓与同步记录也将被移除。此操作无法撤销。';

  @override
  String get accountsDeleteCancelAction => '取消';

  @override
  String get accountsDeleteConfirmAction => '删除';

  @override
  String get accountsFooterHint => '长按账户可重命名或删除';

  @override
  String get addressSheetNoteLabel => '备注';

  @override
  String get addressSheetNoNote => '添加备注';

  @override
  String get addressSheetEditNoteTitle => '编辑备注';

  @override
  String get addressSheetEditNoteHint => '请输入地址备注（如：长期持有、主要收款）';

  @override
  String get addressSheetEditNoteTooLong => '备注长度不能超过 100 个字符';

  @override
  String get addressSheetSave => '保存';

  @override
  String get addressBookSearchHint => '搜索地址、账户、备注';

  @override
  String get addressBookChainAll => '全部链';

  @override
  String get addressBookAccountAll => '全部账户';

  @override
  String get addressBookExactMatch => '是你的地址';

  @override
  String get addressBookVaultDerived => '保险库派生';

  @override
  String addressBookNote(String note) {
    return '备注：$note';
  }

  @override
  String get addressBookEmptyTitle => '暂无地址';

  @override
  String get addressBookEmptyDesc => '添加钱包账户后，此处将集中管理你的所有地址';

  @override
  String get addressBookSearchNoResultTitle => '不在你的地址簿中';

  @override
  String get addressBookSearchNoResultDesc => '未在你的地址簿中找到此地址或相关信息';

  @override
  String get addressBookFooterTip => '粘贴一个完整地址，可以查它是不是你的。没有匹配时会显示「不在你的地址簿中」。';

  @override
  String get overviewChartRange7d => '7 天';

  @override
  String get overviewChartRange30d => '30 天';

  @override
  String get overviewChartRange90d => '90 天';

  @override
  String get overviewChartRangeAll => '全部';

  @override
  String get overviewChartEmpty => '至少需要两天的快照数据以绘制净值曲线';

  @override
  String overviewChartAriaLabel(int count) {
    return '近 $count 天净值曲线';
  }

  @override
  String get overviewChartAriaLabelAll => '全部净值曲线';

  @override
  String overviewChartDaysAgo(int count) {
    return '$count 天前';
  }

  @override
  String get overviewChartToday => '今天';

  @override
  String overviewBackupWarning(int count) {
    return '$count 个钱包尚未备份';
  }

  @override
  String get backupChecklistTitle => '备份清单';

  @override
  String backupChecklistProgress(int backedUp, int total) {
    return '$backedUp / $total 个钱包已备份';
  }

  @override
  String get backupChecklistAllBackedUp => '全部钱包已备份';

  @override
  String get backupChecklistNeverExported => '尚未导出过加密备份';

  @override
  String backupChecklistLastExport(String time) {
    return '加密备份文件：$time 导出';
  }

  @override
  String get backupChecklistUnexportedChanges => '之后保险库有更改，尚未导出';

  @override
  String get backupChecklistExport => '导出加密备份';

  @override
  String get backupChecklistPendingSection => '待处理';

  @override
  String get backupChecklistCompletedSection => '已完成';

  @override
  String get backupChecklistExchangeNote => '交易所资产没有私钥可备份。请启用二次验证，并保管好账号凭据。';

  @override
  String get backupChecklistEmptyTitle => '暂无钱包账户';

  @override
  String get backupChecklistEmptyDesc => '添加钱包账户后，在此查看和管理各钱包的备份状况。';

  @override
  String get backupChecklistKeylessNote =>
      '这类钱包依赖服务商。建议趁服务可用时导出私钥，或把资产转到普通助记词钱包。';

  @override
  String get backupChecklistOverdueWarning => '超过 180 天未核对';

  @override
  String backupChecklistLastVerified(String date) {
    return '上次核对 $date';
  }

  @override
  String get backupActionGoToVault => '去入库';

  @override
  String get backupActionMarkOffline => '标记已离线备份';

  @override
  String get backupActionUnmarkOffline => '取消离线备份标记';

  @override
  String get backupActionMarkKeyless => '标记为无助记词钱包';

  @override
  String get backupActionUnmarkKeyless => '取消无助记词标记';

  @override
  String get backupActionVerifiedToday => '今天已核对';

  @override
  String get backupActionResetStatus => '重新标记';

  @override
  String get backupActionViewChecklist => '查看完整备份清单';

  @override
  String get backupStatusSheetTitle => '备份状态管理';

  @override
  String get backupStatusInVaultDesc => '已关联保险库中的密钥条目。';

  @override
  String get backupStatusOfflineDesc => '已标记为有纸质或其他离线备份。';

  @override
  String get backupStatusOfflineNeverVerified => '未记录核对日期';

  @override
  String get backupStatusKeylessDesc => '无助记词钱包（MPC 或社交登录型，无法导出）。';

  @override
  String get backupStatusNoneDesc => '尚未在保险库入库，也没有标记离线备份。';

  @override
  String get bootstrapWipeAndRestart => '清除本地数据并重新开始';

  @override
  String get bootstrapWipeConfirmTitle => '清除本地数据并重新开始？';

  @override
  String get bootstrapWipeConfirmBody =>
      '此操作将清除本地数据库与所有存储的凭据，无法撤销。如果您有加密备份文件（.owbak），可以在重新进入应用后恢复。';

  @override
  String get bootstrapWipeConfirmAction => '清除并重新开始';

  @override
  String get bootstrapWipeFailed => '清除未完成，请重试';

  @override
  String get bootstrapWipeFailedBody => '部分本地数据未能成功清除，请重试。';

  @override
  String get settingsSectionSecurity => '安全';

  @override
  String get settingsSectionOther => '其他';

  @override
  String get settingsSectionDanger => '危险区';

  @override
  String get settingsSecurity => '应用锁与生物识别';

  @override
  String get settingsSecurityBody => '修改 PIN、自动锁定时间与生物识别';

  @override
  String get settingsSecuritySoon => '安全设置功能即将提供';

  @override
  String get settingsBackup => '加密备份';

  @override
  String get settingsBackupNever => '尚未备份';

  @override
  String settingsBackupLastExported(String date) {
    return '上次导出 $date';
  }

  @override
  String get settingsQuote => '计价货币';

  @override
  String get settingsHideSmall => '隐藏小额币种';

  @override
  String get settingsHideSmallBody => '低于 1 USD 的资产不显示在列表中';

  @override
  String get settingsUnrecognizedTokens => '未识别代币';

  @override
  String get settingsUnrecognizedTokensEmpty => '暂无未识别代币';

  @override
  String get settingsUnrecognizedTokensDesc => '链上收到但未在价格源中识别的代币可以在此处管理显隐';

  @override
  String get settingsTheme => '外观';

  @override
  String get settingsThemeSystem => '跟随系统';

  @override
  String get settingsThemeLight => '浅色模式';

  @override
  String get settingsThemeDark => '深色模式';

  @override
  String get settingsAbout => '关于与帮助';

  @override
  String get settingsWipeAllData => '清除全部数据';

  @override
  String get settingsWipeConfirmTitle => '清除全部数据？';

  @override
  String get settingsWipeConfirmBody =>
      '此操作将清除本地全部钱包、交易所、持仓、快照与保存的凭据，不可撤销。如果有加密备份文件（.owbak），可以在重新进入应用后恢复。';

  @override
  String get settingsWipeConfirmAction => '清除全部数据';

  @override
  String get securitySectionAppLock => '应用锁';

  @override
  String get securitySectionVault => '保险库';

  @override
  String get securitySectionDevice => '设备';

  @override
  String get securityPin => '修改 PIN';

  @override
  String get securityAppBiometrics => '面容 / 指纹解锁';

  @override
  String get securityAutoLock => '自动锁定';

  @override
  String get securityAutoLockImmediately => '立即';

  @override
  String get securityAutoLock1Min => '1 分钟后';

  @override
  String get securityAutoLock5Min => '5 分钟后';

  @override
  String get securityVaultBiometrics => '面容 / 指纹解锁保险库';

  @override
  String get securityVaultBiometricsDesc => '开启时需输入主密码，由硬件安全芯片保护';

  @override
  String get securityChangeMasterPassword => '修改主密码';

  @override
  String get securityDeviceStatus => '设备安全状态';

  @override
  String get securityDeviceNormal => '正常';

  @override
  String get securityDeviceNormalDesc => '未检测到越狱或 root';

  @override
  String get deviceIntegrityWarningTitle => '设备安全风险提示';

  @override
  String get deviceIntegrityWarningBody =>
      '检测到当前设备环境存在异常（可能已被 root、越狱或处于调试状态），系统沙盒与硬件保护可能失效。请谨慎使用。';

  @override
  String get deviceIntegrityWarningConfirm => '我知道了';

  @override
  String get securityFeaturePending => '功能准备中';

  @override
  String get aboutTitle => '关于与帮助';

  @override
  String get aboutVersion => '版本';

  @override
  String get aboutSecurityDesign => '安全设计说明';

  @override
  String get aboutSecurityDesignBody => '本地优先、密钥不出设备、只看不动';

  @override
  String get aboutSecurityDesignDialogTitle => '安全设计原则';

  @override
  String get aboutSecurityDesignDetail =>
      '1. 本地优先：你的资产数据和密钥仅保存在当前设备，不上传至任何服务器。\n\n2. 只看不动：OneWallet 不提供签名、转账或交易功能，杜绝被黑客恶意调用的可能。\n\n3. 离线保险库：助记词和私钥由独立的加密保险库保管，与联网环境物理隔离。';

  @override
  String get aboutBackupFormat => '备份文件格式与解密工具';

  @override
  String get aboutBackupFormatBody => '公开格式，支持电脑端开源离线解密';

  @override
  String get aboutBackupFormatDialogTitle => '加密备份与离线解密';

  @override
  String get aboutBackupFormatDetail =>
      'OneWallet 的加密备份（.owbak）采用公开规范与标准算法（Argon2id + XChaCha20-Poly1305）。\n\n即使应用不可用，你也可以在断网电脑上使用官方提供的开源 Python 脚本解密并导出全部助记词与数据。';

  @override
  String get aboutFaq => '常见问题';

  @override
  String get aboutFaqDerivationTitle => '派生路径是什么？';

  @override
  String get aboutFaqDerivationAnswer =>
      '派生路径是按照 BIP44/84/86 等加密货币标准，从同一套助记词计算出不同链和不同地址规则的算法路径。';

  @override
  String get aboutFaqMismatchTitle => '为什么链上地址与钱包软件显示的不一致？';

  @override
  String get aboutFaqMismatchAnswer =>
      '不同钱包软件可能采用了不同的默认派生路径或地址格式（例如 Bitcoin 的 Legacy 1 开头、SegWit 3 开头或 Native SegWit bc1 开头）。在派生地址页面可以选择对应的路径预设。';

  @override
  String get aboutFaqApiKeyTitle => '如何创建只读 API Key？';

  @override
  String get aboutFaqApiKeyAnswer =>
      '在交易所 API 管理页面创建密钥时，仅勾选「读取」或「Read-Only」权限，切勿开启「交易」或「提现」权限以保障资金绝对安全。';

  @override
  String get aboutLicenses => '开源许可';

  @override
  String get cancel => '取消';

  @override
  String get failureBiometricUnavailable => '无法使用生物识别，请输入主密码。';

  @override
  String failureLockedOut(String time) {
    return '输错次数过多，请在 $time 之后再试。';
  }

  @override
  String get lockTitle => 'OneWallet';

  @override
  String get lockSubtitle => '输入 6 位 PIN';

  @override
  String get lockWrongPin => 'PIN 码不正确';

  @override
  String lockCountdown(String time) {
    return '错误次数过多，请在 $time 后重试';
  }

  @override
  String get lockBiometricsButton => '生物识别';

  @override
  String get lockBiometricReason => '解锁 OneWallet';

  @override
  String get lockDeleteKey => '⌫';

  @override
  String get onboardingWelcomeTitle => '一处看全，备份不丢';

  @override
  String get onboardingWelcomeSubtitle => '查看所有链上钱包和交易所的资产，并把助记词存进本机的加密保险库。';

  @override
  String get onboardingSecurityTitle => '开始前请了解';

  @override
  String get onboardingSecurity1Title => '只读，不转账';

  @override
  String get onboardingSecurity1Desc => 'app 不会发起任何交易';

  @override
  String get onboardingSecurity2Title => '密钥只存在这台手机';

  @override
  String get onboardingSecurity2Desc => '不上传到任何服务器';

  @override
  String get onboardingSecurity3Title => 'PIN 和主密码无法找回';

  @override
  String get onboardingSecurity3Desc => '请务必记牢，并导出加密备份';

  @override
  String get onboardingStartButton => '我已了解，开始使用';

  @override
  String get onboardingRestoreButton => '从备份恢复';

  @override
  String get onboardingSetPinTitle => '设置 6 位 PIN';

  @override
  String get onboardingSetPinSubtitle => '用于每次打开应用时验证身份';

  @override
  String get onboardingConfirmPinTitle => '请再次输入以确认';

  @override
  String get onboardingConfirmPinSubtitle => '两次输入的 PIN 必须一致';

  @override
  String get onboardingPinMismatch => '两次输入的 PIN 不一致，请重新输入';

  @override
  String get onboardingBiometricTitle => '开启生物识别';

  @override
  String get onboardingBiometricSubtitle => '使用面容或指纹更快捷地解锁 OneWallet';

  @override
  String get onboardingEnableBiometric => '开启';

  @override
  String get onboardingSkipBiometric => '稍后再说';

  @override
  String get vaultTitle => '保险库';

  @override
  String get vaultFooterNote => '保险库内容仅存于本机。请定期导出加密备份。';

  @override
  String vaultChecklistNotice(int count) {
    return '备份清单：$count 个钱包未备份';
  }

  @override
  String get vaultEmptyItemsTitle => '暂无密钥条目';

  @override
  String get vaultEmptyItemsBody => '点击右上角「＋」导入第一个助记词或私钥。';

  @override
  String get vaultItemKindMnemonic => '助记词';

  @override
  String get vaultItemKindPrivateKey => '私钥';

  @override
  String get vaultItemPassphrase => '含密码';

  @override
  String get vaultImportAction => '导入密钥';

  @override
  String get vaultSetupTitle => '创建保险库';

  @override
  String get vaultSetupIntro => '主密码用于保护你的助记词，换手机恢复时也需要它。';

  @override
  String get vaultSetupWarningTitle => '主密码无法找回';

  @override
  String get vaultSetupWarningBody =>
      'OneWallet 不在任何服务器保存你的密码。如果遗忘主密码，保险库内的全部密钥将永远无法恢复。';

  @override
  String get vaultSetupPasswordLabel => '主密码（至少 10 个字符）';

  @override
  String get vaultSetupPasswordHint => '请输入至少 10 位主密码';

  @override
  String get vaultSetupPasswordConfirmLabel => '再次输入';

  @override
  String get vaultSetupPasswordConfirmHint => '请再次输入主密码';

  @override
  String get vaultSetupAgreeRisk => '我明白主密码丢失后，保险库内容无法恢复。';

  @override
  String get vaultSetupBiometricsTitle => '使用面容或指纹解锁保险库';

  @override
  String get vaultSetupBiometricsSubtitle => '日常查看更方便，硬件安全芯片保护';

  @override
  String get vaultSetupCreateButton => '创建保险库';

  @override
  String get vaultSetupCreating => '正在生成保险库与加密密钥…';

  @override
  String get vaultSetupTooShort => '主密码长度至少为 10 个字符';

  @override
  String get vaultSetupMismatch => '两次输入的密码不一致';

  @override
  String vaultSetupStrengthLabel(String strength) {
    return '强度：$strength';
  }

  @override
  String get vaultSetupStrengthWeak => '弱';

  @override
  String get vaultSetupStrengthMedium => '中等';

  @override
  String get vaultSetupStrengthStrong => '强';

  @override
  String get vaultSetupWeakConfirmTitle => '密码强度较弱';

  @override
  String get vaultSetupWeakConfirmBody =>
      '当前主密码强度较弱。为了资金安全，建议使用包含大小写字母、数字或符号的复杂密码。是否确认使用当前密码？';

  @override
  String get vaultSetupWeakConfirmContinue => '仍然使用';

  @override
  String get vaultSetupWeakConfirmCancel => '返回修改';

  @override
  String get vaultSetupSuccess => '保险库已成功创建';

  @override
  String get vaultImportTitle => '导入到保险库';

  @override
  String get vaultImportTypeMnemonic => '助记词';

  @override
  String get vaultImportTypePrivateKey => '私钥';

  @override
  String get vaultImportNameLabel => '名称';

  @override
  String get vaultImportNameHint => '如：小狐狸主号';

  @override
  String get vaultImportWordCountLabel => '词数';

  @override
  String get vaultImportPasteFullPhrase => '粘贴整段';

  @override
  String get vaultImportPasteInvalid => '剪贴板中的内容词数不匹配（支持 12/15/18/21/24 词）';

  @override
  String get vaultImportWordSuggestions => '联想词';

  @override
  String get vaultImportMnemonicChecksumFailed => '助记词校验失败，请检查拼写和顺序';

  @override
  String get vaultImportAdvancedPassphrase => '高级：BIP39 附加密码 (Passphrase)';

  @override
  String get vaultImportPassphraseHint => '可选，通常为空';

  @override
  String get vaultImportChainFamilyLabel => '链类型';

  @override
  String get vaultImportPrivateKeyLabel => '私钥';

  @override
  String get vaultImportPrivateKeyHintEvm => '64 位十六进制私钥，可带 0x';

  @override
  String get vaultImportPrivateKeyHintBtc => 'WIF 格式私钥（以 5、K 或 L 开头）';

  @override
  String get vaultImportPrivateKeyHintSol => 'Base58 编码的私钥';

  @override
  String get vaultImportPrivateKeyHintTrx => '64 位十六进制私钥，可带 0x';

  @override
  String get vaultImportPrivateKeyFormatError => '私钥格式不正确';

  @override
  String get vaultImportLinkAccountLabel => '关联账户';

  @override
  String get vaultImportLinkAccountNone => '不关联（稍后在派生地址页处理）';

  @override
  String get vaultImportSubmitButton => '保存到保险库';

  @override
  String get vaultImportVerifyPasswordTitle => '输入主密码';

  @override
  String get vaultImportVerifyPasswordMessage => '请先输入主密码验证身份后保存密钥';

  @override
  String get vaultImportVerifyPasswordCancel => '取消';

  @override
  String get vaultImportVerifyPasswordConfirm => '验证并保存';

  @override
  String get vaultImportSuccess => '密钥已成功保存到保险库';

  @override
  String get vaultImportDuplicateError => '该密钥已存在于保险库中';

  @override
  String get vaultItemDetailTitle => '密钥详情';

  @override
  String get vaultItemType => '类型';

  @override
  String get vaultItemCreatedAt => '创建于';

  @override
  String get vaultItemLinkedAccount => '关联账户';

  @override
  String get vaultItemLinkedAccountNone => '未关联';

  @override
  String get vaultItemVeilMessage => '每次查看都需要面容或主密码验证';

  @override
  String get vaultItemVeilAction => '验证后查看';

  @override
  String get vaultItemPassphraseLabel => 'BIP39 附加密码 (Passphrase)';

  @override
  String get vaultItemPrivateKey => '私钥';

  @override
  String get vaultItemShowQrCode => '以二维码显示';

  @override
  String get vaultItemHideQrCode => '以文字显示';

  @override
  String vaultItemCountdown(int seconds) {
    return '$seconds 秒后自动隐藏';
  }

  @override
  String get vaultItemHideAction => '隐藏';

  @override
  String get vaultItemDerivedAddresses => '已派生地址';

  @override
  String vaultItemDerivedAddressesCount(int count) {
    return '$count 个地址已在观察中';
  }

  @override
  String get vaultItemDeleteButton => '删除此密钥';

  @override
  String get vaultItemDeleteDialogTitle => '删除此密钥';

  @override
  String get vaultItemDeleteDialogMessage =>
      '确定删除此密钥条目？删除后，关联钱包的备份状态将变为未备份。若未另行备份，将无法再查看或导出此密钥。此操作无法撤销。';

  @override
  String get vaultItemDeleteAgreeRisk => '我明白此操作无法撤销，且我已另有备份。';

  @override
  String get vaultItemDeletePasswordHint => '请输入主密码以确认删除';

  @override
  String get vaultItemDeleteConfirm => '删除';

  @override
  String get vaultItemDeleteSuccess => '密钥已删除';

  @override
  String get vaultItemFooterNote => '不提供复制；本页禁止截屏';

  @override
  String get vaultItemRecordingWarning => '检测到录屏，已隐藏敏感内容';

  @override
  String get vaultItemEditNameTitle => '修改条目名称';

  @override
  String get vaultItemEditNameLabel => '名称';

  @override
  String get vaultDeriveTitle => '派生地址';

  @override
  String get vaultDeriveNotice => '以下地址由你的密钥计算得出，仅地址会被用于查询余额，密钥不会离开保险库。';

  @override
  String get vaultDeriveSchemeEvmStandard => '标准（MetaMask 等）';

  @override
  String get vaultDeriveSchemeEvmLedgerLive => 'Ledger Live';

  @override
  String get vaultDeriveSchemeBtcNativeSegwit => '原生隔离见证 bc1q（默认）';

  @override
  String get vaultDeriveSchemeBtcTaproot => 'Taproot bc1p';

  @override
  String get vaultDeriveSchemeBtcNestedSegwit => '嵌套隔离见证 3 开头';

  @override
  String get vaultDeriveSchemeBtcLegacy => '传统 1 开头';

  @override
  String get vaultDeriveSchemeSolanaStandard => '标准（Phantom 等）';

  @override
  String get vaultDeriveSchemeSolanaLegacy => '旧式';

  @override
  String get vaultDeriveSchemeTronStandard => '标准';

  @override
  String get vaultDeriveAlreadyWatched => '已在观察';

  @override
  String get vaultDeriveShowMore => '显示更多';

  @override
  String get vaultDeriveCheckBalance => '检测余额';

  @override
  String get vaultDeriveCheckingBalance => '正在检测...';

  @override
  String get vaultDeriveActive => '有活动';

  @override
  String get vaultDeriveInactive => '无活动';

  @override
  String get vaultDeriveCheckNotice => '检测余额将向公开节点查询该地址是否有交易活动或余额，密钥不会离开设备。';

  @override
  String get vaultDeriveTargetAccount => '目标账户';

  @override
  String get vaultDeriveNewAccount => '新建钱包账户';

  @override
  String get vaultDeriveExistingAccount => '加入已有账户';

  @override
  String get vaultDeriveNewAccountNameLabel => '账户名称';

  @override
  String get vaultDeriveSelectAccountHint => '选择已有钱包账户';

  @override
  String get vaultDeriveAttachAction => '加入观察';

  @override
  String get vaultDeriveSkipAction => '跳过';

  @override
  String get vaultDeriveSuccess => '已成功加入观察';

  @override
  String get vaultDeriveNoSelection => '请至少选择一个地址';

  @override
  String get vaultDeriveAuthPrompt => '请输入主密码以计算派生地址';

  @override
  String get vaultDeriveVerifyTitle => '验证主密码';

  @override
  String get vaultDeriveVerifyConfirm => '开始派生';

  @override
  String get vaultDeriveDeriving => '正在派生地址...';

  @override
  String get vaultDeriveEmpty => '暂无派生地址';

  @override
  String get vaultDeriveItemNotFound => '未找到密钥条目';

  @override
  String get settingsSecuritySubtitle => 'PIN 码、面容/指纹解锁、自动锁定与保险库设置';

  @override
  String get securityTitle => '安全设置';

  @override
  String get securityChangePin => '修改 PIN';

  @override
  String get securityChangePinSuccess => 'PIN 码已修改';

  @override
  String get securityChangePinOldTitle => '输入当前 PIN';

  @override
  String get securityChangePinOldSubtitle => '请输入当前使用的 6 位数字 PIN';

  @override
  String get securityChangePinNewTitle => '输入新 PIN';

  @override
  String get securityChangePinNewSubtitle => '请输入新的 6 位数字 PIN';

  @override
  String get securityChangePinConfirmTitle => '确认新 PIN';

  @override
  String get securityChangePinConfirmSubtitle => '请再次输入新的 6 位数字 PIN';

  @override
  String get securityChangePinMismatch => '两次输入的 PIN 不一致，请重新输入';

  @override
  String get securityChangePinWrongOld => '原 PIN 码不正确';

  @override
  String get securityAppBiometricsDesc => '解锁 OneWallet 时使用生物识别';

  @override
  String get securityVaultBiometricsUninitialized => '保险库尚未创建';

  @override
  String get securityVaultBiometricsUnsupported => '当前设备不支持硬件密钥保护';

  @override
  String get securityChangeMasterPasswordTitle => '修改主密码';

  @override
  String get securityChangeMasterPasswordSuccess => '主密码已修改';

  @override
  String get securityChangeMasterPasswordCurrent => '当前主密码';

  @override
  String get securityChangeMasterPasswordCurrentHint => '请输入当前主密码';

  @override
  String get securityChangeMasterPasswordNew => '新主密码（至少 10 个字符）';

  @override
  String get securityChangeMasterPasswordNewHint => '请输入至少 10 位新主密码';

  @override
  String get securityChangeMasterPasswordConfirm => '确认新主密码';

  @override
  String get securityChangeMasterPasswordConfirmHint => '请再次输入新主密码';

  @override
  String get securityChangeMasterPasswordChanging => '正在重新加密保险库…';

  @override
  String get securityChangeMasterPasswordMismatch => '两次输入的主密码不一致';

  @override
  String get securityChangeMasterPasswordTooShort => '主密码长度至少为 10 个字符';

  @override
  String get securityChangeMasterPasswordWrongCurrent => '当前主密码不正确';

  @override
  String get securityChangeMasterPasswordConfirmAction => '确认修改';

  @override
  String get securityDeviceCompromised => '风险';

  @override
  String get securityDeviceCompromisedDesc => '检测到设备环境异常，可能已被越狱或 root';

  @override
  String get securityVerifyMasterPasswordTitle => '验证主密码';

  @override
  String get securityVerifyMasterPasswordHint => '请输入主密码以开启生物识别';

  @override
  String get securityVerifyMasterPasswordConfirm => '验证并开启';

  @override
  String get securityCancel => '取消';

  @override
  String get settingsBackupDesc => '导出为独立解密文件或从文件恢复';

  @override
  String settingsBackupLastExport(Object date) {
    return '上次导出 $date';
  }

  @override
  String get settingsBackupUnbacked => '有未备份的更改';

  @override
  String get backupTitle => '加密备份';

  @override
  String get backupSensitiveBadge => '敏感页面';

  @override
  String get backupExportSection => '导出';

  @override
  String get backupExportSummaryTitle => '确认内容';

  @override
  String get backupExportSummaryDesc =>
      '全部账户、地址、标签、备份清单状态、全部密钥条目、设置。不包含余额缓存与快照。';

  @override
  String get backupExportIncludeExchange => '包含交易所 API Key';

  @override
  String get backupExportIncludeExchangeDesc =>
      '默认不包含。若勾选，将导出所有已连接交易所的 API Key 与 Secret';

  @override
  String get backupExportStartButton => '开始导出';

  @override
  String get backupRestoreSection => '恢复';

  @override
  String get backupRestoreRowTitle => '从备份文件恢复';

  @override
  String get backupRestoreRowDesc => '选择 .owbak 文件并输入备份密码';

  @override
  String get backupFormatNote => '备份格式是公开的。即使没有这个 app，也能用独立的解密工具在电脑上解开。';

  @override
  String get backupUnbackedWarning => '保险库在上次导出之后有变化，建议及时导出最新备份。';

  @override
  String get backupExportTitle => '导出备份';

  @override
  String get backupExportMasterPasswordTitle => '输入主密码';

  @override
  String get backupExportMasterPasswordDesc => '导出备份需要验证主密码，此处不接受面容或指纹';

  @override
  String get backupExportMasterPasswordHint => '请输入主密码';

  @override
  String get backupExportPasswordTypeTitle => '设置备份密码';

  @override
  String get backupExportUseMasterPassword => '使用主密码作为备份密码';

  @override
  String get backupExportUseCustomPassword => '另设备份密码';

  @override
  String get backupExportCustomPasswordHint => '输入备份密码（至少 10 位）';

  @override
  String get backupExportCustomPasswordConfirmHint => '确认备份密码';

  @override
  String get backupExportPasswordMismatch => '两次输入的备份密码不一致';

  @override
  String get backupExportPasswordTooShort => '备份密码长度至少为 10 个字符';

  @override
  String get backupExportAsciiNotice => '建议使用英文字母、数字和符号，避免在跨平台独立解密工具中出现编码差异';

  @override
  String get backupExportGenerating => '正在生成加密备份文件...';

  @override
  String get backupExportSuccessTitle => '备份已生成';

  @override
  String get backupExportSaveAdvice =>
      '通过系统分享面板保存。请存到手机以外的地方（如离线 U 盘、可信电脑或加密存储）。';

  @override
  String get backupExportSavedButton => '我已保存到安全位置';

  @override
  String get backupExportShareFailed => '导出或分享文件失败，请重试';

  @override
  String get backupExportDoneNotice => '上次导出时间已更新';

  @override
  String get backupRestoreTitle => '恢复备份';

  @override
  String get backupRestoreSelectFile => '选择 .owbak 备份文件';

  @override
  String backupRestoreSelectedFile(Object name, Object size) {
    return '已选文件：$name ($size)';
  }

  @override
  String get backupRestorePasswordHint => '请输入备份密码';

  @override
  String get backupRestoreParseButton => '解析备份文件';

  @override
  String get backupRestoreParsing => '正在解析备份文件...';

  @override
  String get backupRestorePreviewTitle => '备份内容预览';

  @override
  String backupRestoreCreatedAt(Object date) {
    return '创建时间：$date';
  }

  @override
  String backupRestoreAppVersion(Object version) {
    return '备份应用版本：$version';
  }

  @override
  String backupRestoreAccountsCount(Object count) {
    return '包含账户：$count 个';
  }

  @override
  String backupRestoreAddressesCount(Object count) {
    return '包含地址：$count 个';
  }

  @override
  String backupRestoreVaultItemsCount(Object count) {
    return '包含密钥条目：$count 个';
  }

  @override
  String backupRestoreCredentialsCount(Object count) {
    return '包含交易所凭据：$count 个';
  }

  @override
  String backupRestoreSkippedUnreadable(Object count) {
    return '有 $count 项数据格式无法读取，将被跳过';
  }

  @override
  String get backupRestoreModeFreshTitle => '全新设备恢复';

  @override
  String get backupRestoreModeFreshDesc => '将在本地创建新保险库并导入备份中所有数据。';

  @override
  String get backupRestoreModeMergeTitle => '合并导入';

  @override
  String get backupRestoreModeMergeDesc =>
      '将备份内容合并到当前数据中。相同条目与地址自动跳过，重名账户自动添加序号后缀。';

  @override
  String get backupRestoreMasterPasswordHint => '请输入本地保险库主密码';

  @override
  String get backupRestoreNewMasterPasswordHint => '为本机保险库设置主密码（至少 10 位）';

  @override
  String get backupRestoreSameAsBackupPassword => '沿用备份密码作为本机主密码';

  @override
  String get backupRestoreExecuteButton => '开始恢复';

  @override
  String get backupRestoreRestoring => '正在恢复数据...';

  @override
  String get backupRestoreResultTitle => '恢复完成';

  @override
  String backupRestoreResultAdded(
    Object accounts,
    Object addresses,
    Object items,
  ) {
    return '成功导入：$accounts 个账户、$addresses 个地址、$items 个密钥';
  }

  @override
  String backupRestoreResultSkipped(
    Object accounts,
    Object addresses,
    Object items,
  ) {
    return '跳过重复：$accounts 个账户、$addresses 个地址、$items 个密钥';
  }

  @override
  String get backupRestoreFinishButton => '完成';

  @override
  String get backupRestoreWrongPassword => '密码不正确或文件已损坏';

  @override
  String get backupRestoreCorrupted => '这不是 OneWallet 的备份文件，或文件已损坏，无法读取';

  @override
  String get backupRestoreUnsupportedVersion =>
      '这个备份文件来自更新版本的 OneWallet，当前版本无法读取';

  @override
  String get backupRestoreTargetNotEmpty => '本地已有数据，无法以初始模式恢复';

  @override
  String get backupUnbackedBanner => '保险库有未备份的更改，建议及时导出备份';

  @override
  String get backupGoBackup => '去备份';
}
