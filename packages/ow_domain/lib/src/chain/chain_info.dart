import 'chain_family.dart';

/// 一条内置链的静态信息。
final class ChainInfo {
  const ChainInfo({
    required this.id,
    required this.family,
    required this.name,
    required this.nativeSymbol,
    required this.nativeDecimals,
    required this.explorerAddressUrl,
    this.evmChainId,
  });

  /// 稳定标识，写入数据库与备份文件，见 [Chains]。
  final String id;
  final ChainFamily family;

  /// 显示名。
  final String name;

  /// 原生币符号：ETH、BNB、BTC 等。
  final String nativeSymbol;

  /// 原生币的小数位数。
  final int nativeDecimals;

  /// EIP-155 链 ID，仅 EVM 链有值。
  final int? evmChainId;

  /// 区块浏览器的地址页模板，含 `{address}` 占位符。
  final String explorerAddressUrl;

  @override
  bool operator ==(Object other) =>
      other is ChainInfo &&
      other.id == id &&
      other.family == family &&
      other.name == name &&
      other.nativeSymbol == nativeSymbol &&
      other.nativeDecimals == nativeDecimals &&
      other.evmChainId == evmChainId &&
      other.explorerAddressUrl == explorerAddressUrl;

  @override
  int get hashCode => Object.hash(
    id,
    family,
    name,
    nativeSymbol,
    nativeDecimals,
    evmChainId,
    explorerAddressUrl,
  );

  @override
  String toString() => 'ChainInfo($id)';
}

/// 内置链表。v1.0 固定 9 条，顺序即界面上的默认顺序。
abstract final class Chains {
  static const _ethereum = ChainInfo(
    id: 'ethereum',
    family: ChainFamily.evm,
    name: 'Ethereum',
    nativeSymbol: 'ETH',
    nativeDecimals: 18,
    evmChainId: 1,
    explorerAddressUrl: 'https://etherscan.io/address/{address}',
  );

  static const _bsc = ChainInfo(
    id: 'bsc',
    family: ChainFamily.evm,
    name: 'BNB Chain',
    nativeSymbol: 'BNB',
    nativeDecimals: 18,
    evmChainId: 56,
    explorerAddressUrl: 'https://bscscan.com/address/{address}',
  );

  static const _arbitrum = ChainInfo(
    id: 'arbitrum',
    family: ChainFamily.evm,
    name: 'Arbitrum',
    nativeSymbol: 'ETH',
    nativeDecimals: 18,
    evmChainId: 42161,
    explorerAddressUrl: 'https://arbiscan.io/address/{address}',
  );

  static const _optimism = ChainInfo(
    id: 'optimism',
    family: ChainFamily.evm,
    name: 'Optimism',
    nativeSymbol: 'ETH',
    nativeDecimals: 18,
    evmChainId: 10,
    explorerAddressUrl: 'https://optimistic.etherscan.io/address/{address}',
  );

  static const _base = ChainInfo(
    id: 'base',
    family: ChainFamily.evm,
    name: 'Base',
    nativeSymbol: 'ETH',
    nativeDecimals: 18,
    evmChainId: 8453,
    explorerAddressUrl: 'https://basescan.org/address/{address}',
  );

  static const _polygon = ChainInfo(
    id: 'polygon',
    family: ChainFamily.evm,
    name: 'Polygon',
    nativeSymbol: 'POL',
    nativeDecimals: 18,
    evmChainId: 137,
    explorerAddressUrl: 'https://polygonscan.com/address/{address}',
  );

  static const _bitcoin = ChainInfo(
    id: 'bitcoin',
    family: ChainFamily.bitcoin,
    name: 'Bitcoin',
    nativeSymbol: 'BTC',
    nativeDecimals: 8,
    explorerAddressUrl: 'https://mempool.space/address/{address}',
  );

  static const _solana = ChainInfo(
    id: 'solana',
    family: ChainFamily.solana,
    name: 'Solana',
    nativeSymbol: 'SOL',
    nativeDecimals: 9,
    explorerAddressUrl: 'https://solscan.io/account/{address}',
  );

  static const _tron = ChainInfo(
    id: 'tron',
    family: ChainFamily.tron,
    name: 'Tron',
    nativeSymbol: 'TRX',
    nativeDecimals: 6,
    explorerAddressUrl: 'https://tronscan.org/#/address/{address}',
  );

  /// 全部内置链。
  static const List<ChainInfo> all = [
    _ethereum,
    _bsc,
    _arbitrum,
    _optimism,
    _base,
    _polygon,
    _bitcoin,
    _solana,
    _tron,
  ];

  /// 按 [id] 查找内置链。
  ///
  /// 失败时：[id] 不是内置链时抛出 [ArgumentError]。链 id 只来自本表，
  /// 查不到属于程序缺陷；需要处理外部输入时先用 [tryById]。
  static ChainInfo byId(String id) {
    final chain = tryById(id);
    if (chain == null) {
      throw ArgumentError.value(id, 'id', '未知的链');
    }
    return chain;
  }

  /// 按 [id] 查找内置链，查不到返回 null。
  static ChainInfo? tryById(String id) {
    for (final chain in all) {
      if (chain.id == id) return chain;
    }
    return null;
  }

  /// 属于 [family] 的全部链，保持 [all] 中的顺序。
  static List<ChainInfo> ofFamily(ChainFamily family) =>
      all.where((c) => c.family == family).toList(growable: false);
}
