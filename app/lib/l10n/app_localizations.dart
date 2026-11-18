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

  /// No description provided for @failureVaultCorrupted.
  ///
  /// In zh, this message translates to:
  /// **'保险库文件已损坏或被改动，无法读取。请不要删除它，可用加密备份恢复。'**
  String get failureVaultCorrupted;

  /// No description provided for @failureVaultVersionUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'这个保险库文件来自更新版本的 OneWallet，当前版本无法读取。请先升级应用，文件未被改动。'**
  String get failureVaultVersionUnsupported;

  /// No description provided for @failureVaultNotFound.
  ///
  /// In zh, this message translates to:
  /// **'找不到保险库文件。如果之前创建过保险库，请用加密备份恢复。'**
  String get failureVaultNotFound;

  /// No description provided for @failureVaultAlreadyExists.
  ///
  /// In zh, this message translates to:
  /// **'保险库已经存在，不能重复创建。'**
  String get failureVaultAlreadyExists;

  /// No description provided for @failureVaultItemNotFound.
  ///
  /// In zh, this message translates to:
  /// **'保险库中找不到这个密钥，它可能已被删除。'**
  String get failureVaultItemNotFound;

  /// No description provided for @failureBackupCorrupted.
  ///
  /// In zh, this message translates to:
  /// **'这不是 OneWallet 的备份文件，或文件已损坏，无法读取。请换一份备份文件再试。'**
  String get failureBackupCorrupted;

  /// No description provided for @failureBackupVersionUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'这个备份文件来自更新版本的 OneWallet，当前版本无法读取。请先升级应用再恢复。'**
  String get failureBackupVersionUnsupported;

  /// No description provided for @failureUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'当前设备不支持这个功能。'**
  String get failureUnsupported;

  /// No description provided for @failureUnsupportedNotIntegrated.
  ///
  /// In zh, this message translates to:
  /// **'暂不支持这条链或这家交易所，将在后续版本提供，已有数据不受影响。'**
  String get failureUnsupportedNotIntegrated;

  /// No description provided for @failureUnknown.
  ///
  /// In zh, this message translates to:
  /// **'出现了未知问题。请稍后重试，反复出现时可在「同步状态」中查看记录。'**
  String get failureUnknown;

  /// No description provided for @failureDuplicateAddress.
  ///
  /// In zh, this message translates to:
  /// **'{kind, select, existing{地址 {address} 已在账户「{account}」中，同一地址不能重复添加。} ownerMissing{该地址已存在于本应用中。} other{地址 {address} 在本次输入中出现了不止一次，请删除重复的一项。}}'**
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

  /// No description provided for @accountsSyncing.
  ///
  /// In zh, this message translates to:
  /// **'同步中'**
  String get accountsSyncing;

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

  /// No description provided for @addressSheetExcludedBtc.
  ///
  /// In zh, this message translates to:
  /// **'口径说明：只含已确认余额，未确认交易不计入。'**
  String get addressSheetExcludedBtc;

  /// No description provided for @addressSheetExcludedSol.
  ///
  /// In zh, this message translates to:
  /// **'口径说明：不含质押在验证者上的 SOL 与 NFT。'**
  String get addressSheetExcludedSol;

  /// No description provided for @addressSheetExcludedTron.
  ///
  /// In zh, this message translates to:
  /// **'口径说明：不含 Stake 1.0 质押与未领取的投票奖励。'**
  String get addressSheetExcludedTron;

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

  /// No description provided for @settingsSync.
  ///
  /// In zh, this message translates to:
  /// **'同步状态'**
  String get settingsSync;

  /// No description provided for @settingsSyncBody.
  ///
  /// In zh, this message translates to:
  /// **'各账户同步情况与日志'**
  String get settingsSyncBody;

  /// No description provided for @settingsSyncFailedCount.
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, other{{count} 个账户失败}}'**
  String settingsSyncFailedCount(int count);

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

  /// No description provided for @sourcesMempoolName.
  ///
  /// In zh, this message translates to:
  /// **'mempool.space'**
  String get sourcesMempoolName;

  /// No description provided for @sourcesMempoolBody.
  ///
  /// In zh, this message translates to:
  /// **'Bitcoin · 只含已确认余额'**
  String get sourcesMempoolBody;

  /// No description provided for @sourcesHeliusName.
  ///
  /// In zh, this message translates to:
  /// **'Helius'**
  String get sourcesHeliusName;

  /// No description provided for @sourcesHeliusBody.
  ///
  /// In zh, this message translates to:
  /// **'Solana · 不含质押在验证者上的 SOL 与 NFT'**
  String get sourcesHeliusBody;

  /// No description provided for @sourcesTrongridName.
  ///
  /// In zh, this message translates to:
  /// **'TronGrid'**
  String get sourcesTrongridName;

  /// No description provided for @sourcesTrongridBody.
  ///
  /// In zh, this message translates to:
  /// **'Tron · 不含 Stake 1.0 与未领取的奖励'**
  String get sourcesTrongridBody;

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

  /// No description provided for @sourcesMempoolRequired.
  ///
  /// In zh, this message translates to:
  /// **'mempool.space 公共实例无需 API Key。如需自建实例，可在下方配置自定义端点。'**
  String get sourcesMempoolRequired;

  /// No description provided for @sourcesHeliusRequired.
  ///
  /// In zh, this message translates to:
  /// **'Solana 余额与代币查询；未配置时使用公共节点（限制较严）。'**
  String get sourcesHeliusRequired;

  /// No description provided for @sourcesTrongridRequired.
  ///
  /// In zh, this message translates to:
  /// **'Tron 余额与 TRC-20 查询；未配置时易受限频。'**
  String get sourcesTrongridRequired;

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

  /// No description provided for @sourcesCoingeckoAttribution.
  ///
  /// In zh, this message translates to:
  /// **'价格数据来自 CoinGecko'**
  String get sourcesCoingeckoAttribution;

  /// No description provided for @externalLinkConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'即将离开 OneWallet'**
  String get externalLinkConfirmTitle;

  /// No description provided for @externalLinkConfirmBody.
  ///
  /// In zh, this message translates to:
  /// **'将用系统浏览器打开以下网址，请核对域名：\n\n{url}'**
  String externalLinkConfirmBody(String url);

  /// No description provided for @externalLinkConfirmOpen.
  ///
  /// In zh, this message translates to:
  /// **'继续访问'**
  String get externalLinkConfirmOpen;

  /// No description provided for @externalLinkCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get externalLinkCancel;

  /// No description provided for @directoryLinkWebsite.
  ///
  /// In zh, this message translates to:
  /// **'官网'**
  String get directoryLinkWebsite;

  /// No description provided for @directoryLinkDocs.
  ///
  /// In zh, this message translates to:
  /// **'帮助文档'**
  String get directoryLinkDocs;

  /// No description provided for @directoryLinkApiKey.
  ///
  /// In zh, this message translates to:
  /// **'获取 API Key'**
  String get directoryLinkApiKey;

  /// No description provided for @walletAddSourceSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索钱包…'**
  String get walletAddSourceSearch;

  /// No description provided for @walletAddSourceOther.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get walletAddSourceOther;

  /// No description provided for @exchangeAddTitle.
  ///
  /// In zh, this message translates to:
  /// **'连接交易所'**
  String get exchangeAddTitle;

  /// No description provided for @exchangeReplaceKeyTitle.
  ///
  /// In zh, this message translates to:
  /// **'更换 API Key'**
  String get exchangeReplaceKeyTitle;

  /// No description provided for @exchangeAddExchange.
  ///
  /// In zh, this message translates to:
  /// **'交易所'**
  String get exchangeAddExchange;

  /// No description provided for @exchangeAddAccountName.
  ///
  /// In zh, this message translates to:
  /// **'账户名称'**
  String get exchangeAddAccountName;

  /// No description provided for @exchangeAddAccountNameHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：Binance 主账户'**
  String get exchangeAddAccountNameHint;

  /// No description provided for @exchangeAddAccountNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入账户名称，最多 30 个字。'**
  String get exchangeAddAccountNameRequired;

  /// No description provided for @exchangeAddApiKey.
  ///
  /// In zh, this message translates to:
  /// **'API Key'**
  String get exchangeAddApiKey;

  /// No description provided for @exchangeAddApiKeyHint.
  ///
  /// In zh, this message translates to:
  /// **'粘贴或输入 API Key'**
  String get exchangeAddApiKeyHint;

  /// No description provided for @exchangeAddApiKeyRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入 API Key。'**
  String get exchangeAddApiKeyRequired;

  /// No description provided for @exchangeAddApiSecret.
  ///
  /// In zh, this message translates to:
  /// **'API Secret'**
  String get exchangeAddApiSecret;

  /// No description provided for @exchangeAddApiSecretHint.
  ///
  /// In zh, this message translates to:
  /// **'粘贴或输入 API Secret'**
  String get exchangeAddApiSecretHint;

  /// No description provided for @exchangeAddApiSecretRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入 API Secret。'**
  String get exchangeAddApiSecretRequired;

  /// No description provided for @exchangeAddPassphrase.
  ///
  /// In zh, this message translates to:
  /// **'Passphrase'**
  String get exchangeAddPassphrase;

  /// No description provided for @exchangeAddPassphraseHint.
  ///
  /// In zh, this message translates to:
  /// **'创建 API Key 时设置的口令'**
  String get exchangeAddPassphraseHint;

  /// No description provided for @exchangeAddPassphraseRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入 Passphrase。'**
  String get exchangeAddPassphraseRequired;

  /// No description provided for @exchangeAddPaste.
  ///
  /// In zh, this message translates to:
  /// **'粘贴'**
  String get exchangeAddPaste;

  /// No description provided for @exchangeAddSecurityNote.
  ///
  /// In zh, this message translates to:
  /// **'请只勾选「读取」权限，不要开启交易和提现。保存前会检查这个 Key 的权限。'**
  String get exchangeAddSecurityNote;

  /// No description provided for @exchangeAddGuideTitle.
  ///
  /// In zh, this message translates to:
  /// **'如何创建只读 API Key'**
  String get exchangeAddGuideTitle;

  /// No description provided for @exchangeAddGuideSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'分步图文与官方指引'**
  String get exchangeAddGuideSubtitle;

  /// No description provided for @exchangeAddGuideOfficialLink.
  ///
  /// In zh, this message translates to:
  /// **'前往官方创建指引'**
  String get exchangeAddGuideOfficialLink;

  /// No description provided for @exchangeAddGuideApiManagementLink.
  ///
  /// In zh, this message translates to:
  /// **'前往 API 管理'**
  String get exchangeAddGuideApiManagementLink;

  /// No description provided for @exchangeAddTestAndSave.
  ///
  /// In zh, this message translates to:
  /// **'测试并保存'**
  String get exchangeAddTestAndSave;

  /// No description provided for @exchangeAddVerifying.
  ///
  /// In zh, this message translates to:
  /// **'正在验证凭据…'**
  String get exchangeAddVerifying;

  /// No description provided for @exchangeAddSaving.
  ///
  /// In zh, this message translates to:
  /// **'正在保存…'**
  String get exchangeAddSaving;

  /// No description provided for @exchangeAddComingSoon.
  ///
  /// In zh, this message translates to:
  /// **'即将支持'**
  String get exchangeAddComingSoon;

  /// No description provided for @exchangeAddBitgetNotice.
  ///
  /// In zh, this message translates to:
  /// **'Bitget 暂未接入，即将支持。'**
  String get exchangeAddBitgetNotice;

  /// No description provided for @exchangeAddPermWarningTitle.
  ///
  /// In zh, this message translates to:
  /// **'权限超出只读'**
  String get exchangeAddPermWarningTitle;

  /// No description provided for @exchangeAddPermWarningBody.
  ///
  /// In zh, this message translates to:
  /// **'检测到此 Key 包含交易或提现权限，存在资金安全风险。建议在交易所后台重新创建只读 Key。'**
  String get exchangeAddPermWarningBody;

  /// No description provided for @exchangeAddPermWarningModify.
  ///
  /// In zh, this message translates to:
  /// **'返回修改'**
  String get exchangeAddPermWarningModify;

  /// No description provided for @exchangeAddPermWarningProceed.
  ///
  /// In zh, this message translates to:
  /// **'仍然保存'**
  String get exchangeAddPermWarningProceed;

  /// No description provided for @exchangeAddErrCredential.
  ///
  /// In zh, this message translates to:
  /// **'API Key、Secret 或 Passphrase 不正确，服务商拒绝了请求。'**
  String get exchangeAddErrCredential;

  /// No description provided for @exchangeAddErrNetwork.
  ///
  /// In zh, this message translates to:
  /// **'网络不可用或请求超时。请检查网络连接后重试。'**
  String get exchangeAddErrNetwork;

  /// No description provided for @exchangeAddErrClockSkew.
  ///
  /// In zh, this message translates to:
  /// **'设备时间与服务器相差过大，请求被拒绝。请在系统设置中开启自动校时后重试。'**
  String get exchangeAddErrClockSkew;

  /// No description provided for @exchangeAddErrIpRestricted.
  ///
  /// In zh, this message translates to:
  /// **'该 API Key 限制了访问 IP，请检查交易所后台的 IP 白名单设置。'**
  String get exchangeAddErrIpRestricted;

  /// No description provided for @exchangeAddErrAccountMissing.
  ///
  /// In zh, this message translates to:
  /// **'找不到这个账户，它可能已被删除。'**
  String get exchangeAddErrAccountMissing;

  /// No description provided for @exchangeAddErrUnknown.
  ///
  /// In zh, this message translates to:
  /// **'验证失败：{detail}'**
  String exchangeAddErrUnknown(String detail);

  /// No description provided for @exchangeDetailTotal.
  ///
  /// In zh, this message translates to:
  /// **'账户总估值'**
  String get exchangeDetailTotal;

  /// No description provided for @exchangeDetailTabAssets.
  ///
  /// In zh, this message translates to:
  /// **'按币种'**
  String get exchangeDetailTabAssets;

  /// No description provided for @exchangeDetailTabSubAccounts.
  ///
  /// In zh, this message translates to:
  /// **'按子账户'**
  String get exchangeDetailTabSubAccounts;

  /// No description provided for @exchangeDetailKeyStatusNormal.
  ///
  /// In zh, this message translates to:
  /// **'API Key 正常 · 只读'**
  String get exchangeDetailKeyStatusNormal;

  /// No description provided for @exchangeDetailKeyStatusExpired.
  ///
  /// In zh, this message translates to:
  /// **'API Key 已失效'**
  String get exchangeDetailKeyStatusExpired;

  /// No description provided for @exchangeDetailKeyExpiredNotice.
  ///
  /// In zh, this message translates to:
  /// **'API Key 已失效，无法同步最新资产，请尽快更换。'**
  String get exchangeDetailKeyExpiredNotice;

  /// No description provided for @exchangeDetailNoAssets.
  ///
  /// In zh, this message translates to:
  /// **'该交易所目前没有可显示的资产'**
  String get exchangeDetailNoAssets;

  /// No description provided for @exchangeDetailNotFound.
  ///
  /// In zh, this message translates to:
  /// **'找不到这个交易所账户，它可能已被删除。'**
  String get exchangeDetailNotFound;

  /// No description provided for @exchangeDetailFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'同步失败'**
  String get exchangeDetailFailedTitle;

  /// No description provided for @exchangeDetailLastSuccess.
  ///
  /// In zh, this message translates to:
  /// **'上次成功同步：{time}'**
  String exchangeDetailLastSuccess(String time);

  /// No description provided for @exchangeDetailNeverSucceeded.
  ///
  /// In zh, this message translates to:
  /// **'还没有成功同步过，下面没有缓存数据。'**
  String get exchangeDetailNeverSucceeded;

  /// No description provided for @exchangeDetailUnpriced.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个未识别或无估值的币种'**
  String exchangeDetailUnpriced(int count);

  /// No description provided for @exchangeDetailNotIncluded.
  ///
  /// In zh, this message translates to:
  /// **'未包含：{items}'**
  String exchangeDetailNotIncluded(String items);

  /// No description provided for @exchangeDetailDepositAddressesTitle.
  ///
  /// In zh, this message translates to:
  /// **'充值地址'**
  String get exchangeDetailDepositAddressesTitle;

  /// No description provided for @exchangeDetailDepositAddressesSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'由交易所控制，仅供查看'**
  String get exchangeDetailDepositAddressesSubtitle;

  /// No description provided for @exchangeDetailDepositAddressesNotice.
  ///
  /// In zh, this message translates to:
  /// **'此地址由交易所控制，仅供查看。为避免在交易所自动创建新地址，仅展示已有地址。'**
  String get exchangeDetailDepositAddressesNotice;

  /// No description provided for @exchangeDetailDepositAddressesEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无充值地址'**
  String get exchangeDetailDepositAddressesEmpty;

  /// No description provided for @exchangeDetailDepositAddressMemo.
  ///
  /// In zh, this message translates to:
  /// **'备注/Tag: {memo}'**
  String exchangeDetailDepositAddressMemo(String memo);

  /// No description provided for @exchangeDetailReplaceKey.
  ///
  /// In zh, this message translates to:
  /// **'更换 API Key'**
  String get exchangeDetailReplaceKey;

  /// No description provided for @exchangeDetailDeleteAccount.
  ///
  /// In zh, this message translates to:
  /// **'删除账户'**
  String get exchangeDetailDeleteAccount;

  /// No description provided for @exchangeDetailDeleteConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除交易所账户'**
  String get exchangeDetailDeleteConfirmTitle;

  /// No description provided for @exchangeDetailDeleteConfirmBody.
  ///
  /// In zh, this message translates to:
  /// **'确定删除此交易所账户？删除后将同时清除存储的 API 凭据，本地持仓与同步记录也将被移除。'**
  String get exchangeDetailDeleteConfirmBody;

  /// No description provided for @exchangeDetailDeleteConfirmAction.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get exchangeDetailDeleteConfirmAction;

  /// No description provided for @exchangeDetailDeleteCancelAction.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get exchangeDetailDeleteCancelAction;

  /// No description provided for @subAccountSpot.
  ///
  /// In zh, this message translates to:
  /// **'现货'**
  String get subAccountSpot;

  /// No description provided for @subAccountFunding.
  ///
  /// In zh, this message translates to:
  /// **'资金'**
  String get subAccountFunding;

  /// No description provided for @subAccountFutures.
  ///
  /// In zh, this message translates to:
  /// **'合约'**
  String get subAccountFutures;

  /// No description provided for @subAccountMargin.
  ///
  /// In zh, this message translates to:
  /// **'杠杆'**
  String get subAccountMargin;

  /// No description provided for @subAccountEarn.
  ///
  /// In zh, this message translates to:
  /// **'理财'**
  String get subAccountEarn;

  /// No description provided for @subAccountOther.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get subAccountOther;

  /// No description provided for @assetDetailTitle.
  ///
  /// In zh, this message translates to:
  /// **'币种详情'**
  String get assetDetailTitle;

  /// No description provided for @assetDetailCurrentPrice.
  ///
  /// In zh, this message translates to:
  /// **'当前价格'**
  String get assetDetailCurrentPrice;

  /// No description provided for @assetDetailHoldings.
  ///
  /// In zh, this message translates to:
  /// **'持有'**
  String get assetDetailHoldings;

  /// No description provided for @assetDetailValuation.
  ///
  /// In zh, this message translates to:
  /// **'估值'**
  String get assetDetailValuation;

  /// No description provided for @assetDetailDistributionTitle.
  ///
  /// In zh, this message translates to:
  /// **'分布'**
  String get assetDetailDistributionTitle;

  /// No description provided for @assetDetailDistributionEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无账户持有该币种'**
  String get assetDetailDistributionEmpty;

  /// No description provided for @assetDetailContractsTitle.
  ///
  /// In zh, this message translates to:
  /// **'合约地址'**
  String get assetDetailContractsTitle;

  /// No description provided for @assetDetailCopyContract.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get assetDetailCopyContract;

  /// No description provided for @assetDetailCopied.
  ///
  /// In zh, this message translates to:
  /// **'已复制合约地址'**
  String get assetDetailCopied;

  /// No description provided for @assetDetailNoPrice.
  ///
  /// In zh, this message translates to:
  /// **'估值缺失'**
  String get assetDetailNoPrice;

  /// No description provided for @assetDetailNotFound.
  ///
  /// In zh, this message translates to:
  /// **'未找到该币种信息'**
  String get assetDetailNotFound;

  /// No description provided for @assetDetailViewDistribution.
  ///
  /// In zh, this message translates to:
  /// **'查看币种分布'**
  String get assetDetailViewDistribution;

  /// No description provided for @syncStatusTitle.
  ///
  /// In zh, this message translates to:
  /// **'同步状态'**
  String get syncStatusTitle;

  /// No description provided for @syncStatusLastFullSync.
  ///
  /// In zh, this message translates to:
  /// **'上次全量同步'**
  String get syncStatusLastFullSync;

  /// No description provided for @syncStatusNeverFullSynced.
  ///
  /// In zh, this message translates to:
  /// **'尚未进行过全量同步'**
  String get syncStatusNeverFullSynced;

  /// No description provided for @syncStatusSyncNow.
  ///
  /// In zh, this message translates to:
  /// **'立即同步'**
  String get syncStatusSyncNow;

  /// No description provided for @syncStatusSyncing.
  ///
  /// In zh, this message translates to:
  /// **'正在同步...'**
  String get syncStatusSyncing;

  /// No description provided for @syncStatusDurationSeconds.
  ///
  /// In zh, this message translates to:
  /// **'用时 {seconds} 秒'**
  String syncStatusDurationSeconds(String seconds);

  /// No description provided for @syncStatusDurationMs.
  ///
  /// In zh, this message translates to:
  /// **'用时 {ms} 毫秒'**
  String syncStatusDurationMs(int ms);

  /// No description provided for @syncStatusAccountsSection.
  ///
  /// In zh, this message translates to:
  /// **'各账户状态'**
  String get syncStatusAccountsSection;

  /// No description provided for @syncStatusLogsSection.
  ///
  /// In zh, this message translates to:
  /// **'最近同步记录（最多 50 条）'**
  String get syncStatusLogsSection;

  /// No description provided for @syncStatusLogsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无同步记录'**
  String get syncStatusLogsEmpty;

  /// No description provided for @syncStatusSuccess.
  ///
  /// In zh, this message translates to:
  /// **'成功'**
  String get syncStatusSuccess;

  /// No description provided for @syncStatusFailed.
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get syncStatusFailed;

  /// No description provided for @syncStatusRunning.
  ///
  /// In zh, this message translates to:
  /// **'同步中'**
  String get syncStatusRunning;

  /// No description provided for @syncStatusLastSuccess.
  ///
  /// In zh, this message translates to:
  /// **'上次成功 {time}'**
  String syncStatusLastSuccess(String time);

  /// No description provided for @syncStatusNeverSuccess.
  ///
  /// In zh, this message translates to:
  /// **'从未成功同步'**
  String get syncStatusNeverSuccess;

  /// No description provided for @syncStatusKeyExpiredHint.
  ///
  /// In zh, this message translates to:
  /// **'API Key 已失效，请更换'**
  String get syncStatusKeyExpiredHint;

  /// No description provided for @syncStatusViewFullStatus.
  ///
  /// In zh, this message translates to:
  /// **'查看完整同步状态'**
  String get syncStatusViewFullStatus;

  /// No description provided for @syncStatusDeletedAccount.
  ///
  /// In zh, this message translates to:
  /// **'已删除的账户'**
  String get syncStatusDeletedAccount;

  /// No description provided for @accountsTabAccounts.
  ///
  /// In zh, this message translates to:
  /// **'账户'**
  String get accountsTabAccounts;

  /// No description provided for @accountsTabAddressBook.
  ///
  /// In zh, this message translates to:
  /// **'地址簿'**
  String get accountsTabAddressBook;

  /// No description provided for @accountsSort.
  ///
  /// In zh, this message translates to:
  /// **'排序'**
  String get accountsSort;

  /// No description provided for @accountsSortByValuation.
  ///
  /// In zh, this message translates to:
  /// **'按估值排序'**
  String get accountsSortByValuation;

  /// No description provided for @accountsSortByName.
  ///
  /// In zh, this message translates to:
  /// **'按名称排序'**
  String get accountsSortByName;

  /// No description provided for @accountsMoreActions.
  ///
  /// In zh, this message translates to:
  /// **'更多操作'**
  String get accountsMoreActions;

  /// No description provided for @accountsMenuRename.
  ///
  /// In zh, this message translates to:
  /// **'重命名'**
  String get accountsMenuRename;

  /// No description provided for @accountsMenuDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get accountsMenuDelete;

  /// No description provided for @accountsRenameTitle.
  ///
  /// In zh, this message translates to:
  /// **'重命名账户'**
  String get accountsRenameTitle;

  /// No description provided for @accountsRenameHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入账户名称'**
  String get accountsRenameHint;

  /// No description provided for @accountsRenameCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get accountsRenameCancel;

  /// No description provided for @accountsRenameSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get accountsRenameSave;

  /// No description provided for @accountsDeleteWalletTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除钱包账户'**
  String get accountsDeleteWalletTitle;

  /// No description provided for @accountsDeleteWalletMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定删除此账户？将删除其地址、持仓缓存与历史快照中的该账户明细。如果关联了保险库密钥，密钥不会被删除，仅解除关联。此操作无法撤销。'**
  String get accountsDeleteWalletMessage;

  /// No description provided for @accountsDeleteExchangeTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除交易所账户'**
  String get accountsDeleteExchangeTitle;

  /// No description provided for @accountsDeleteExchangeMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定删除此交易所账户？删除后将同时清除存储的 API 凭据，本地持仓与同步记录也将被移除。此操作无法撤销。'**
  String get accountsDeleteExchangeMessage;

  /// No description provided for @accountsDeleteCancelAction.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get accountsDeleteCancelAction;

  /// No description provided for @accountsDeleteConfirmAction.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get accountsDeleteConfirmAction;

  /// No description provided for @accountsFooterHint.
  ///
  /// In zh, this message translates to:
  /// **'长按账户可重命名或删除'**
  String get accountsFooterHint;

  /// No description provided for @addressSheetNoteLabel.
  ///
  /// In zh, this message translates to:
  /// **'备注'**
  String get addressSheetNoteLabel;

  /// No description provided for @addressSheetNoNote.
  ///
  /// In zh, this message translates to:
  /// **'添加备注'**
  String get addressSheetNoNote;

  /// No description provided for @addressSheetEditNoteTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑备注'**
  String get addressSheetEditNoteTitle;

  /// No description provided for @addressSheetEditNoteHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入地址备注（如：长期持有、主要收款）'**
  String get addressSheetEditNoteHint;

  /// No description provided for @addressSheetEditNoteTooLong.
  ///
  /// In zh, this message translates to:
  /// **'备注长度不能超过 100 个字符'**
  String get addressSheetEditNoteTooLong;

  /// No description provided for @addressSheetSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get addressSheetSave;

  /// No description provided for @addressBookSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索地址、账户、备注'**
  String get addressBookSearchHint;

  /// No description provided for @addressBookChainAll.
  ///
  /// In zh, this message translates to:
  /// **'全部链'**
  String get addressBookChainAll;

  /// No description provided for @addressBookAccountAll.
  ///
  /// In zh, this message translates to:
  /// **'全部账户'**
  String get addressBookAccountAll;

  /// No description provided for @addressBookExactMatch.
  ///
  /// In zh, this message translates to:
  /// **'是你的地址'**
  String get addressBookExactMatch;

  /// No description provided for @addressBookVaultDerived.
  ///
  /// In zh, this message translates to:
  /// **'保险库派生'**
  String get addressBookVaultDerived;

  /// No description provided for @addressBookNote.
  ///
  /// In zh, this message translates to:
  /// **'备注：{note}'**
  String addressBookNote(String note);

  /// No description provided for @addressBookEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'暂无地址'**
  String get addressBookEmptyTitle;

  /// No description provided for @addressBookEmptyDesc.
  ///
  /// In zh, this message translates to:
  /// **'添加钱包账户后，此处将集中管理你的所有地址'**
  String get addressBookEmptyDesc;

  /// No description provided for @addressBookSearchNoResultTitle.
  ///
  /// In zh, this message translates to:
  /// **'不在你的地址簿中'**
  String get addressBookSearchNoResultTitle;

  /// No description provided for @addressBookSearchNoResultDesc.
  ///
  /// In zh, this message translates to:
  /// **'未在你的地址簿中找到此地址或相关信息'**
  String get addressBookSearchNoResultDesc;

  /// No description provided for @addressBookFooterTip.
  ///
  /// In zh, this message translates to:
  /// **'粘贴一个完整地址，可以查它是不是你的。没有匹配时会显示「不在你的地址簿中」。'**
  String get addressBookFooterTip;

  /// No description provided for @overviewChartRange7d.
  ///
  /// In zh, this message translates to:
  /// **'7 天'**
  String get overviewChartRange7d;

  /// No description provided for @overviewChartRange30d.
  ///
  /// In zh, this message translates to:
  /// **'30 天'**
  String get overviewChartRange30d;

  /// No description provided for @overviewChartRange90d.
  ///
  /// In zh, this message translates to:
  /// **'90 天'**
  String get overviewChartRange90d;

  /// No description provided for @overviewChartRangeAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get overviewChartRangeAll;

  /// No description provided for @overviewChartEmpty.
  ///
  /// In zh, this message translates to:
  /// **'至少需要两天的快照数据以绘制净值曲线'**
  String get overviewChartEmpty;

  /// No description provided for @overviewChartAriaLabel.
  ///
  /// In zh, this message translates to:
  /// **'近 {count} 天净值曲线'**
  String overviewChartAriaLabel(int count);

  /// No description provided for @overviewChartAriaLabelAll.
  ///
  /// In zh, this message translates to:
  /// **'全部净值曲线'**
  String get overviewChartAriaLabelAll;

  /// No description provided for @overviewChartDaysAgo.
  ///
  /// In zh, this message translates to:
  /// **'{count} 天前'**
  String overviewChartDaysAgo(int count);

  /// No description provided for @overviewChartToday.
  ///
  /// In zh, this message translates to:
  /// **'今天'**
  String get overviewChartToday;

  /// No description provided for @overviewBackupWarning.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个钱包尚未备份'**
  String overviewBackupWarning(int count);

  /// No description provided for @backupChecklistTitle.
  ///
  /// In zh, this message translates to:
  /// **'备份清单'**
  String get backupChecklistTitle;

  /// No description provided for @backupChecklistProgress.
  ///
  /// In zh, this message translates to:
  /// **'{backedUp} / {total} 个钱包已备份'**
  String backupChecklistProgress(int backedUp, int total);

  /// No description provided for @backupChecklistAllBackedUp.
  ///
  /// In zh, this message translates to:
  /// **'全部钱包已备份'**
  String get backupChecklistAllBackedUp;

  /// No description provided for @backupChecklistNeverExported.
  ///
  /// In zh, this message translates to:
  /// **'尚未导出过加密备份'**
  String get backupChecklistNeverExported;

  /// No description provided for @backupChecklistLastExport.
  ///
  /// In zh, this message translates to:
  /// **'加密备份文件：{time} 导出'**
  String backupChecklistLastExport(String time);

  /// No description provided for @backupChecklistUnexportedChanges.
  ///
  /// In zh, this message translates to:
  /// **'之后保险库有更改，尚未导出'**
  String get backupChecklistUnexportedChanges;

  /// No description provided for @backupChecklistExport.
  ///
  /// In zh, this message translates to:
  /// **'导出加密备份'**
  String get backupChecklistExport;

  /// No description provided for @backupChecklistPendingSection.
  ///
  /// In zh, this message translates to:
  /// **'待处理'**
  String get backupChecklistPendingSection;

  /// No description provided for @backupChecklistCompletedSection.
  ///
  /// In zh, this message translates to:
  /// **'已完成'**
  String get backupChecklistCompletedSection;

  /// No description provided for @backupChecklistExchangeNote.
  ///
  /// In zh, this message translates to:
  /// **'交易所资产没有私钥可备份。请启用二次验证，并保管好账号凭据。'**
  String get backupChecklistExchangeNote;

  /// No description provided for @backupChecklistEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'暂无钱包账户'**
  String get backupChecklistEmptyTitle;

  /// No description provided for @backupChecklistEmptyDesc.
  ///
  /// In zh, this message translates to:
  /// **'添加钱包账户后，在此查看和管理各钱包的备份状况。'**
  String get backupChecklistEmptyDesc;

  /// No description provided for @backupChecklistKeylessNote.
  ///
  /// In zh, this message translates to:
  /// **'这类钱包依赖服务商。建议趁服务可用时导出私钥，或把资产转到普通助记词钱包。'**
  String get backupChecklistKeylessNote;

  /// No description provided for @backupChecklistOverdueWarning.
  ///
  /// In zh, this message translates to:
  /// **'超过 180 天未核对'**
  String get backupChecklistOverdueWarning;

  /// No description provided for @backupChecklistLastVerified.
  ///
  /// In zh, this message translates to:
  /// **'上次核对 {date}'**
  String backupChecklistLastVerified(String date);

  /// No description provided for @backupActionGoToVault.
  ///
  /// In zh, this message translates to:
  /// **'去入库'**
  String get backupActionGoToVault;

  /// No description provided for @backupActionMarkOffline.
  ///
  /// In zh, this message translates to:
  /// **'标记已离线备份'**
  String get backupActionMarkOffline;

  /// No description provided for @backupActionUnmarkOffline.
  ///
  /// In zh, this message translates to:
  /// **'取消离线备份标记'**
  String get backupActionUnmarkOffline;

  /// No description provided for @backupActionMarkKeyless.
  ///
  /// In zh, this message translates to:
  /// **'标记为无助记词钱包'**
  String get backupActionMarkKeyless;

  /// No description provided for @backupActionUnmarkKeyless.
  ///
  /// In zh, this message translates to:
  /// **'取消无助记词标记'**
  String get backupActionUnmarkKeyless;

  /// No description provided for @backupActionVerifiedToday.
  ///
  /// In zh, this message translates to:
  /// **'今天已核对'**
  String get backupActionVerifiedToday;

  /// No description provided for @backupActionResetStatus.
  ///
  /// In zh, this message translates to:
  /// **'重新标记'**
  String get backupActionResetStatus;

  /// No description provided for @backupActionViewChecklist.
  ///
  /// In zh, this message translates to:
  /// **'查看完整备份清单'**
  String get backupActionViewChecklist;

  /// No description provided for @backupStatusSheetTitle.
  ///
  /// In zh, this message translates to:
  /// **'备份状态管理'**
  String get backupStatusSheetTitle;

  /// No description provided for @backupStatusInVaultDesc.
  ///
  /// In zh, this message translates to:
  /// **'已关联保险库中的密钥条目。'**
  String get backupStatusInVaultDesc;

  /// No description provided for @backupStatusOfflineDesc.
  ///
  /// In zh, this message translates to:
  /// **'已标记为有纸质或其他离线备份。'**
  String get backupStatusOfflineDesc;

  /// No description provided for @backupStatusOfflineNeverVerified.
  ///
  /// In zh, this message translates to:
  /// **'未记录核对日期'**
  String get backupStatusOfflineNeverVerified;

  /// No description provided for @backupStatusKeylessDesc.
  ///
  /// In zh, this message translates to:
  /// **'无助记词钱包（MPC 或社交登录型，无法导出）。'**
  String get backupStatusKeylessDesc;

  /// No description provided for @backupStatusNoneDesc.
  ///
  /// In zh, this message translates to:
  /// **'尚未在保险库入库，也没有标记离线备份。'**
  String get backupStatusNoneDesc;

  /// No description provided for @bootstrapWipeAndRestart.
  ///
  /// In zh, this message translates to:
  /// **'清除本地数据并重新开始'**
  String get bootstrapWipeAndRestart;

  /// No description provided for @bootstrapWipeConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'清除本地数据并重新开始？'**
  String get bootstrapWipeConfirmTitle;

  /// No description provided for @bootstrapWipeConfirmBody.
  ///
  /// In zh, this message translates to:
  /// **'此操作将清除本地数据库与所有存储的凭据，无法撤销。如果您有加密备份文件（.owbak），可以在重新进入应用后恢复。'**
  String get bootstrapWipeConfirmBody;

  /// No description provided for @bootstrapWipeConfirmAction.
  ///
  /// In zh, this message translates to:
  /// **'清除并重新开始'**
  String get bootstrapWipeConfirmAction;

  /// No description provided for @bootstrapWipeFailed.
  ///
  /// In zh, this message translates to:
  /// **'清除未完成，请重试'**
  String get bootstrapWipeFailed;

  /// No description provided for @bootstrapWipeFailedBody.
  ///
  /// In zh, this message translates to:
  /// **'部分本地数据未能成功清除，请重试。'**
  String get bootstrapWipeFailedBody;

  /// No description provided for @settingsSectionSecurity.
  ///
  /// In zh, this message translates to:
  /// **'安全'**
  String get settingsSectionSecurity;

  /// No description provided for @settingsSectionOther.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get settingsSectionOther;

  /// No description provided for @settingsSectionDanger.
  ///
  /// In zh, this message translates to:
  /// **'危险区'**
  String get settingsSectionDanger;

  /// No description provided for @settingsSecurity.
  ///
  /// In zh, this message translates to:
  /// **'应用锁与生物识别'**
  String get settingsSecurity;

  /// No description provided for @settingsSecurityBody.
  ///
  /// In zh, this message translates to:
  /// **'修改 PIN、自动锁定时间与生物识别'**
  String get settingsSecurityBody;

  /// No description provided for @settingsSecuritySoon.
  ///
  /// In zh, this message translates to:
  /// **'安全设置功能即将提供'**
  String get settingsSecuritySoon;

  /// No description provided for @settingsBackup.
  ///
  /// In zh, this message translates to:
  /// **'加密备份'**
  String get settingsBackup;

  /// No description provided for @settingsBackupNever.
  ///
  /// In zh, this message translates to:
  /// **'尚未备份'**
  String get settingsBackupNever;

  /// No description provided for @settingsBackupLastExported.
  ///
  /// In zh, this message translates to:
  /// **'上次导出 {date}'**
  String settingsBackupLastExported(String date);

  /// No description provided for @settingsQuote.
  ///
  /// In zh, this message translates to:
  /// **'计价货币'**
  String get settingsQuote;

  /// No description provided for @settingsHideSmall.
  ///
  /// In zh, this message translates to:
  /// **'隐藏小额币种'**
  String get settingsHideSmall;

  /// No description provided for @settingsHideSmallBody.
  ///
  /// In zh, this message translates to:
  /// **'低于 1 USD 的资产不显示在列表中'**
  String get settingsHideSmallBody;

  /// No description provided for @settingsUnrecognizedTokens.
  ///
  /// In zh, this message translates to:
  /// **'未识别代币'**
  String get settingsUnrecognizedTokens;

  /// No description provided for @settingsUnrecognizedTokensEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无未识别代币'**
  String get settingsUnrecognizedTokensEmpty;

  /// No description provided for @settingsUnrecognizedTokensDesc.
  ///
  /// In zh, this message translates to:
  /// **'链上收到但未在价格源中识别的代币可以在此处管理显隐'**
  String get settingsUnrecognizedTokensDesc;

  /// No description provided for @settingsTheme.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get settingsTheme;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色模式'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色模式'**
  String get settingsThemeDark;

  /// No description provided for @settingsAbout.
  ///
  /// In zh, this message translates to:
  /// **'关于与帮助'**
  String get settingsAbout;

  /// No description provided for @settingsWipeAllData.
  ///
  /// In zh, this message translates to:
  /// **'清除全部数据'**
  String get settingsWipeAllData;

  /// No description provided for @settingsWipeConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'清除全部数据？'**
  String get settingsWipeConfirmTitle;

  /// No description provided for @settingsWipeConfirmBody.
  ///
  /// In zh, this message translates to:
  /// **'此操作将清除本地全部钱包、交易所、持仓、快照与保存的凭据，不可撤销。如果有加密备份文件（.owbak），可以在重新进入应用后恢复。'**
  String get settingsWipeConfirmBody;

  /// No description provided for @settingsWipeConfirmAction.
  ///
  /// In zh, this message translates to:
  /// **'清除全部数据'**
  String get settingsWipeConfirmAction;

  /// No description provided for @securitySectionAppLock.
  ///
  /// In zh, this message translates to:
  /// **'应用锁'**
  String get securitySectionAppLock;

  /// No description provided for @securitySectionVault.
  ///
  /// In zh, this message translates to:
  /// **'保险库'**
  String get securitySectionVault;

  /// No description provided for @securitySectionDevice.
  ///
  /// In zh, this message translates to:
  /// **'设备'**
  String get securitySectionDevice;

  /// No description provided for @securityPin.
  ///
  /// In zh, this message translates to:
  /// **'修改 PIN'**
  String get securityPin;

  /// No description provided for @securityAppBiometrics.
  ///
  /// In zh, this message translates to:
  /// **'面容 / 指纹解锁'**
  String get securityAppBiometrics;

  /// No description provided for @securityAutoLock.
  ///
  /// In zh, this message translates to:
  /// **'自动锁定'**
  String get securityAutoLock;

  /// No description provided for @securityAutoLockImmediately.
  ///
  /// In zh, this message translates to:
  /// **'立即'**
  String get securityAutoLockImmediately;

  /// No description provided for @securityAutoLock1Min.
  ///
  /// In zh, this message translates to:
  /// **'1 分钟后'**
  String get securityAutoLock1Min;

  /// No description provided for @securityAutoLock5Min.
  ///
  /// In zh, this message translates to:
  /// **'5 分钟后'**
  String get securityAutoLock5Min;

  /// No description provided for @securityVaultBiometrics.
  ///
  /// In zh, this message translates to:
  /// **'面容 / 指纹解锁保险库'**
  String get securityVaultBiometrics;

  /// No description provided for @securityVaultBiometricsDesc.
  ///
  /// In zh, this message translates to:
  /// **'开启时需输入主密码，由硬件安全芯片保护'**
  String get securityVaultBiometricsDesc;

  /// No description provided for @securityChangeMasterPassword.
  ///
  /// In zh, this message translates to:
  /// **'修改主密码'**
  String get securityChangeMasterPassword;

  /// No description provided for @securityDeviceStatus.
  ///
  /// In zh, this message translates to:
  /// **'设备安全状态'**
  String get securityDeviceStatus;

  /// No description provided for @securityDeviceNormal.
  ///
  /// In zh, this message translates to:
  /// **'正常'**
  String get securityDeviceNormal;

  /// No description provided for @securityDeviceNormalDesc.
  ///
  /// In zh, this message translates to:
  /// **'未检测到越狱或 root'**
  String get securityDeviceNormalDesc;

  /// No description provided for @securityFeaturePending.
  ///
  /// In zh, this message translates to:
  /// **'功能准备中'**
  String get securityFeaturePending;

  /// No description provided for @aboutTitle.
  ///
  /// In zh, this message translates to:
  /// **'关于与帮助'**
  String get aboutTitle;

  /// No description provided for @aboutVersion.
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get aboutVersion;

  /// No description provided for @aboutSecurityDesign.
  ///
  /// In zh, this message translates to:
  /// **'安全设计说明'**
  String get aboutSecurityDesign;

  /// No description provided for @aboutSecurityDesignBody.
  ///
  /// In zh, this message translates to:
  /// **'本地优先、密钥不出设备、只看不动'**
  String get aboutSecurityDesignBody;

  /// No description provided for @aboutSecurityDesignDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'安全设计原则'**
  String get aboutSecurityDesignDialogTitle;

  /// No description provided for @aboutSecurityDesignDetail.
  ///
  /// In zh, this message translates to:
  /// **'1. 本地优先：你的资产数据和密钥仅保存在当前设备，不上传至任何服务器。\n\n2. 只看不动：OneWallet 不提供签名、转账或交易功能，杜绝被黑客恶意调用的可能。\n\n3. 离线保险库：助记词和私钥由独立的加密保险库保管，与联网环境物理隔离。'**
  String get aboutSecurityDesignDetail;

  /// No description provided for @aboutBackupFormat.
  ///
  /// In zh, this message translates to:
  /// **'备份文件格式与解密工具'**
  String get aboutBackupFormat;

  /// No description provided for @aboutBackupFormatBody.
  ///
  /// In zh, this message translates to:
  /// **'公开格式，支持电脑端开源离线解密'**
  String get aboutBackupFormatBody;

  /// No description provided for @aboutBackupFormatDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'加密备份与离线解密'**
  String get aboutBackupFormatDialogTitle;

  /// No description provided for @aboutBackupFormatDetail.
  ///
  /// In zh, this message translates to:
  /// **'OneWallet 的加密备份（.owbak）采用公开规范与标准算法（Argon2id + XChaCha20-Poly1305）。\n\n即使应用不可用，你也可以在断网电脑上使用官方提供的开源 Python 脚本解密并导出全部助记词与数据。'**
  String get aboutBackupFormatDetail;

  /// No description provided for @aboutFaq.
  ///
  /// In zh, this message translates to:
  /// **'常见问题'**
  String get aboutFaq;

  /// No description provided for @aboutFaqDerivationTitle.
  ///
  /// In zh, this message translates to:
  /// **'派生路径是什么？'**
  String get aboutFaqDerivationTitle;

  /// No description provided for @aboutFaqDerivationAnswer.
  ///
  /// In zh, this message translates to:
  /// **'派生路径是按照 BIP44/84/86 等加密货币标准，从同一套助记词计算出不同链和不同地址规则的算法路径。'**
  String get aboutFaqDerivationAnswer;

  /// No description provided for @aboutFaqMismatchTitle.
  ///
  /// In zh, this message translates to:
  /// **'为什么链上地址与钱包软件显示的不一致？'**
  String get aboutFaqMismatchTitle;

  /// No description provided for @aboutFaqMismatchAnswer.
  ///
  /// In zh, this message translates to:
  /// **'不同钱包软件可能采用了不同的默认派生路径或地址格式（例如 Bitcoin 的 Legacy 1 开头、SegWit 3 开头或 Native SegWit bc1 开头）。在派生地址页面可以选择对应的路径预设。'**
  String get aboutFaqMismatchAnswer;

  /// No description provided for @aboutFaqApiKeyTitle.
  ///
  /// In zh, this message translates to:
  /// **'如何创建只读 API Key？'**
  String get aboutFaqApiKeyTitle;

  /// No description provided for @aboutFaqApiKeyAnswer.
  ///
  /// In zh, this message translates to:
  /// **'在交易所 API 管理页面创建密钥时，仅勾选「读取」或「Read-Only」权限，切勿开启「交易」或「提现」权限以保障资金绝对安全。'**
  String get aboutFaqApiKeyAnswer;

  /// No description provided for @aboutLicenses.
  ///
  /// In zh, this message translates to:
  /// **'开源许可'**
  String get aboutLicenses;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @failureBiometricUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'无法使用生物识别，请输入主密码。'**
  String get failureBiometricUnavailable;

  /// No description provided for @failureLockedOut.
  ///
  /// In zh, this message translates to:
  /// **'输错次数过多，请在 {time} 之后再试。'**
  String failureLockedOut(String time);

  /// No description provided for @lockTitle.
  ///
  /// In zh, this message translates to:
  /// **'OneWallet'**
  String get lockTitle;

  /// No description provided for @lockSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'输入 6 位 PIN'**
  String get lockSubtitle;

  /// No description provided for @lockWrongPin.
  ///
  /// In zh, this message translates to:
  /// **'PIN 码不正确'**
  String get lockWrongPin;

  /// No description provided for @lockCountdown.
  ///
  /// In zh, this message translates to:
  /// **'错误次数过多，请在 {time} 后重试'**
  String lockCountdown(String time);

  /// No description provided for @lockBiometricsButton.
  ///
  /// In zh, this message translates to:
  /// **'生物识别'**
  String get lockBiometricsButton;

  /// No description provided for @lockBiometricReason.
  ///
  /// In zh, this message translates to:
  /// **'解锁 OneWallet'**
  String get lockBiometricReason;

  /// No description provided for @lockDeleteKey.
  ///
  /// In zh, this message translates to:
  /// **'⌫'**
  String get lockDeleteKey;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In zh, this message translates to:
  /// **'一处看全，备份不丢'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'查看所有链上钱包和交易所的资产，并把助记词存进本机的加密保险库。'**
  String get onboardingWelcomeSubtitle;

  /// No description provided for @onboardingSecurityTitle.
  ///
  /// In zh, this message translates to:
  /// **'开始前请了解'**
  String get onboardingSecurityTitle;

  /// No description provided for @onboardingSecurity1Title.
  ///
  /// In zh, this message translates to:
  /// **'只读，不转账'**
  String get onboardingSecurity1Title;

  /// No description provided for @onboardingSecurity1Desc.
  ///
  /// In zh, this message translates to:
  /// **'app 不会发起任何交易'**
  String get onboardingSecurity1Desc;

  /// No description provided for @onboardingSecurity2Title.
  ///
  /// In zh, this message translates to:
  /// **'密钥只存在这台手机'**
  String get onboardingSecurity2Title;

  /// No description provided for @onboardingSecurity2Desc.
  ///
  /// In zh, this message translates to:
  /// **'不上传到任何服务器'**
  String get onboardingSecurity2Desc;

  /// No description provided for @onboardingSecurity3Title.
  ///
  /// In zh, this message translates to:
  /// **'PIN 和主密码无法找回'**
  String get onboardingSecurity3Title;

  /// No description provided for @onboardingSecurity3Desc.
  ///
  /// In zh, this message translates to:
  /// **'请务必记牢，并导出加密备份'**
  String get onboardingSecurity3Desc;

  /// No description provided for @onboardingStartButton.
  ///
  /// In zh, this message translates to:
  /// **'我已了解，开始使用'**
  String get onboardingStartButton;

  /// No description provided for @onboardingRestoreButton.
  ///
  /// In zh, this message translates to:
  /// **'从备份恢复'**
  String get onboardingRestoreButton;

  /// No description provided for @onboardingSetPinTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置 6 位 PIN'**
  String get onboardingSetPinTitle;

  /// No description provided for @onboardingSetPinSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'用于每次打开应用时验证身份'**
  String get onboardingSetPinSubtitle;

  /// No description provided for @onboardingConfirmPinTitle.
  ///
  /// In zh, this message translates to:
  /// **'请再次输入以确认'**
  String get onboardingConfirmPinTitle;

  /// No description provided for @onboardingConfirmPinSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'两次输入的 PIN 必须一致'**
  String get onboardingConfirmPinSubtitle;

  /// No description provided for @onboardingPinMismatch.
  ///
  /// In zh, this message translates to:
  /// **'两次输入的 PIN 不一致，请重新输入'**
  String get onboardingPinMismatch;

  /// No description provided for @onboardingBiometricTitle.
  ///
  /// In zh, this message translates to:
  /// **'开启生物识别'**
  String get onboardingBiometricTitle;

  /// No description provided for @onboardingBiometricSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'使用面容或指纹更快捷地解锁 OneWallet'**
  String get onboardingBiometricSubtitle;

  /// No description provided for @onboardingEnableBiometric.
  ///
  /// In zh, this message translates to:
  /// **'开启'**
  String get onboardingEnableBiometric;

  /// No description provided for @onboardingSkipBiometric.
  ///
  /// In zh, this message translates to:
  /// **'稍后再说'**
  String get onboardingSkipBiometric;

  /// No description provided for @vaultTitle.
  ///
  /// In zh, this message translates to:
  /// **'保险库'**
  String get vaultTitle;

  /// No description provided for @vaultFooterNote.
  ///
  /// In zh, this message translates to:
  /// **'保险库内容仅存于本机。请定期导出加密备份。'**
  String get vaultFooterNote;

  /// No description provided for @vaultChecklistNotice.
  ///
  /// In zh, this message translates to:
  /// **'备份清单：{count} 个钱包未备份'**
  String vaultChecklistNotice(int count);

  /// No description provided for @vaultEmptyItemsTitle.
  ///
  /// In zh, this message translates to:
  /// **'暂无密钥条目'**
  String get vaultEmptyItemsTitle;

  /// No description provided for @vaultEmptyItemsBody.
  ///
  /// In zh, this message translates to:
  /// **'点击右上角「＋」导入第一个助记词或私钥。'**
  String get vaultEmptyItemsBody;

  /// No description provided for @vaultItemKindMnemonic.
  ///
  /// In zh, this message translates to:
  /// **'助记词'**
  String get vaultItemKindMnemonic;

  /// No description provided for @vaultItemKindPrivateKey.
  ///
  /// In zh, this message translates to:
  /// **'私钥'**
  String get vaultItemKindPrivateKey;

  /// No description provided for @vaultItemPassphrase.
  ///
  /// In zh, this message translates to:
  /// **'含密码'**
  String get vaultItemPassphrase;

  /// No description provided for @vaultImportAction.
  ///
  /// In zh, this message translates to:
  /// **'导入密钥'**
  String get vaultImportAction;

  /// No description provided for @vaultSetupTitle.
  ///
  /// In zh, this message translates to:
  /// **'创建保险库'**
  String get vaultSetupTitle;

  /// No description provided for @vaultSetupIntro.
  ///
  /// In zh, this message translates to:
  /// **'主密码用于保护你的助记词，换手机恢复时也需要它。'**
  String get vaultSetupIntro;

  /// No description provided for @vaultSetupWarningTitle.
  ///
  /// In zh, this message translates to:
  /// **'主密码无法找回'**
  String get vaultSetupWarningTitle;

  /// No description provided for @vaultSetupWarningBody.
  ///
  /// In zh, this message translates to:
  /// **'OneWallet 不在任何服务器保存你的密码。如果遗忘主密码，保险库内的全部密钥将永远无法恢复。'**
  String get vaultSetupWarningBody;

  /// No description provided for @vaultSetupPasswordLabel.
  ///
  /// In zh, this message translates to:
  /// **'主密码（至少 10 个字符）'**
  String get vaultSetupPasswordLabel;

  /// No description provided for @vaultSetupPasswordHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入至少 10 位主密码'**
  String get vaultSetupPasswordHint;

  /// No description provided for @vaultSetupPasswordConfirmLabel.
  ///
  /// In zh, this message translates to:
  /// **'再次输入'**
  String get vaultSetupPasswordConfirmLabel;

  /// No description provided for @vaultSetupPasswordConfirmHint.
  ///
  /// In zh, this message translates to:
  /// **'请再次输入主密码'**
  String get vaultSetupPasswordConfirmHint;

  /// No description provided for @vaultSetupAgreeRisk.
  ///
  /// In zh, this message translates to:
  /// **'我明白主密码丢失后，保险库内容无法恢复。'**
  String get vaultSetupAgreeRisk;

  /// No description provided for @vaultSetupBiometricsTitle.
  ///
  /// In zh, this message translates to:
  /// **'使用面容或指纹解锁保险库'**
  String get vaultSetupBiometricsTitle;

  /// No description provided for @vaultSetupBiometricsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'日常查看更方便，硬件安全芯片保护'**
  String get vaultSetupBiometricsSubtitle;

  /// No description provided for @vaultSetupCreateButton.
  ///
  /// In zh, this message translates to:
  /// **'创建保险库'**
  String get vaultSetupCreateButton;

  /// No description provided for @vaultSetupCreating.
  ///
  /// In zh, this message translates to:
  /// **'正在生成保险库与加密密钥…'**
  String get vaultSetupCreating;

  /// No description provided for @vaultSetupTooShort.
  ///
  /// In zh, this message translates to:
  /// **'主密码长度至少为 10 个字符'**
  String get vaultSetupTooShort;

  /// No description provided for @vaultSetupMismatch.
  ///
  /// In zh, this message translates to:
  /// **'两次输入的密码不一致'**
  String get vaultSetupMismatch;

  /// No description provided for @vaultSetupStrengthLabel.
  ///
  /// In zh, this message translates to:
  /// **'强度：{strength}'**
  String vaultSetupStrengthLabel(String strength);

  /// No description provided for @vaultSetupStrengthWeak.
  ///
  /// In zh, this message translates to:
  /// **'弱'**
  String get vaultSetupStrengthWeak;

  /// No description provided for @vaultSetupStrengthMedium.
  ///
  /// In zh, this message translates to:
  /// **'中等'**
  String get vaultSetupStrengthMedium;

  /// No description provided for @vaultSetupStrengthStrong.
  ///
  /// In zh, this message translates to:
  /// **'强'**
  String get vaultSetupStrengthStrong;

  /// No description provided for @vaultSetupWeakConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'密码强度较弱'**
  String get vaultSetupWeakConfirmTitle;

  /// No description provided for @vaultSetupWeakConfirmBody.
  ///
  /// In zh, this message translates to:
  /// **'当前主密码强度较弱。为了资金安全，建议使用包含大小写字母、数字或符号的复杂密码。是否确认使用当前密码？'**
  String get vaultSetupWeakConfirmBody;

  /// No description provided for @vaultSetupWeakConfirmContinue.
  ///
  /// In zh, this message translates to:
  /// **'仍然使用'**
  String get vaultSetupWeakConfirmContinue;

  /// No description provided for @vaultSetupWeakConfirmCancel.
  ///
  /// In zh, this message translates to:
  /// **'返回修改'**
  String get vaultSetupWeakConfirmCancel;

  /// No description provided for @vaultSetupSuccess.
  ///
  /// In zh, this message translates to:
  /// **'保险库已成功创建'**
  String get vaultSetupSuccess;

  /// No description provided for @vaultImportTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入到保险库'**
  String get vaultImportTitle;

  /// No description provided for @vaultImportTypeMnemonic.
  ///
  /// In zh, this message translates to:
  /// **'助记词'**
  String get vaultImportTypeMnemonic;

  /// No description provided for @vaultImportTypePrivateKey.
  ///
  /// In zh, this message translates to:
  /// **'私钥'**
  String get vaultImportTypePrivateKey;

  /// No description provided for @vaultImportNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get vaultImportNameLabel;

  /// No description provided for @vaultImportNameHint.
  ///
  /// In zh, this message translates to:
  /// **'如：小狐狸主号'**
  String get vaultImportNameHint;

  /// No description provided for @vaultImportWordCountLabel.
  ///
  /// In zh, this message translates to:
  /// **'词数'**
  String get vaultImportWordCountLabel;

  /// No description provided for @vaultImportPasteFullPhrase.
  ///
  /// In zh, this message translates to:
  /// **'粘贴整段'**
  String get vaultImportPasteFullPhrase;

  /// No description provided for @vaultImportPasteInvalid.
  ///
  /// In zh, this message translates to:
  /// **'剪贴板中的内容词数不匹配（支持 12/15/18/21/24 词）'**
  String get vaultImportPasteInvalid;

  /// No description provided for @vaultImportWordSuggestions.
  ///
  /// In zh, this message translates to:
  /// **'联想词'**
  String get vaultImportWordSuggestions;

  /// No description provided for @vaultImportMnemonicChecksumFailed.
  ///
  /// In zh, this message translates to:
  /// **'助记词校验失败，请检查拼写和顺序'**
  String get vaultImportMnemonicChecksumFailed;

  /// No description provided for @vaultImportAdvancedPassphrase.
  ///
  /// In zh, this message translates to:
  /// **'高级：BIP39 附加密码 (Passphrase)'**
  String get vaultImportAdvancedPassphrase;

  /// No description provided for @vaultImportPassphraseHint.
  ///
  /// In zh, this message translates to:
  /// **'可选，通常为空'**
  String get vaultImportPassphraseHint;

  /// No description provided for @vaultImportChainFamilyLabel.
  ///
  /// In zh, this message translates to:
  /// **'链类型'**
  String get vaultImportChainFamilyLabel;

  /// No description provided for @vaultImportPrivateKeyLabel.
  ///
  /// In zh, this message translates to:
  /// **'私钥'**
  String get vaultImportPrivateKeyLabel;

  /// No description provided for @vaultImportPrivateKeyHintEvm.
  ///
  /// In zh, this message translates to:
  /// **'64 位十六进制私钥，可带 0x'**
  String get vaultImportPrivateKeyHintEvm;

  /// No description provided for @vaultImportPrivateKeyHintBtc.
  ///
  /// In zh, this message translates to:
  /// **'WIF 格式私钥（以 5、K 或 L 开头）'**
  String get vaultImportPrivateKeyHintBtc;

  /// No description provided for @vaultImportPrivateKeyHintSol.
  ///
  /// In zh, this message translates to:
  /// **'Base58 编码的私钥'**
  String get vaultImportPrivateKeyHintSol;

  /// No description provided for @vaultImportPrivateKeyHintTrx.
  ///
  /// In zh, this message translates to:
  /// **'64 位十六进制私钥，可带 0x'**
  String get vaultImportPrivateKeyHintTrx;

  /// No description provided for @vaultImportPrivateKeyFormatError.
  ///
  /// In zh, this message translates to:
  /// **'私钥格式不正确'**
  String get vaultImportPrivateKeyFormatError;

  /// No description provided for @vaultImportLinkAccountLabel.
  ///
  /// In zh, this message translates to:
  /// **'关联账户'**
  String get vaultImportLinkAccountLabel;

  /// No description provided for @vaultImportLinkAccountNone.
  ///
  /// In zh, this message translates to:
  /// **'不关联（稍后在派生地址页处理）'**
  String get vaultImportLinkAccountNone;

  /// No description provided for @vaultImportSubmitButton.
  ///
  /// In zh, this message translates to:
  /// **'保存到保险库'**
  String get vaultImportSubmitButton;

  /// No description provided for @vaultImportVerifyPasswordTitle.
  ///
  /// In zh, this message translates to:
  /// **'输入主密码'**
  String get vaultImportVerifyPasswordTitle;

  /// No description provided for @vaultImportVerifyPasswordMessage.
  ///
  /// In zh, this message translates to:
  /// **'请先输入主密码验证身份后保存密钥'**
  String get vaultImportVerifyPasswordMessage;

  /// No description provided for @vaultImportVerifyPasswordCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get vaultImportVerifyPasswordCancel;

  /// No description provided for @vaultImportVerifyPasswordConfirm.
  ///
  /// In zh, this message translates to:
  /// **'验证并保存'**
  String get vaultImportVerifyPasswordConfirm;

  /// No description provided for @vaultImportSuccess.
  ///
  /// In zh, this message translates to:
  /// **'密钥已成功保存到保险库'**
  String get vaultImportSuccess;

  /// No description provided for @vaultImportDuplicateError.
  ///
  /// In zh, this message translates to:
  /// **'该密钥已存在于保险库中'**
  String get vaultImportDuplicateError;

  /// No description provided for @vaultItemDetailTitle.
  ///
  /// In zh, this message translates to:
  /// **'密钥详情'**
  String get vaultItemDetailTitle;

  /// No description provided for @vaultItemType.
  ///
  /// In zh, this message translates to:
  /// **'类型'**
  String get vaultItemType;

  /// No description provided for @vaultItemCreatedAt.
  ///
  /// In zh, this message translates to:
  /// **'创建于'**
  String get vaultItemCreatedAt;

  /// No description provided for @vaultItemLinkedAccount.
  ///
  /// In zh, this message translates to:
  /// **'关联账户'**
  String get vaultItemLinkedAccount;

  /// No description provided for @vaultItemLinkedAccountNone.
  ///
  /// In zh, this message translates to:
  /// **'未关联'**
  String get vaultItemLinkedAccountNone;

  /// No description provided for @vaultItemVeilMessage.
  ///
  /// In zh, this message translates to:
  /// **'每次查看都需要面容或主密码验证'**
  String get vaultItemVeilMessage;

  /// No description provided for @vaultItemVeilAction.
  ///
  /// In zh, this message translates to:
  /// **'验证后查看'**
  String get vaultItemVeilAction;

  /// No description provided for @vaultItemPassphraseLabel.
  ///
  /// In zh, this message translates to:
  /// **'BIP39 附加密码 (Passphrase)'**
  String get vaultItemPassphraseLabel;

  /// No description provided for @vaultItemPrivateKey.
  ///
  /// In zh, this message translates to:
  /// **'私钥'**
  String get vaultItemPrivateKey;

  /// No description provided for @vaultItemShowQrCode.
  ///
  /// In zh, this message translates to:
  /// **'以二维码显示'**
  String get vaultItemShowQrCode;

  /// No description provided for @vaultItemHideQrCode.
  ///
  /// In zh, this message translates to:
  /// **'以文字显示'**
  String get vaultItemHideQrCode;

  /// No description provided for @vaultItemCountdown.
  ///
  /// In zh, this message translates to:
  /// **'{seconds} 秒后自动隐藏'**
  String vaultItemCountdown(int seconds);

  /// No description provided for @vaultItemHideAction.
  ///
  /// In zh, this message translates to:
  /// **'隐藏'**
  String get vaultItemHideAction;

  /// No description provided for @vaultItemDerivedAddresses.
  ///
  /// In zh, this message translates to:
  /// **'已派生地址'**
  String get vaultItemDerivedAddresses;

  /// No description provided for @vaultItemDerivedAddressesCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个地址已在观察中'**
  String vaultItemDerivedAddressesCount(int count);

  /// No description provided for @vaultItemDeleteButton.
  ///
  /// In zh, this message translates to:
  /// **'删除此密钥'**
  String get vaultItemDeleteButton;

  /// No description provided for @vaultItemDeleteDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除此密钥'**
  String get vaultItemDeleteDialogTitle;

  /// No description provided for @vaultItemDeleteDialogMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定删除此密钥条目？删除后，关联钱包的备份状态将变为未备份。若未另行备份，将无法再查看或导出此密钥。此操作无法撤销。'**
  String get vaultItemDeleteDialogMessage;

  /// No description provided for @vaultItemDeleteAgreeRisk.
  ///
  /// In zh, this message translates to:
  /// **'我明白此操作无法撤销，且我已另有备份。'**
  String get vaultItemDeleteAgreeRisk;

  /// No description provided for @vaultItemDeletePasswordHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入主密码以确认删除'**
  String get vaultItemDeletePasswordHint;

  /// No description provided for @vaultItemDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get vaultItemDeleteConfirm;

  /// No description provided for @vaultItemDeleteSuccess.
  ///
  /// In zh, this message translates to:
  /// **'密钥已删除'**
  String get vaultItemDeleteSuccess;

  /// No description provided for @vaultItemFooterNote.
  ///
  /// In zh, this message translates to:
  /// **'不提供复制；本页禁止截屏'**
  String get vaultItemFooterNote;

  /// No description provided for @vaultItemRecordingWarning.
  ///
  /// In zh, this message translates to:
  /// **'检测到录屏，已隐藏敏感内容'**
  String get vaultItemRecordingWarning;

  /// No description provided for @vaultItemEditNameTitle.
  ///
  /// In zh, this message translates to:
  /// **'修改条目名称'**
  String get vaultItemEditNameTitle;

  /// No description provided for @vaultItemEditNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get vaultItemEditNameLabel;

  /// No description provided for @vaultDeriveTitle.
  ///
  /// In zh, this message translates to:
  /// **'派生地址'**
  String get vaultDeriveTitle;

  /// No description provided for @vaultDeriveNotice.
  ///
  /// In zh, this message translates to:
  /// **'以下地址由你的密钥计算得出，仅地址会被用于查询余额，密钥不会离开保险库。'**
  String get vaultDeriveNotice;

  /// No description provided for @vaultDeriveSchemeEvmStandard.
  ///
  /// In zh, this message translates to:
  /// **'标准（MetaMask 等）'**
  String get vaultDeriveSchemeEvmStandard;

  /// No description provided for @vaultDeriveSchemeEvmLedgerLive.
  ///
  /// In zh, this message translates to:
  /// **'Ledger Live'**
  String get vaultDeriveSchemeEvmLedgerLive;

  /// No description provided for @vaultDeriveSchemeBtcNativeSegwit.
  ///
  /// In zh, this message translates to:
  /// **'原生隔离见证 bc1q（默认）'**
  String get vaultDeriveSchemeBtcNativeSegwit;

  /// No description provided for @vaultDeriveSchemeBtcTaproot.
  ///
  /// In zh, this message translates to:
  /// **'Taproot bc1p'**
  String get vaultDeriveSchemeBtcTaproot;

  /// No description provided for @vaultDeriveSchemeBtcNestedSegwit.
  ///
  /// In zh, this message translates to:
  /// **'嵌套隔离见证 3 开头'**
  String get vaultDeriveSchemeBtcNestedSegwit;

  /// No description provided for @vaultDeriveSchemeBtcLegacy.
  ///
  /// In zh, this message translates to:
  /// **'传统 1 开头'**
  String get vaultDeriveSchemeBtcLegacy;

  /// No description provided for @vaultDeriveSchemeSolanaStandard.
  ///
  /// In zh, this message translates to:
  /// **'标准（Phantom 等）'**
  String get vaultDeriveSchemeSolanaStandard;

  /// No description provided for @vaultDeriveSchemeSolanaLegacy.
  ///
  /// In zh, this message translates to:
  /// **'旧式'**
  String get vaultDeriveSchemeSolanaLegacy;

  /// No description provided for @vaultDeriveSchemeTronStandard.
  ///
  /// In zh, this message translates to:
  /// **'标准'**
  String get vaultDeriveSchemeTronStandard;

  /// No description provided for @vaultDeriveAlreadyWatched.
  ///
  /// In zh, this message translates to:
  /// **'已在观察'**
  String get vaultDeriveAlreadyWatched;

  /// No description provided for @vaultDeriveShowMore.
  ///
  /// In zh, this message translates to:
  /// **'显示更多'**
  String get vaultDeriveShowMore;

  /// No description provided for @vaultDeriveCheckBalance.
  ///
  /// In zh, this message translates to:
  /// **'检测余额'**
  String get vaultDeriveCheckBalance;

  /// No description provided for @vaultDeriveCheckingBalance.
  ///
  /// In zh, this message translates to:
  /// **'正在检测...'**
  String get vaultDeriveCheckingBalance;

  /// No description provided for @vaultDeriveActive.
  ///
  /// In zh, this message translates to:
  /// **'有活动'**
  String get vaultDeriveActive;

  /// No description provided for @vaultDeriveInactive.
  ///
  /// In zh, this message translates to:
  /// **'无活动'**
  String get vaultDeriveInactive;

  /// No description provided for @vaultDeriveCheckNotice.
  ///
  /// In zh, this message translates to:
  /// **'检测余额将向公开节点查询该地址是否有交易活动或余额，密钥不会离开设备。'**
  String get vaultDeriveCheckNotice;

  /// No description provided for @vaultDeriveTargetAccount.
  ///
  /// In zh, this message translates to:
  /// **'目标账户'**
  String get vaultDeriveTargetAccount;

  /// No description provided for @vaultDeriveNewAccount.
  ///
  /// In zh, this message translates to:
  /// **'新建钱包账户'**
  String get vaultDeriveNewAccount;

  /// No description provided for @vaultDeriveExistingAccount.
  ///
  /// In zh, this message translates to:
  /// **'加入已有账户'**
  String get vaultDeriveExistingAccount;

  /// No description provided for @vaultDeriveNewAccountNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'账户名称'**
  String get vaultDeriveNewAccountNameLabel;

  /// No description provided for @vaultDeriveSelectAccountHint.
  ///
  /// In zh, this message translates to:
  /// **'选择已有钱包账户'**
  String get vaultDeriveSelectAccountHint;

  /// No description provided for @vaultDeriveAttachAction.
  ///
  /// In zh, this message translates to:
  /// **'加入观察'**
  String get vaultDeriveAttachAction;

  /// No description provided for @vaultDeriveSkipAction.
  ///
  /// In zh, this message translates to:
  /// **'跳过'**
  String get vaultDeriveSkipAction;

  /// No description provided for @vaultDeriveSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已成功加入观察'**
  String get vaultDeriveSuccess;

  /// No description provided for @vaultDeriveNoSelection.
  ///
  /// In zh, this message translates to:
  /// **'请至少选择一个地址'**
  String get vaultDeriveNoSelection;

  /// No description provided for @vaultDeriveAuthPrompt.
  ///
  /// In zh, this message translates to:
  /// **'请输入主密码以计算派生地址'**
  String get vaultDeriveAuthPrompt;

  /// No description provided for @vaultDeriveVerifyTitle.
  ///
  /// In zh, this message translates to:
  /// **'验证主密码'**
  String get vaultDeriveVerifyTitle;

  /// No description provided for @vaultDeriveVerifyConfirm.
  ///
  /// In zh, this message translates to:
  /// **'开始派生'**
  String get vaultDeriveVerifyConfirm;

  /// No description provided for @vaultDeriveDeriving.
  ///
  /// In zh, this message translates to:
  /// **'正在派生地址...'**
  String get vaultDeriveDeriving;

  /// No description provided for @vaultDeriveEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无派生地址'**
  String get vaultDeriveEmpty;

  /// No description provided for @vaultDeriveItemNotFound.
  ///
  /// In zh, this message translates to:
  /// **'未找到密钥条目'**
  String get vaultDeriveItemNotFound;

  /// No description provided for @settingsSecuritySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'PIN 码、面容/指纹解锁、自动锁定与保险库设置'**
  String get settingsSecuritySubtitle;

  /// No description provided for @securityTitle.
  ///
  /// In zh, this message translates to:
  /// **'安全设置'**
  String get securityTitle;

  /// No description provided for @securityChangePin.
  ///
  /// In zh, this message translates to:
  /// **'修改 PIN'**
  String get securityChangePin;

  /// No description provided for @securityChangePinSuccess.
  ///
  /// In zh, this message translates to:
  /// **'PIN 码已修改'**
  String get securityChangePinSuccess;

  /// No description provided for @securityChangePinOldTitle.
  ///
  /// In zh, this message translates to:
  /// **'输入当前 PIN'**
  String get securityChangePinOldTitle;

  /// No description provided for @securityChangePinOldSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'请输入当前使用的 6 位数字 PIN'**
  String get securityChangePinOldSubtitle;

  /// No description provided for @securityChangePinNewTitle.
  ///
  /// In zh, this message translates to:
  /// **'输入新 PIN'**
  String get securityChangePinNewTitle;

  /// No description provided for @securityChangePinNewSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'请输入新的 6 位数字 PIN'**
  String get securityChangePinNewSubtitle;

  /// No description provided for @securityChangePinConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认新 PIN'**
  String get securityChangePinConfirmTitle;

  /// No description provided for @securityChangePinConfirmSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'请再次输入新的 6 位数字 PIN'**
  String get securityChangePinConfirmSubtitle;

  /// No description provided for @securityChangePinMismatch.
  ///
  /// In zh, this message translates to:
  /// **'两次输入的 PIN 不一致，请重新输入'**
  String get securityChangePinMismatch;

  /// No description provided for @securityChangePinWrongOld.
  ///
  /// In zh, this message translates to:
  /// **'原 PIN 码不正确'**
  String get securityChangePinWrongOld;

  /// No description provided for @securityAppBiometricsDesc.
  ///
  /// In zh, this message translates to:
  /// **'解锁 OneWallet 时使用生物识别'**
  String get securityAppBiometricsDesc;

  /// No description provided for @securityVaultBiometricsUninitialized.
  ///
  /// In zh, this message translates to:
  /// **'保险库尚未创建'**
  String get securityVaultBiometricsUninitialized;

  /// No description provided for @securityVaultBiometricsUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'当前设备不支持硬件密钥保护'**
  String get securityVaultBiometricsUnsupported;

  /// No description provided for @securityChangeMasterPasswordTitle.
  ///
  /// In zh, this message translates to:
  /// **'修改主密码'**
  String get securityChangeMasterPasswordTitle;

  /// No description provided for @securityChangeMasterPasswordSuccess.
  ///
  /// In zh, this message translates to:
  /// **'主密码已修改'**
  String get securityChangeMasterPasswordSuccess;

  /// No description provided for @securityChangeMasterPasswordCurrent.
  ///
  /// In zh, this message translates to:
  /// **'当前主密码'**
  String get securityChangeMasterPasswordCurrent;

  /// No description provided for @securityChangeMasterPasswordCurrentHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入当前主密码'**
  String get securityChangeMasterPasswordCurrentHint;

  /// No description provided for @securityChangeMasterPasswordNew.
  ///
  /// In zh, this message translates to:
  /// **'新主密码（至少 10 个字符）'**
  String get securityChangeMasterPasswordNew;

  /// No description provided for @securityChangeMasterPasswordNewHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入至少 10 位新主密码'**
  String get securityChangeMasterPasswordNewHint;

  /// No description provided for @securityChangeMasterPasswordConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确认新主密码'**
  String get securityChangeMasterPasswordConfirm;

  /// No description provided for @securityChangeMasterPasswordConfirmHint.
  ///
  /// In zh, this message translates to:
  /// **'请再次输入新主密码'**
  String get securityChangeMasterPasswordConfirmHint;

  /// No description provided for @securityChangeMasterPasswordChanging.
  ///
  /// In zh, this message translates to:
  /// **'正在重新加密保险库…'**
  String get securityChangeMasterPasswordChanging;

  /// No description provided for @securityChangeMasterPasswordMismatch.
  ///
  /// In zh, this message translates to:
  /// **'两次输入的主密码不一致'**
  String get securityChangeMasterPasswordMismatch;

  /// No description provided for @securityChangeMasterPasswordTooShort.
  ///
  /// In zh, this message translates to:
  /// **'主密码长度至少为 10 个字符'**
  String get securityChangeMasterPasswordTooShort;

  /// No description provided for @securityChangeMasterPasswordWrongCurrent.
  ///
  /// In zh, this message translates to:
  /// **'当前主密码不正确'**
  String get securityChangeMasterPasswordWrongCurrent;

  /// No description provided for @securityChangeMasterPasswordConfirmAction.
  ///
  /// In zh, this message translates to:
  /// **'确认修改'**
  String get securityChangeMasterPasswordConfirmAction;

  /// No description provided for @securityDeviceCompromised.
  ///
  /// In zh, this message translates to:
  /// **'风险'**
  String get securityDeviceCompromised;

  /// No description provided for @securityDeviceCompromisedDesc.
  ///
  /// In zh, this message translates to:
  /// **'检测到设备环境异常，可能已被越狱或 root'**
  String get securityDeviceCompromisedDesc;

  /// No description provided for @securityVerifyMasterPasswordTitle.
  ///
  /// In zh, this message translates to:
  /// **'验证主密码'**
  String get securityVerifyMasterPasswordTitle;

  /// No description provided for @securityVerifyMasterPasswordHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入主密码以开启生物识别'**
  String get securityVerifyMasterPasswordHint;

  /// No description provided for @securityVerifyMasterPasswordConfirm.
  ///
  /// In zh, this message translates to:
  /// **'验证并开启'**
  String get securityVerifyMasterPasswordConfirm;

  /// No description provided for @securityCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get securityCancel;

  /// No description provided for @settingsBackupDesc.
  ///
  /// In zh, this message translates to:
  /// **'导出为独立解密文件或从文件恢复'**
  String get settingsBackupDesc;

  /// No description provided for @settingsBackupLastExport.
  ///
  /// In zh, this message translates to:
  /// **'上次导出 {date}'**
  String settingsBackupLastExport(Object date);

  /// No description provided for @settingsBackupUnbacked.
  ///
  /// In zh, this message translates to:
  /// **'有未备份的更改'**
  String get settingsBackupUnbacked;

  /// No description provided for @backupTitle.
  ///
  /// In zh, this message translates to:
  /// **'加密备份'**
  String get backupTitle;

  /// No description provided for @backupSensitiveBadge.
  ///
  /// In zh, this message translates to:
  /// **'敏感页面'**
  String get backupSensitiveBadge;

  /// No description provided for @backupExportSection.
  ///
  /// In zh, this message translates to:
  /// **'导出'**
  String get backupExportSection;

  /// No description provided for @backupExportSummaryTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认内容'**
  String get backupExportSummaryTitle;

  /// No description provided for @backupExportSummaryDesc.
  ///
  /// In zh, this message translates to:
  /// **'全部账户、地址、标签、备份清单状态、全部密钥条目、设置。不包含余额缓存与快照。'**
  String get backupExportSummaryDesc;

  /// No description provided for @backupExportIncludeExchange.
  ///
  /// In zh, this message translates to:
  /// **'包含交易所 API Key'**
  String get backupExportIncludeExchange;

  /// No description provided for @backupExportIncludeExchangeDesc.
  ///
  /// In zh, this message translates to:
  /// **'默认不包含。若勾选，将导出所有已连接交易所的 API Key 与 Secret'**
  String get backupExportIncludeExchangeDesc;

  /// No description provided for @backupExportStartButton.
  ///
  /// In zh, this message translates to:
  /// **'开始导出'**
  String get backupExportStartButton;

  /// No description provided for @backupRestoreSection.
  ///
  /// In zh, this message translates to:
  /// **'恢复'**
  String get backupRestoreSection;

  /// No description provided for @backupRestoreRowTitle.
  ///
  /// In zh, this message translates to:
  /// **'从备份文件恢复'**
  String get backupRestoreRowTitle;

  /// No description provided for @backupRestoreRowDesc.
  ///
  /// In zh, this message translates to:
  /// **'选择 .owbak 文件并输入备份密码'**
  String get backupRestoreRowDesc;

  /// No description provided for @backupFormatNote.
  ///
  /// In zh, this message translates to:
  /// **'备份格式是公开的。即使没有这个 app，也能用独立的解密工具在电脑上解开。'**
  String get backupFormatNote;

  /// No description provided for @backupUnbackedWarning.
  ///
  /// In zh, this message translates to:
  /// **'保险库在上次导出之后有变化，建议及时导出最新备份。'**
  String get backupUnbackedWarning;

  /// No description provided for @backupExportTitle.
  ///
  /// In zh, this message translates to:
  /// **'导出备份'**
  String get backupExportTitle;

  /// No description provided for @backupExportMasterPasswordTitle.
  ///
  /// In zh, this message translates to:
  /// **'输入主密码'**
  String get backupExportMasterPasswordTitle;

  /// No description provided for @backupExportMasterPasswordDesc.
  ///
  /// In zh, this message translates to:
  /// **'导出备份需要验证主密码，此处不接受面容或指纹'**
  String get backupExportMasterPasswordDesc;

  /// No description provided for @backupExportMasterPasswordHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入主密码'**
  String get backupExportMasterPasswordHint;

  /// No description provided for @backupExportPasswordTypeTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置备份密码'**
  String get backupExportPasswordTypeTitle;

  /// No description provided for @backupExportUseMasterPassword.
  ///
  /// In zh, this message translates to:
  /// **'使用主密码作为备份密码'**
  String get backupExportUseMasterPassword;

  /// No description provided for @backupExportUseCustomPassword.
  ///
  /// In zh, this message translates to:
  /// **'另设备份密码'**
  String get backupExportUseCustomPassword;

  /// No description provided for @backupExportCustomPasswordHint.
  ///
  /// In zh, this message translates to:
  /// **'输入备份密码（至少 10 位）'**
  String get backupExportCustomPasswordHint;

  /// No description provided for @backupExportCustomPasswordConfirmHint.
  ///
  /// In zh, this message translates to:
  /// **'确认备份密码'**
  String get backupExportCustomPasswordConfirmHint;

  /// No description provided for @backupExportPasswordMismatch.
  ///
  /// In zh, this message translates to:
  /// **'两次输入的备份密码不一致'**
  String get backupExportPasswordMismatch;

  /// No description provided for @backupExportPasswordTooShort.
  ///
  /// In zh, this message translates to:
  /// **'备份密码长度至少为 10 个字符'**
  String get backupExportPasswordTooShort;

  /// No description provided for @backupExportAsciiNotice.
  ///
  /// In zh, this message translates to:
  /// **'建议使用英文字母、数字和符号，避免在跨平台独立解密工具中出现编码差异'**
  String get backupExportAsciiNotice;

  /// No description provided for @backupExportGenerating.
  ///
  /// In zh, this message translates to:
  /// **'正在生成加密备份文件...'**
  String get backupExportGenerating;

  /// No description provided for @backupExportSuccessTitle.
  ///
  /// In zh, this message translates to:
  /// **'备份已生成'**
  String get backupExportSuccessTitle;

  /// No description provided for @backupExportSaveAdvice.
  ///
  /// In zh, this message translates to:
  /// **'通过系统分享面板保存。请存到手机以外的地方（如离线 U 盘、可信电脑或加密存储）。'**
  String get backupExportSaveAdvice;

  /// No description provided for @backupExportSavedButton.
  ///
  /// In zh, this message translates to:
  /// **'我已保存到安全位置'**
  String get backupExportSavedButton;

  /// No description provided for @backupExportShareFailed.
  ///
  /// In zh, this message translates to:
  /// **'导出或分享文件失败，请重试'**
  String get backupExportShareFailed;

  /// No description provided for @backupExportDoneNotice.
  ///
  /// In zh, this message translates to:
  /// **'上次导出时间已更新'**
  String get backupExportDoneNotice;

  /// No description provided for @backupRestoreTitle.
  ///
  /// In zh, this message translates to:
  /// **'恢复备份'**
  String get backupRestoreTitle;

  /// No description provided for @backupRestoreSelectFile.
  ///
  /// In zh, this message translates to:
  /// **'选择 .owbak 备份文件'**
  String get backupRestoreSelectFile;

  /// No description provided for @backupRestoreSelectedFile.
  ///
  /// In zh, this message translates to:
  /// **'已选文件：{name} ({size})'**
  String backupRestoreSelectedFile(Object name, Object size);

  /// No description provided for @backupRestorePasswordHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入备份密码'**
  String get backupRestorePasswordHint;

  /// No description provided for @backupRestoreParseButton.
  ///
  /// In zh, this message translates to:
  /// **'解析备份文件'**
  String get backupRestoreParseButton;

  /// No description provided for @backupRestoreParsing.
  ///
  /// In zh, this message translates to:
  /// **'正在解析备份文件...'**
  String get backupRestoreParsing;

  /// No description provided for @backupRestorePreviewTitle.
  ///
  /// In zh, this message translates to:
  /// **'备份内容预览'**
  String get backupRestorePreviewTitle;

  /// No description provided for @backupRestoreCreatedAt.
  ///
  /// In zh, this message translates to:
  /// **'创建时间：{date}'**
  String backupRestoreCreatedAt(Object date);

  /// No description provided for @backupRestoreAppVersion.
  ///
  /// In zh, this message translates to:
  /// **'备份应用版本：{version}'**
  String backupRestoreAppVersion(Object version);

  /// No description provided for @backupRestoreAccountsCount.
  ///
  /// In zh, this message translates to:
  /// **'包含账户：{count} 个'**
  String backupRestoreAccountsCount(Object count);

  /// No description provided for @backupRestoreAddressesCount.
  ///
  /// In zh, this message translates to:
  /// **'包含地址：{count} 个'**
  String backupRestoreAddressesCount(Object count);

  /// No description provided for @backupRestoreVaultItemsCount.
  ///
  /// In zh, this message translates to:
  /// **'包含密钥条目：{count} 个'**
  String backupRestoreVaultItemsCount(Object count);

  /// No description provided for @backupRestoreCredentialsCount.
  ///
  /// In zh, this message translates to:
  /// **'包含交易所凭据：{count} 个'**
  String backupRestoreCredentialsCount(Object count);

  /// No description provided for @backupRestoreSkippedUnreadable.
  ///
  /// In zh, this message translates to:
  /// **'有 {count} 项数据格式无法读取，将被跳过'**
  String backupRestoreSkippedUnreadable(Object count);

  /// No description provided for @backupRestoreModeFreshTitle.
  ///
  /// In zh, this message translates to:
  /// **'全新设备恢复'**
  String get backupRestoreModeFreshTitle;

  /// No description provided for @backupRestoreModeFreshDesc.
  ///
  /// In zh, this message translates to:
  /// **'将在本地创建新保险库并导入备份中所有数据。'**
  String get backupRestoreModeFreshDesc;

  /// No description provided for @backupRestoreModeMergeTitle.
  ///
  /// In zh, this message translates to:
  /// **'合并导入'**
  String get backupRestoreModeMergeTitle;

  /// No description provided for @backupRestoreModeMergeDesc.
  ///
  /// In zh, this message translates to:
  /// **'将备份内容合并到当前数据中。相同条目与地址自动跳过，重名账户自动添加序号后缀。'**
  String get backupRestoreModeMergeDesc;

  /// No description provided for @backupRestoreMasterPasswordHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入本地保险库主密码'**
  String get backupRestoreMasterPasswordHint;

  /// No description provided for @backupRestoreNewMasterPasswordHint.
  ///
  /// In zh, this message translates to:
  /// **'为本机保险库设置主密码（至少 10 位）'**
  String get backupRestoreNewMasterPasswordHint;

  /// No description provided for @backupRestoreSameAsBackupPassword.
  ///
  /// In zh, this message translates to:
  /// **'沿用备份密码作为本机主密码'**
  String get backupRestoreSameAsBackupPassword;

  /// No description provided for @backupRestoreExecuteButton.
  ///
  /// In zh, this message translates to:
  /// **'开始恢复'**
  String get backupRestoreExecuteButton;

  /// No description provided for @backupRestoreRestoring.
  ///
  /// In zh, this message translates to:
  /// **'正在恢复数据...'**
  String get backupRestoreRestoring;

  /// No description provided for @backupRestoreResultTitle.
  ///
  /// In zh, this message translates to:
  /// **'恢复完成'**
  String get backupRestoreResultTitle;

  /// No description provided for @backupRestoreResultAdded.
  ///
  /// In zh, this message translates to:
  /// **'成功导入：{accounts} 个账户、{addresses} 个地址、{items} 个密钥'**
  String backupRestoreResultAdded(
    Object accounts,
    Object addresses,
    Object items,
  );

  /// No description provided for @backupRestoreResultSkipped.
  ///
  /// In zh, this message translates to:
  /// **'跳过重复：{accounts} 个账户、{addresses} 个地址、{items} 个密钥'**
  String backupRestoreResultSkipped(
    Object accounts,
    Object addresses,
    Object items,
  );

  /// No description provided for @backupRestoreFinishButton.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get backupRestoreFinishButton;

  /// No description provided for @backupRestoreWrongPassword.
  ///
  /// In zh, this message translates to:
  /// **'密码不正确或文件已损坏'**
  String get backupRestoreWrongPassword;

  /// No description provided for @backupRestoreCorrupted.
  ///
  /// In zh, this message translates to:
  /// **'这不是 OneWallet 的备份文件，或文件已损坏，无法读取'**
  String get backupRestoreCorrupted;

  /// No description provided for @backupRestoreUnsupportedVersion.
  ///
  /// In zh, this message translates to:
  /// **'这个备份文件来自更新版本的 OneWallet，当前版本无法读取'**
  String get backupRestoreUnsupportedVersion;

  /// No description provided for @backupRestoreTargetNotEmpty.
  ///
  /// In zh, this message translates to:
  /// **'本地已有数据，无法以初始模式恢复'**
  String get backupRestoreTargetNotEmpty;

  /// No description provided for @backupUnbackedBanner.
  ///
  /// In zh, this message translates to:
  /// **'保险库有未备份的更改，建议及时导出备份'**
  String get backupUnbackedBanner;

  /// No description provided for @backupGoBackup.
  ///
  /// In zh, this message translates to:
  /// **'去备份'**
  String get backupGoBackup;
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
