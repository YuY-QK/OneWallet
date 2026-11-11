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
}
