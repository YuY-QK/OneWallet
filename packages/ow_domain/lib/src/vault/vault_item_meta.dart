import '../chain/chain_family.dart';

/// 保险库条目的类型。
enum VaultItemKind { mnemonic, privateKey }

/// 保险库条目的非敏感元数据，存于数据库，用于列表显示与查重。
///
/// 不含任何密钥内容；明文只在保险库会话中读取。
final class VaultItemMeta {
  const VaultItemMeta({
    required this.id,
    required this.name,
    required this.kind,
    required this.hasPassphrase,
    required this.fingerprint,
    required this.createdAt,
    this.wordCount,
    this.family,
  });

  final String id;
  final String name;
  final VaultItemKind kind;

  /// 仅助记词：12、15、18、21 或 24。
  final int? wordCount;

  /// 仅私钥：所属链家族。
  final ChainFamily? family;

  /// 是否设置了 BIP39 附加密码。
  final bool hasPassphrase;

  /// 十六进制，查重用；由保险库以带密钥的哈希生成，不能反推内容。
  final String fingerprint;

  /// 创建时间（UTC）。
  final DateTime createdAt;

  /// 返回改名后的副本。
  VaultItemMeta copyWith({String? name}) => VaultItemMeta(
    id: id,
    name: name ?? this.name,
    kind: kind,
    wordCount: wordCount,
    family: family,
    hasPassphrase: hasPassphrase,
    fingerprint: fingerprint,
    createdAt: createdAt,
  );

  @override
  bool operator ==(Object other) =>
      other is VaultItemMeta &&
      other.id == id &&
      other.name == name &&
      other.kind == kind &&
      other.wordCount == wordCount &&
      other.family == family &&
      other.hasPassphrase == hasPassphrase &&
      other.fingerprint == fingerprint &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    kind,
    wordCount,
    family,
    hasPassphrase,
    fingerprint,
    createdAt,
  );

  @override
  String toString() => 'VaultItemMeta($id, ${kind.name})';
}
