import '../chain/chain_family.dart';
import '../chain/derivation_scheme.dart';
import '../core/equality.dart';

/// 钱包账户下被观察的一个地址。
final class WatchAddress {
  /// [enabledChainIds] 会被复制为不可修改的集合。
  WatchAddress({
    required this.id,
    required this.accountId,
    required this.family,
    required this.address,
    required Set<String> enabledChainIds,
    this.scheme,
    this.derivationIndex,
    this.note = '',
  }) : enabledChainIds = Set.unmodifiable(enabledChainIds);

  final String id;
  final String accountId;
  final ChainFamily family;

  /// 规范化形式（见 `AddressCodec.normalize`）。
  final String address;

  /// 启用的链 id。EVM 可多条（R3）；其余家族固定一条。
  final Set<String> enabledChainIds;

  /// 由保险库派生时记录的方案，手动添加的为 null。
  final DerivationScheme? scheme;

  /// 由保险库派生时记录的序号，手动添加的为 null。
  final int? derivationIndex;
  final String note;

  /// 返回替换了指定字段的副本。地址本身与派生信息不可改。
  WatchAddress copyWith({Set<String>? enabledChainIds, String? note}) =>
      WatchAddress(
        id: id,
        accountId: accountId,
        family: family,
        address: address,
        enabledChainIds: enabledChainIds ?? this.enabledChainIds,
        scheme: scheme,
        derivationIndex: derivationIndex,
        note: note ?? this.note,
      );

  @override
  bool operator ==(Object other) =>
      other is WatchAddress &&
      other.id == id &&
      other.accountId == accountId &&
      other.family == family &&
      other.address == address &&
      setEquals(other.enabledChainIds, enabledChainIds) &&
      other.scheme == scheme &&
      other.derivationIndex == derivationIndex &&
      other.note == note;

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    family,
    address,
    setHash(enabledChainIds),
    scheme,
    derivationIndex,
    note,
  );

  @override
  String toString() => 'WatchAddress($id, $family)';
}
