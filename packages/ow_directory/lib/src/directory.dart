import 'dart:convert';

import 'package:ow_domain/ow_domain.dart';

import 'directory_data.g.dart';
import 'directory_entry.dart';
import 'directory_enums.dart';

/// 第三方目录的只读查询入口。
///
/// 解析规则（向前兼容）：遇到未知的 kind，跳过整个条目；遇到未知的 link 键，
/// 跳过该链接；两种情况都继续解析其余内容。顶层结构不合法时得到空目录。
final class ThirdPartyDirectory {
  ThirdPartyDirectory(Iterable<DirectoryEntry> entries)
    : all = List.unmodifiable(entries) {
    _byId = {for (final e in all) e.id: e};
  }

  /// 内置目录（由 `data/directory.json` 生成的内嵌常量解析而来）。
  factory ThirdPartyDirectory.builtin() =>
      ThirdPartyDirectory.fromJson(directoryJson);

  /// 从 JSON 文本解析。格式不合法时返回空目录。
  factory ThirdPartyDirectory.fromJson(String json) {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      return ThirdPartyDirectory(const []);
    }
    final raw = decoded is Map ? decoded['entries'] : null;
    if (raw is! List) return ThirdPartyDirectory(const []);
    final seen = <String>{};
    final entries = <DirectoryEntry>[];
    for (final item in raw) {
      final e = DirectoryEntry.fromJson(item);
      if (e != null && seen.add(e.id)) entries.add(e);
    }
    return ThirdPartyDirectory(entries);
  }

  /// 全部条目，保持文件中的顺序。
  final List<DirectoryEntry> all;
  late final Map<String, DirectoryEntry> _byId;

  /// 仅已核对的条目。app 只展示这些。
  List<DirectoryEntry> get verifiedOnly =>
      all.where((e) => e.isVerified).toList(growable: false);

  DirectoryEntry? byId(String id) => _byId[id];

  List<DirectoryEntry> byKind(DirectoryKind kind) =>
      all.where((e) => e.kind == kind).toList(growable: false);

  /// 按名称与别名搜索，不区分大小写，子串匹配。空查询返回全部。
  List<DirectoryEntry> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where(
          (e) =>
              e.name.toLowerCase().contains(q) ||
              e.aliases.any((a) => a.toLowerCase().contains(q)),
        )
        .toList(growable: false);
  }

  /// 已接入交易所对应的条目。
  DirectoryEntry? forExchange(ExchangeId id) {
    for (final e in all) {
      if (e.kind == DirectoryKind.exchange &&
          e.exchange?.domainExchangeId == id.name) {
        return e;
      }
    }
    return null;
  }

  /// 某条链的主区块浏览器（文件中排在最前的那个）。
  DirectoryEntry? explorerFor(String chainId) =>
      explorersFor(chainId).firstOrNull;

  /// 某条链的全部区块浏览器条目。
  List<DirectoryEntry> explorersFor(String chainId) =>
      all.where((e) => e.explorer?.chainId == chainId).toList(growable: false);
}
