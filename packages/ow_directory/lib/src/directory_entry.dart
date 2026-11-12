import 'directory_enums.dart';

/// 钱包类条目的附加信息（仅 kind 为 wallet 或 hardwareWallet）。
final class WalletInfo {
  const WalletInfo({
    required this.custody,
    required this.exportable,
    required this.families,
  });

  final WalletCustody custody;

  /// 能否导出助记词或私钥；不确定为 null。
  final bool? exportable;

  /// ow_domain 的 ChainFamily 名称，可为空。
  final List<String> families;
}

/// 已接入交易所的对应关系（仅已接入的交易所）。
final class ExchangeInfo {
  const ExchangeInfo({required this.domainExchangeId});

  /// ow_domain 的 ExchangeId 名称。
  final String domainExchangeId;
}

/// 区块浏览器信息。
final class ExplorerInfo {
  const ExplorerInfo({required this.chainId, required this.addressUrlTemplate});

  /// ow_domain 的 Chains 中的链 id。
  final String chainId;

  /// 含 `{address}` 占位符。
  final String addressUrlTemplate;

  /// 把 [address] 代入模板。
  String addressUrl(String address) =>
      addressUrlTemplate.replaceAll('{address}', address);
}

/// 目录条目。全部不可变。
final class DirectoryEntry {
  const DirectoryEntry({
    required this.id,
    required this.kind,
    required this.name,
    required this.aliases,
    required this.officialDomains,
    required this.links,
    required this.integration,
    required this.verifiedAt,
    required this.sources,
    required this.notes,
    this.wallet,
    this.exchange,
    this.explorer,
  });

  /// 小写字母、数字、连字符；全局唯一；一经发布不改。
  final String id;
  final DirectoryKind kind;
  final String name;
  final List<String> aliases;

  /// 该条目所有链接的主机名必须等于其中之一或是其子域。
  final List<String> officialDomains;
  final Map<LinkKind, String> links;
  final IntegrationLevel integration;
  final WalletInfo? wallet;
  final ExchangeInfo? exchange;
  final ExplorerInfo? explorer;

  /// 核对日期（yyyy-MM-dd）；未核对为 null。
  final String? verifiedAt;
  final List<String> sources;
  final String notes;

  /// 是否已核对。app 只展示已核对的条目。
  bool get isVerified => verifiedAt != null;

  String? link(LinkKind kind) => links[kind];

  /// 从已解码的 JSON 解析。kind 未知或结构不合法返回 null（调用方跳过）。
  ///
  /// 未知的 link 键被丢弃；未知的 integration 视为 none；
  /// wallet 子结构的 custody 未知时整个子结构视为缺失。
  static DirectoryEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final name = raw['name'];
    final kind = DirectoryKind.parse(raw['kind']);
    if (id is! String || name is! String || kind == null) return null;

    final links = <LinkKind, String>{};
    final rawLinks = raw['links'];
    if (rawLinks is Map) {
      for (final e in rawLinks.entries) {
        final k = LinkKind.parse(e.key);
        final v = e.value;
        if (k != null && v is String) links[k] = v;
      }
    }

    WalletInfo? wallet;
    final rawWallet = raw['wallet'];
    if (rawWallet is Map) {
      final custody = WalletCustody.parse(rawWallet['custody']);
      if (custody != null) {
        final exportable = rawWallet['exportable'];
        wallet = WalletInfo(
          custody: custody,
          exportable: exportable is bool ? exportable : null,
          families: _strings(rawWallet['families']),
        );
      }
    }

    ExchangeInfo? exchange;
    final rawExchange = raw['exchange'];
    if (rawExchange is Map && rawExchange['domainExchangeId'] is String) {
      exchange = ExchangeInfo(
        domainExchangeId: rawExchange['domainExchangeId']! as String,
      );
    }

    ExplorerInfo? explorer;
    final rawExplorer = raw['explorer'];
    if (rawExplorer is Map &&
        rawExplorer['chainId'] is String &&
        rawExplorer['addressUrlTemplate'] is String) {
      explorer = ExplorerInfo(
        chainId: rawExplorer['chainId']! as String,
        addressUrlTemplate: rawExplorer['addressUrlTemplate']! as String,
      );
    }

    final verifiedAt = raw['verifiedAt'];
    final notes = raw['notes'];
    return DirectoryEntry(
      id: id,
      kind: kind,
      name: name,
      aliases: _strings(raw['aliases']),
      officialDomains: _strings(raw['officialDomains']),
      links: Map.unmodifiable(links),
      integration:
          IntegrationLevel.parse(raw['integration']) ?? IntegrationLevel.none,
      wallet: wallet,
      exchange: exchange,
      explorer: explorer,
      verifiedAt: verifiedAt is String ? verifiedAt : null,
      sources: _strings(raw['sources']),
      notes: notes is String ? notes : '',
    );
  }
}

List<String> _strings(Object? raw) =>
    raw is List ? List.unmodifiable(raw.whereType<String>()) : const <String>[];
