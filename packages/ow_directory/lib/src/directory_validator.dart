import 'dart:convert';

import 'package:ow_domain/ow_domain.dart';

import 'directory_enums.dart';

/// 目录数据的校验器。供测试与今后补充数据的人使用。
///
/// 直接检查原始 JSON（而不是解析后的对象），这样非法枚举值等问题能被报出来，
/// 而不是被解析器静默跳过。返回问题列表，空列表表示通过。
abstract final class DirectoryValidator {
  static final _idPattern = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');
  static final _domainPattern = RegExp(r'^(?!-)[a-z0-9-]+(\.[a-z0-9-]+)+$');
  static final _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// 不允许单独作为官方域名的共享托管域名（任何人都能在其下建站）。
  static const sharedHostingDomains = {
    'github.io',
    'github.com',
    'gitbook.io',
    'notion.site',
    'medium.com',
    'vercel.app',
    'netlify.app',
    'pages.dev',
    'web.app',
    'firebaseapp.com',
    'herokuapp.com',
    'readthedocs.io',
    'wixsite.com',
    'blogspot.com',
    'google.com',
    'twitter.com',
    'x.com',
    'telegram.org',
    't.me',
  };

  /// 推广、邀请返佣参数的特征。
  static final _promoPatterns = <RegExp>[
    RegExp('ref=', caseSensitive: false),
    RegExp('referral', caseSensitive: false),
    RegExp('utm_', caseSensitive: false),
    RegExp('invite', caseSensitive: false),
    // aff 只在路径段或参数名开头匹配，避免误伤 staff 之类的词。
    RegExp(r'(^|[/?&=_#-])aff', caseSensitive: false),
  ];

  /// 校验 JSON 文本。
  static List<String> validateJson(String json) {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException catch (e) {
      return ['不是合法 JSON：${e.message}'];
    }
    return validate(decoded);
  }

  /// 校验已解码的 JSON。
  static List<String> validate(Object? decoded) {
    final problems = <String>[];
    if (decoded is! Map || decoded['entries'] is! List) {
      return ['顶层必须是含 entries 数组的对象'];
    }
    final ids = <String>{};
    for (final (index, raw) in (decoded['entries']! as List).indexed) {
      if (raw is! Map) {
        problems.add('第 $index 项不是对象');
        continue;
      }
      final id = raw['id'];
      final label = id is String ? id : '#$index';
      void add(String message) => problems.add('$label：$message');

      if (id is! String || !_idPattern.hasMatch(id)) {
        add('id 必须由小写字母、数字、连字符组成（不能以连字符开头或结尾）');
      } else if (!ids.add(id)) {
        add('id 重复');
      }
      final name = raw['name'];
      if (name is! String || name.trim().isEmpty) add('name 不能为空');

      final kind = DirectoryKind.parse(raw['kind']);
      if (kind == null) add('kind 取值非法：${raw['kind']}');
      if (IntegrationLevel.parse(raw['integration']) == null) {
        add('integration 取值非法：${raw['integration']}');
      }
      final aliases = raw['aliases'];
      if (aliases != null && (aliases is! List || aliases.any(_notString))) {
        add('aliases 必须是字符串数组');
      }

      final domains = _validateDomains(raw['officialDomains'], add);
      _validateLinks(raw['links'], domains, add);
      _validateWallet(raw['wallet'], kind, add);
      _validateExchange(raw['exchange'], kind, raw['integration'], add);
      _validateExplorer(raw['explorer'], kind, domains, add);
      _validateVerification(raw, add);
    }
    return problems;
  }

  static bool _notString(Object? v) => v is! String;

  static List<String> _validateDomains(Object? raw, void Function(String) add) {
    if (raw is! List || raw.isEmpty || raw.any(_notString)) {
      add('officialDomains 必须是非空的字符串数组');
      return const [];
    }
    final domains = raw.cast<String>();
    for (final d in domains) {
      if (!_domainPattern.hasMatch(d)) {
        add('officialDomains 中的 "$d" 必须是小写域名，不带协议、路径和端口');
      } else if (sharedHostingDomains.contains(d)) {
        add('officialDomains 中的 "$d" 是共享托管域名，不能作为官方域名');
      }
    }
    return domains;
  }

  static void _validateLinks(
    Object? raw,
    List<String> domains,
    void Function(String) add,
  ) {
    if (raw == null) return;
    if (raw is! Map) {
      add('links 必须是对象');
      return;
    }
    for (final e in raw.entries) {
      if (LinkKind.parse(e.key) == null) {
        add('links 含未知的键 "${e.key}"');
        continue;
      }
      final problem = checkUrl(e.value, domains);
      if (problem != null) add('链接 ${e.key}：$problem');
    }
  }

