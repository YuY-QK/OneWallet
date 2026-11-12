import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('zh')];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'OneWallet'**
  String get appTitle;

  /// No description provided for @tabOverview.
  ///
  /// In zh, this message translates to:
  /// **'总览'**
  String get tabOverview;

  /// No description provided for @tabAccounts.
  ///
  /// In zh, this message translates to:
  /// **'账户'**
  String get tabAccounts;

  /// No description provided for @tabVault.
  ///
  /// In zh, this message translates to:
  /// **'保险库'**
  String get tabVault;

  /// No description provided for @tabSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get tabSettings;

  /// No description provided for @overviewEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'还没有账户'**
  String get overviewEmptyTitle;

  /// No description provided for @overviewEmptyBody.
  ///
  /// In zh, this message translates to:
  /// **'添加一个链上地址或交易所，就能在这里看到总资产。'**
  String get overviewEmptyBody;

  /// No description provided for @overviewEmptyAction.
  ///
  /// In zh, this message translates to:
  /// **'添加第一个账户'**
  String get overviewEmptyAction;

  /// No description provided for @accountsEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'还没有账户'**
  String get accountsEmptyTitle;

  /// No description provided for @accountsEmptyBody.
  ///
  /// In zh, this message translates to:
  /// **'钱包和交易所账户会显示在这里。'**
  String get accountsEmptyBody;

  /// No description provided for @vaultIntroTitle.
  ///
  /// In zh, this message translates to:
  /// **'保险库尚未启用'**
  String get vaultIntroTitle;

  /// No description provided for @vaultIntroBody.
  ///
  /// In zh, this message translates to:
  /// **'保险库把助记词和私钥加密保存在这台设备上，不会联网。'**
  String get vaultIntroBody;

  /// No description provided for @vaultIntroAction.
  ///
  /// In zh, this message translates to:
  /// **'启用保险库'**
  String get vaultIntroAction;

  /// No description provided for @notAvailableYet.
  ///
  /// In zh, this message translates to:
  /// **'此功能尚未实现'**
  String get notAvailableYet;

  /// No description provided for @bootstrapLoading.
  ///
  /// In zh, this message translates to:
  /// **'正在打开本地数据…'**
  String get bootstrapLoading;

  /// No description provided for @bootstrapErrorTitle.
  ///
  /// In zh, this message translates to:
  /// **'无法打开本地数据'**
  String get bootstrapErrorTitle;

  /// No description provided for @bootstrapErrorSecureStorage.
  ///
  /// In zh, this message translates to:
  /// **'无法访问系统安全存储。请确认设备已解锁后重试。'**
  String get bootstrapErrorSecureStorage;

  /// No description provided for @bootstrapErrorKeyMissing.
  ///
  /// In zh, this message translates to:
  /// **'本地数据库还在，但找不到它的密钥，可能是应用数据被清理或从备份恢复到了新设备。为避免丢失数据，应用不会自动重建数据库。'**
  String get bootstrapErrorKeyMissing;

  /// No description provided for @bootstrapErrorOpenFailed.
  ///
  /// In zh, this message translates to:
  /// **'本地数据库无法打开，文件可能已损坏。应用不会自动删除或重建它。请重试；仍然失败请联系开发者。'**
  String get bootstrapErrorOpenFailed;

  /// No description provided for @bootstrapRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get bootstrapRetry;

  /// No description provided for @timeJustNow.
  ///
  /// In zh, this message translates to:
  /// **'刚刚'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In zh, this message translates to:
  /// **'{minutes} 分钟前'**
  String timeMinutesAgo(int minutes);

  /// No description provided for @failureNetwork.
  ///
  /// In zh, this message translates to:
  /// **'网络不可用或请求超时。请检查网络连接后重试。'**
  String get failureNetwork;

  /// No description provided for @failureRateLimited.
  ///
  /// In zh, this message translates to:
  /// **'请求太频繁，被数据服务暂时限制了。请等一两分钟再刷新。'**
  String get failureRateLimited;

  /// No description provided for @failureUnauthorized.
  ///
  /// In zh, this message translates to:
  /// **'API Key 或 Secret 不正确，服务商拒绝了请求。请检查后重新填写。'**
  String get failureUnauthorized;

  /// No description provided for @failureKeyExpired.
  ///
  /// In zh, this message translates to:
  /// **'API Key 已失效，请到交易所重新创建并更换。'**
  String get failureKeyExpired;

  /// No description provided for @failureClockSkew.
  ///
  /// In zh, this message translates to:
  /// **'设备时间与服务器相差过大，请求被拒绝。请在系统设置中开启自动校时后重试。'**
  String get failureClockSkew;

  /// No description provided for @failureServiceDown.
  ///
  /// In zh, this message translates to:
  /// **'数据服务暂时出了问题。请稍后重试，已有的数据不受影响。'**
  String get failureServiceDown;

  /// No description provided for @failureValidation.
  ///
  /// In zh, this message translates to:
  /// **'输入的内容格式不正确。请检查后重新输入。'**
  String get failureValidation;

  /// No description provided for @failureWrongPassword.
  ///
  /// In zh, this message translates to:
  /// **'密码不正确。请重新输入。'**
  String get failureWrongPassword;

  /// No description provided for @failureUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'当前设备不支持这个功能。'**
  String get failureUnsupported;

  /// No description provided for @failureUnknown.
  ///
  /// In zh, this message translates to:
  /// **'出现了未知问题。请稍后重试，反复出现时可在「同步状态」中查看记录。'**
  String get failureUnknown;

  /// No description provided for @failureDuplicateAddress.
  ///
  /// In zh, this message translates to:
  /// **'{kind, select, existing{地址 {address} 已在账户「{account}」中，同一地址不能重复添加。} other{地址 {address} 在本次输入中出现了不止一次，请删除重复的一项。}}'**
  String failureDuplicateAddress(String kind, String address, String account);

  /// No description provided for @walletSourceUniswap.
  ///
  /// In zh, this message translates to:
  /// **'Uniswap Wallet'**
  String get walletSourceUniswap;

  /// No description provided for @walletSourceMetamask.
  ///
  /// In zh, this message translates to:
  /// **'MetaMask'**
  String get walletSourceMetamask;

  /// No description provided for @walletSourceOkxWeb3.
  ///
  /// In zh, this message translates to:
  /// **'OKX Web3'**
  String get walletSourceOkxWeb3;

  /// No description provided for @walletSourceBitgetWallet.
  ///
  /// In zh, this message translates to:
  /// **'Bitget Wallet'**
  String get walletSourceBitgetWallet;

  /// No description provided for @walletSourceTrustWallet.
  ///
  /// In zh, this message translates to:
  /// **'Trust Wallet'**
  String get walletSourceTrustWallet;

  /// No description provided for @walletSourceOther.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get walletSourceOther;

  /// No description provided for @exchangeBinance.
  ///
  /// In zh, this message translates to:
  /// **'Binance'**
  String get exchangeBinance;

  /// No description provided for @exchangeOkx.
  ///
  /// In zh, this message translates to:
  /// **'OKX'**
  String get exchangeOkx;

  /// No description provided for @exchangeBybit.
  ///
  /// In zh, this message translates to:
  /// **'Bybit'**
  String get exchangeBybit;

  /// No description provided for @exchangeBitget.
  ///
  /// In zh, this message translates to:
  /// **'Bitget'**
  String get exchangeBitget;

  /// No description provided for @chainFamilyEvm.
  ///
  /// In zh, this message translates to:
  /// **'EVM'**
  String get chainFamilyEvm;

  /// No description provided for @chainFamilyBitcoin.
  ///
  /// In zh, this message translates to:
  /// **'Bitcoin'**
  String get chainFamilyBitcoin;

  /// No description provided for @chainFamilySolana.
  ///
  /// In zh, this message translates to:
  /// **'Solana'**
  String get chainFamilySolana;

  /// No description provided for @chainFamilyTron.
  ///
  /// In zh, this message translates to:
  /// **'Tron'**
  String get chainFamilyTron;

  /// No description provided for @backupStatusInVault.
  ///
  /// In zh, this message translates to:
  /// **'已入库'**
  String get backupStatusInVault;

  /// No description provided for @backupStatusOffline.
  ///
  /// In zh, this message translates to:
  /// **'已离线备份'**
  String get backupStatusOffline;

  /// No description provided for @backupStatusInVaultAndOffline.
  ///
  /// In zh, this message translates to:
  /// **'已入库并离线备份'**
  String get backupStatusInVaultAndOffline;

  /// No description provided for @backupStatusKeyless.
  ///
  /// In zh, this message translates to:
  /// **'无助记词钱包'**
  String get backupStatusKeyless;

  /// No description provided for @backupStatusNone.
  ///
  /// In zh, this message translates to:
  /// **'未备份'**
  String get backupStatusNone;

  /// No description provided for @syncFailureUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'暂不支持：这类地址的余额读取将在后续版本提供，已有数据不受影响。'**
  String get syncFailureUnsupported;

  /// No description provided for @comingSoonTitle.
  ///
  /// In zh, this message translates to:
  /// **'即将推出'**
  String get comingSoonTitle;

  /// No description provided for @comingSoonBody.
  ///
  /// In zh, this message translates to:
  /// **'此功能将在后续版本提供。'**
  String get comingSoonBody;

  /// No description provided for @accountAddTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加账户'**
  String get accountAddTitle;

  /// No description provided for @accountAddWatchTitle.
  ///
  /// In zh, this message translates to:
  /// **'观察链上地址'**
  String get accountAddWatchTitle;

  /// No description provided for @accountAddWatchBody.
  ///
  /// In zh, this message translates to:
  /// **'只需粘贴地址，不需要私钥'**
  String get accountAddWatchBody;

  /// No description provided for @accountAddExchangeTitle.
  ///
  /// In zh, this message translates to:
  /// **'连接交易所'**
  String get accountAddExchangeTitle;

  /// No description provided for @accountAddExchangeBody.
  ///
  /// In zh, this message translates to:
  /// **'使用只读 API Key'**
  String get accountAddExchangeBody;

  /// No description provided for @accountAddImportTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入助记词或私钥'**
  String get accountAddImportTitle;

  /// No description provided for @accountAddImportBody.
  ///
  /// In zh, this message translates to:
  /// **'存入加密保险库，并自动生成观察地址'**
  String get accountAddImportBody;

  /// No description provided for @walletAddTitle.
  ///
  /// In zh, this message translates to:
  /// **'观察链上地址'**
  String get walletAddTitle;

  /// No description provided for @walletAddExtraTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加地址'**
  String get walletAddExtraTitle;

  /// No description provided for @walletAddName.
  ///
  /// In zh, this message translates to:
  /// **'账户名称'**
  String get walletAddName;

  /// No description provided for @walletAddNameHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：主钱包'**
  String get walletAddNameHint;

  /// No description provided for @walletAddNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入账户名称，最多 30 个字。'**
  String get walletAddNameRequired;

  /// No description provided for @walletAddSource.
  ///
  /// In zh, this message translates to:
  /// **'来源钱包'**
  String get walletAddSource;

  /// No description provided for @walletAddAddress.
  ///
  /// In zh, this message translates to:
  /// **'地址'**
  String get walletAddAddress;

  /// No description provided for @walletAddAddressN.
  ///
  /// In zh, this message translates to:
  /// **'地址 {n}'**
  String walletAddAddressN(int n);

  /// No description provided for @walletAddAddressHint.
  ///
  /// In zh, this message translates to:
  /// **'粘贴要观察的地址'**
  String get walletAddAddressHint;

  /// No description provided for @walletAddAddressRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入地址。'**
  String get walletAddAddressRequired;

  /// No description provided for @walletAddPaste.
  ///
  /// In zh, this message translates to:
  /// **'粘贴'**
  String get walletAddPaste;

  /// No description provided for @walletAddClipboardEmpty.
  ///
  /// In zh, this message translates to:
  /// **'剪贴板里没有文字。'**
  String get walletAddClipboardEmpty;

  /// No description provided for @walletAddRecognized.
  ///
  /// In zh, this message translates to:
  /// **'识别为 {family} 地址'**
  String walletAddRecognized(String family);

  /// No description provided for @walletAddUnrecognized.
  ///
  /// In zh, this message translates to:
  /// **'无法识别的地址格式。请检查是否复制完整。'**
  String get walletAddUnrecognized;

  /// No description provided for @walletAddChains.
  ///
  /// In zh, this message translates to:
  /// **'链（可多选）'**
  String get walletAddChains;

  /// No description provided for @walletAddChainAuto.
  ///
  /// In zh, this message translates to:
  /// **'链：{chain}（自动确定）'**
  String walletAddChainAuto(String chain);

  /// No description provided for @walletAddChainRequired.
  ///
  /// In zh, this message translates to:
  /// **'至少选择一条链。'**
  String get walletAddChainRequired;

  /// No description provided for @walletAddAnother.
  ///
  /// In zh, this message translates to:
  /// **'再添加一个地址'**
  String get walletAddAnother;

  /// No description provided for @walletAddRemove.
  ///
  /// In zh, this message translates to:
  /// **'删除这个地址'**
  String get walletAddRemove;

  /// No description provided for @walletAddBackup.
  ///
  /// In zh, this message translates to:
  /// **'备份状态'**
  String get walletAddBackup;

  /// No description provided for @walletAddBackupNone.
  ///
  /// In zh, this message translates to:
  /// **'未备份'**
  String get walletAddBackupNone;

  /// No description provided for @walletAddBackupOffline.
  ///
  /// In zh, this message translates to:
  /// **'已离线备份'**
  String get walletAddBackupOffline;

  /// No description provided for @walletAddBackupKeyless.
  ///
  /// In zh, this message translates to:
  /// **'无助记词钱包'**
  String get walletAddBackupKeyless;

  /// No description provided for @walletAddSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get walletAddSave;

  /// No description provided for @walletAddSaving.
  ///
  /// In zh, this message translates to:
  /// **'保存中…'**
  String get walletAddSaving;

  /// No description provided for @walletAddAccountMissing.
  ///
  /// In zh, this message translates to:
  /// **'找不到这个账户，它可能已被删除。'**
  String get walletAddAccountMissing;

  /// No description provided for @walletAddKeyMissing.
  ///
  /// In zh, this message translates to:
  /// **'尚未配置 Alchemy Key，EVM 地址的余额可能查不到。可在「设置 → 数据源」中填写。'**
  String get walletAddKeyMissing;

  /// No description provided for @overviewHideAmounts.
  ///
  /// In zh, this message translates to:
  /// **'隐藏金额'**
  String get overviewHideAmounts;

  /// No description provided for @overviewShowAmounts.
  ///
  /// In zh, this message translates to:
  /// **'显示金额'**
  String get overviewShowAmounts;

  /// No description provided for @overviewAddAccount.
  ///
  /// In zh, this message translates to:
  /// **'添加账户'**
  String get overviewAddAccount;

  /// No description provided for @overviewTotalLabel.
  ///
  /// In zh, this message translates to:
  /// **'总资产（{quote}）'**
  String overviewTotalLabel(String quote);

  /// No description provided for @overviewChange24h.
  ///
  /// In zh, this message translates to:
  /// **'24 小时'**
  String get overviewChange24h;

  /// No description provided for @overviewChangeUnknown.
  ///
  /// In zh, this message translates to:
  /// **'24 小时变化 —'**
  String get overviewChangeUnknown;

  /// No description provided for @overviewLastSynced.
  ///
  /// In zh, this message translates to:
  /// **'上次同步 {time}'**
  String overviewLastSynced(String time);

  /// No description provided for @overviewNeverSynced.
  ///
  /// In zh, this message translates to:
  /// **'尚未同步'**
  String get overviewNeverSynced;

  /// No description provided for @overviewDistCoin.
  ///
  /// In zh, this message translates to:
  /// **'按币种'**
  String get overviewDistCoin;

  /// No description provided for @overviewDistAccount.
  ///
  /// In zh, this message translates to:
  /// **'按账户'**
  String get overviewDistAccount;

  /// No description provided for @overviewDistType.
  ///
  /// In zh, this message translates to:
  /// **'按类型'**
  String get overviewDistType;

  /// No description provided for @overviewTypeOnChain.
  ///
  /// In zh, this message translates to:
  /// **'链上钱包'**
  String get overviewTypeOnChain;

  /// No description provided for @overviewTypeExchange.
  ///
  /// In zh, this message translates to:
  /// **'交易所'**
  String get overviewTypeExchange;

  /// No description provided for @overviewDistEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂时没有可显示的资产。'**
  String get overviewDistEmpty;

  /// No description provided for @overviewFooterUnpriced.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个币种无估值'**
  String overviewFooterUnpriced(int count);

  /// No description provided for @overviewFooterHidden.
  ///
  /// In zh, this message translates to:
  /// **'已隐藏 {count} 个小额币种'**
  String overviewFooterHidden(int count);

  /// No description provided for @overviewSyncingLabel.
  ///
  /// In zh, this message translates to:
  /// **'正在同步'**
  String get overviewSyncingLabel;

  /// No description provided for @overviewPartialFailed.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个账户同步失败'**
  String overviewPartialFailed(int count);

  /// No description provided for @overviewOffline.
  ///
  /// In zh, this message translates to:
  /// **'当前离线，显示的是 {time} 的数据'**
  String overviewOffline(String time);

  /// No description provided for @overviewAllFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'同步失败'**
  String get overviewAllFailedTitle;

  /// No description provided for @overviewAllFailedBody.
  ///
  /// In zh, this message translates to:
  /// **'所有账户都没能同步，也没有可显示的缓存数据。请检查数据源设置后重试。'**
  String get overviewAllFailedBody;

  /// No description provided for @overviewRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get overviewRetry;

  /// No description provided for @overviewFailureListTitle.
  ///
  /// In zh, this message translates to:
  /// **'同步失败的账户'**
  String get overviewFailureListTitle;

  /// No description provided for @overviewFailureClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get overviewFailureClose;

  /// No description provided for @accountsAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加账户'**
  String get accountsAdd;

  /// No description provided for @accountsGroupWallet.
  ///
  /// In zh, this message translates to:
  /// **'钱包'**
  String get accountsGroupWallet;

  /// No description provided for @accountsGroupExchange.
  ///
  /// In zh, this message translates to:
  /// **'交易所'**
  String get accountsGroupExchange;

  /// No description provided for @accountsSyncFailed.
  ///
  /// In zh, this message translates to:
  /// **'同步失败'**
  String get accountsSyncFailed;

  /// No description provided for @accountsLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法读取账户列表。请重启应用后重试。'**
  String get accountsLoadFailed;

  /// No description provided for @accountsSelectHint.
  ///
  /// In zh, this message translates to:
  /// **'选择一个账户查看详情。'**
  String get accountsSelectHint;

  /// No description provided for @walletDetailTotal.
  ///
  /// In zh, this message translates to:
  /// **'账户总估值'**
  String get walletDetailTotal;

  /// No description provided for @walletDetailTabAssets.
  ///
  /// In zh, this message translates to:
  /// **'资产'**
  String get walletDetailTabAssets;

  /// No description provided for @walletDetailTabAddresses.
  ///
  /// In zh, this message translates to:
  /// **'地址'**
  String get walletDetailTabAddresses;

  /// No description provided for @walletDetailNoAssets.
  ///
  /// In zh, this message translates to:
  /// **'该钱包目前没有可显示的资产'**
  String get walletDetailNoAssets;

  /// No description provided for @walletDetailNotFound.
  ///
  /// In zh, this message translates to:
  /// **'找不到这个账户，它可能已被删除。'**
  String get walletDetailNotFound;

  /// No description provided for @walletDetailFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'同步失败'**
  String get walletDetailFailedTitle;

  /// No description provided for @walletDetailLastSuccess.
  ///
  /// In zh, this message translates to:
  /// **'上次成功同步：{time}'**
  String walletDetailLastSuccess(String time);

  /// No description provided for @walletDetailNeverSucceeded.
  ///
  /// In zh, this message translates to:
  /// **'还没有成功同步过，下面没有缓存数据。'**
  String get walletDetailNeverSucceeded;

  /// No description provided for @walletDetailUnpriced.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个未识别或无估值的币种'**
  String walletDetailUnpriced(int count);

  /// No description provided for @walletDetailAddAddress.
  ///
  /// In zh, this message translates to:
  /// **'添加地址'**
  String get walletDetailAddAddress;

  /// No description provided for @walletDetailAddressesHint.
  ///
  /// In zh, this message translates to:
  /// **'点击地址可查看二维码、复制、在浏览器中打开'**
  String get walletDetailAddressesHint;

  /// No description provided for @walletDetailChainCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 条链'**
  String walletDetailChainCount(int count);

  /// No description provided for @addressSheetTitle.
  ///
  /// In zh, this message translates to:
  /// **'{family} 地址'**
  String addressSheetTitle(String family);

  /// No description provided for @addressSheetCopy.
  ///
  /// In zh, this message translates to:
  /// **'复制地址'**
  String get addressSheetCopy;

  /// No description provided for @addressSheetCopied.
  ///
  /// In zh, this message translates to:
  /// **'已复制'**
  String get addressSheetCopied;

  /// No description provided for @addressSheetExplorerHeader.
  ///
  /// In zh, this message translates to:
  /// **'在区块浏览器中打开'**
  String get addressSheetExplorerHeader;

  /// No description provided for @addressSheetExplorerRow.
  ///
  /// In zh, this message translates to:
  /// **'{chain} · {host}'**
  String addressSheetExplorerRow(String chain, String host);

  /// No description provided for @addressSheetExplorerNote.
  ///
  /// In zh, this message translates to:
  /// **'将用系统浏览器打开所示网站，请确认域名无误。'**
  String get addressSheetExplorerNote;

  /// No description provided for @addressSheetOpenFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法打开系统浏览器。'**
  String get addressSheetOpenFailed;

  /// No description provided for @addressSheetDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除地址'**
  String get addressSheetDelete;

  /// No description provided for @addressSheetDeleteLast.
  ///
  /// In zh, this message translates to:
  /// **'账户至少要保留一个地址，所以不能删除最后一个地址。'**
  String get addressSheetDeleteLast;

  /// No description provided for @addressSheetDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除这个地址？'**
  String get addressSheetDeleteTitle;

  /// No description provided for @addressSheetDeleteBody.
  ///
  /// In zh, this message translates to:
  /// **'删除后，这个地址的余额缓存也会清除；链上资产不受影响，之后可以重新添加。'**
  String get addressSheetDeleteBody;

  /// No description provided for @addressSheetCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get addressSheetCancel;

  /// No description provided for @settingsSectionData.
  ///
  /// In zh, this message translates to:
  /// **'数据'**
  String get settingsSectionData;

  /// No description provided for @settingsSources.
  ///
  /// In zh, this message translates to:
  /// **'数据源'**
  String get settingsSources;

  /// No description provided for @settingsSourcesBody.
  ///
  /// In zh, this message translates to:
  /// **'配置链上数据与价格服务的 API Key'**
  String get settingsSourcesBody;

  /// No description provided for @sourcesTitle.
  ///
  /// In zh, this message translates to:
  /// **'数据源'**
  String get sourcesTitle;

  /// No description provided for @sourcesAlchemyName.
  ///
  /// In zh, this message translates to:
  /// **'Alchemy'**
  String get sourcesAlchemyName;

  /// No description provided for @sourcesAlchemyBody.
  ///
  /// In zh, this message translates to:
  /// **'EVM 六条链的余额'**
  String get sourcesAlchemyBody;

  /// No description provided for @sourcesCoingeckoName.
  ///
  /// In zh, this message translates to:
  /// **'CoinGecko'**
  String get sourcesCoingeckoName;

  /// No description provided for @sourcesCoingeckoBody.
  ///
  /// In zh, this message translates to:
  /// **'价格（Key 可选）'**
  String get sourcesCoingeckoBody;

  /// No description provided for @sourcesComingSoon.
  ///
  /// In zh, this message translates to:
  /// **'即将支持'**
  String get sourcesComingSoon;

  /// No description provided for @sourcesConfigured.
  ///
  /// In zh, this message translates to:
  /// **'已配置'**
  String get sourcesConfigured;

  /// No description provided for @sourcesNotConfigured.
  ///
  /// In zh, this message translates to:
  /// **'未配置'**
  String get sourcesNotConfigured;

  /// No description provided for @sourcesConfiguredPreview.
  ///
  /// In zh, this message translates to:
  /// **'已配置 · {preview}'**
  String sourcesConfiguredPreview(String preview);

  /// No description provided for @sourcesPrivacy.
  ///
  /// In zh, this message translates to:
  /// **'查询余额时，你的地址和 IP 会被发送给所选的数据服务商。'**
  String get sourcesPrivacy;

  /// No description provided for @sourcesEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'{name} 设置'**
  String sourcesEditTitle(String name);

  /// No description provided for @sourcesKeyLabel.
  ///
  /// In zh, this message translates to:
  /// **'API Key'**
  String get sourcesKeyLabel;

  /// No description provided for @sourcesKeyHint.
  ///
  /// In zh, this message translates to:
  /// **'粘贴 API Key'**
  String get sourcesKeyHint;

  /// No description provided for @sourcesKeyHintReplace.
  ///
  /// In zh, this message translates to:
  /// **'输入新的 Key 以替换已保存的'**
  String get sourcesKeyHintReplace;

  /// No description provided for @sourcesKeyShow.
  ///
  /// In zh, this message translates to:
  /// **'显示'**
  String get sourcesKeyShow;

  /// No description provided for @sourcesKeyHide.
  ///
  /// In zh, this message translates to:
  /// **'隐藏'**
  String get sourcesKeyHide;

  /// No description provided for @sourcesKeyEmpty.
  ///
  /// In zh, this message translates to:
  /// **'请输入 API Key。'**
  String get sourcesKeyEmpty;

  /// No description provided for @sourcesAlchemyRequired.
  ///
  /// In zh, this message translates to:
  /// **'读取 EVM 余额需要 Alchemy 的 API Key。'**
  String get sourcesAlchemyRequired;

  /// No description provided for @sourcesCoingeckoOptional.
  ///
  /// In zh, this message translates to:
  /// **'CoinGecko 的 Key 可不填，但免费额度较紧，价格刷新可能被限频。'**
  String get sourcesCoingeckoOptional;

  /// No description provided for @sourcesSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get sourcesSave;

  /// No description provided for @sourcesSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get sourcesSaved;

  /// No description provided for @sourcesClear.
  ///
  /// In zh, this message translates to:
  /// **'清除 Key'**
  String get sourcesClear;

  /// No description provided for @sourcesTest.
  ///
  /// In zh, this message translates to:
  /// **'测试连接'**
  String get sourcesTest;

  /// No description provided for @sourcesTesting.
  ///
  /// In zh, this message translates to:
  /// **'正在测试…'**
  String get sourcesTesting;

  /// No description provided for @sourcesTestSaveFirst.
  ///
  /// In zh, this message translates to:
  /// **'输入的 Key 还没有保存。请先保存，再测试连接。'**
  String get sourcesTestSaveFirst;

  /// No description provided for @sourcesTestOk.
  ///
  /// In zh, this message translates to:
  /// **'连接正常。'**
  String get sourcesTestOk;

  /// No description provided for @sourcesAdvanced.
  ///
  /// In zh, this message translates to:
  /// **'高级：自定义 RPC 端点'**
  String get sourcesAdvanced;

  /// No description provided for @sourcesEndpointNote.
  ///
  /// In zh, this message translates to:
  /// **'自定义端点会收到你的地址与 IP，请只填写可信的服务。'**
  String get sourcesEndpointNote;

  /// No description provided for @sourcesEndpointHint.
  ///
  /// In zh, this message translates to:
  /// **'https://…'**
  String get sourcesEndpointHint;

  /// No description provided for @sourcesEndpointInvalid.
  ///
  /// In zh, this message translates to:
  /// **'只接受 https 地址，且不能包含用户名或密码。'**
  String get sourcesEndpointInvalid;

  /// No description provided for @sourcesEndpointSet.
  ///
  /// In zh, this message translates to:
  /// **'已设置自定义端点：{host}'**
  String sourcesEndpointSet(String host);

  /// No description provided for @sourcesEndpointDefault.
  ///
  /// In zh, this message translates to:
  /// **'使用默认端点'**
  String get sourcesEndpointDefault;

  /// No description provided for @sourcesEndpointSave.
  ///
  /// In zh, this message translates to:
  /// **'保存端点'**
  String get sourcesEndpointSave;

  /// No description provided for @sourcesEndpointClear.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认'**
  String get sourcesEndpointClear;

  /// No description provided for @sourcesDone.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get sourcesDone;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
