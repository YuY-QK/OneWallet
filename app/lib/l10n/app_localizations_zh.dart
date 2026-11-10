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
}
