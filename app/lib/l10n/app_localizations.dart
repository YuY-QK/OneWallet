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

  /// No description provided for @settingsPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'设置项将在后续里程碑加入。'**
  String get settingsPlaceholder;

  /// No description provided for @notAvailableYet.
  ///
  /// In zh, this message translates to:
  /// **'此功能尚未实现'**
  String get notAvailableYet;
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