  /// 检查一条链接，合格返回 null，否则返回原因。
  static String? checkUrl(Object? value, List<String> domains) {
    if (value is! String) return '必须是字符串';
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasAuthority) return '不是合法的绝对地址';
    if (uri.scheme != 'https') return '必须使用 https';
    if (uri.userInfo.isNotEmpty) return '不得包含用户名或密码';
    if (uri.hasPort && uri.port != 443) return '不得使用非标准端口';
    for (final p in _promoPatterns) {
      if (p.hasMatch(value)) return '含推广或邀请参数（${p.pattern}）';
    }
    final host = uri.host.toLowerCase();
    final owned = domains.any((d) => host == d || host.endsWith('.$d'));
    if (!owned) return '主机名 $host 不属于 officialDomains';
    return null;
  }

  static void _validateWallet(
    Object? raw,
    DirectoryKind? kind,
    void Function(String) add,
  ) {
    if (raw == null) return;
    if (kind != null && !kind.isWalletLike) {
      add('只有 wallet 与 hardwareWallet 可以带 wallet 子结构');
    }
    if (raw is! Map) {
      add('wallet 必须是对象');
      return;
    }
    if (WalletCustody.parse(raw['custody']) == null) {
      add('wallet.custody 取值非法：${raw['custody']}');
    }
    final exportable = raw['exportable'];
    if (exportable != null && exportable is! bool) {
      add('wallet.exportable 必须是布尔值或 null');
    }
    final families = raw['families'];
    if (families is! List) {
      add('wallet.families 必须是数组');
    } else {
      final valid = ChainFamily.values.map((f) => f.name).toSet();
      for (final f in families) {
        if (f is! String || !valid.contains(f)) {
          add('wallet.families 含非法取值：$f');
        }
      }
    }
  }

  static void _validateExchange(
    Object? raw,
    DirectoryKind? kind,
    Object? integration,
    void Function(String) add,
  ) {
    if (raw == null) return;
    if (kind != null && kind != DirectoryKind.exchange) {
      add('只有 exchange 可以带 exchange 子结构');
    }
    if (raw is! Map) {
      add('exchange 必须是对象');
      return;
    }
    final id = raw['domainExchangeId'];
    if (id is! String || !ExchangeId.values.any((e) => e.name == id)) {
      add('exchange.domainExchangeId 不是合法的 ExchangeId：$id');
    }
  }

  static void _validateExplorer(
    Object? raw,
    DirectoryKind? kind,
    List<String> domains,
    void Function(String) add,
  ) {
    if (kind == DirectoryKind.explorer && raw == null) {
      add('explorer 类条目必须有 explorer 子结构');
    }
    if (raw == null) return;
    if (kind != null &&
        kind != DirectoryKind.explorer &&
        kind != DirectoryKind.dataProvider) {
      add('只有 explorer 与 dataProvider 可以带 explorer 子结构');
    }
    if (raw is! Map) {
      add('explorer 必须是对象');
      return;
    }
    final chainId = raw['chainId'];
    if (chainId is! String || !Chains.all.any((c) => c.id == chainId)) {
      add('explorer.chainId 在 Chains 中不存在：$chainId');
    }
    final template = raw['addressUrlTemplate'];
    if (template is! String || !template.contains('{address}')) {
      add('explorer.addressUrlTemplate 必须含 {address}');
    } else {
      // 占位符不是合法的 URL 字符，换成示例字符串后按普通链接检查。
      final problem = checkUrl(template.replaceAll('{address}', 'x'), domains);
      if (problem != null) add('explorer.addressUrlTemplate：$problem');
    }
  }

  static void _validateVerification(
    Map<Object?, Object?> raw,
    void Function(String) add,
  ) {
    final verifiedAt = raw['verifiedAt'];
    final sources = raw['sources'];
    if (sources != null && (sources is! List || sources.any(_notString))) {
      add('sources 必须是字符串数组');
    }
    if (verifiedAt == null) return;
    if (verifiedAt is! String || !_datePattern.hasMatch(verifiedAt)) {
      add('verifiedAt 必须是 yyyy-MM-dd 或 null');
      return;
    }
    if (sources is! List || sources.isEmpty) {
      add('已核对（verifiedAt 非空）的条目必须至少有一个 source');
    } else {
      for (final s in sources) {
        final uri = s is String ? Uri.tryParse(s) : null;
        if (uri == null || uri.scheme != 'https' || !uri.hasAuthority) {
          add('source 必须是 https 地址：$s');
        }
      }
    }
  }
}
