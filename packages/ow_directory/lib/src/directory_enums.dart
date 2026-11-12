/// 条目类别。JSON 中使用 [wireName]。
enum DirectoryKind {
  exchange('exchange'),
  wallet('wallet'),
  dataProvider('dataProvider'),
  explorer('explorer'),
  hardwareWallet('hardwareWallet');

  const DirectoryKind(this.wireName);
  final String wireName;

  /// 未知取值返回 null（调用方跳过该条目，向前兼容）。
  static DirectoryKind? parse(Object? raw) {
    for (final v in values) {
      if (v.wireName == raw) return v;
    }
    return null;
  }

  /// 该类别是否可以带 `wallet` 子结构。
  bool get isWalletLike => this == wallet || this == hardwareWallet;
}

/// 链接类别。键只能取这些值。
enum LinkKind {
  website('website'),
  apiDocs('apiDocs'),
  apiKeyGuide('apiKeyGuide'),
  apiKeyManagement('apiKeyManagement'),
  exportKeyGuide('exportKeyGuide'),
  helpCenter('helpCenter'),
  status('status'),
  download('download'),
  signup('signup'),
  pricing('pricing');

  const LinkKind(this.wireName);
  final String wireName;

  /// 未知取值返回 null（调用方跳过该链接，向前兼容）。
  static LinkKind? parse(Object? raw) {
    for (final v in values) {
      if (v.wireName == raw) return v;
    }
    return null;
  }
}

/// 本应用对该第三方的接入程度。
enum IntegrationLevel {
  /// 本应用已接入。
  integrated('integrated'),

  /// 计划接入。
  planned('planned'),

  /// 仅收录，未接入。
  none('none');

  const IntegrationLevel(this.wireName);
  final String wireName;

  static IntegrationLevel? parse(Object? raw) {
    for (final v in values) {
      if (v.wireName == raw) return v;
    }
    return null;
  }
}

/// 钱包的托管方式。
enum WalletCustody {
  /// 用户自持助记词或私钥。
  selfCustody('selfCustody'),

  /// 多方计算（无完整助记词）。
  mpc('mpc'),

  /// 托管。
  custodial('custodial');

  const WalletCustody(this.wireName);
  final String wireName;

  static WalletCustody? parse(Object? raw) {
    for (final v in values) {
      if (v.wireName == raw) return v;
    }
    return null;
  }
}
