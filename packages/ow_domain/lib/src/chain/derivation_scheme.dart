import 'chain_family.dart';

/// 助记词到地址的派生方案：路径模板加地址编码方式。
///
/// 同一组助记词在不同钱包里可能使用不同的方案，所以每个派生出的地址都要
/// 记录它的方案和序号（PRD P16）。
enum DerivationScheme {
  /// MetaMask 等大多数 EVM 钱包。
  evmStandard(ChainFamily.evm, "m/44'/60'/0'/0/{i}"),

  /// Ledger Live：每个账户换的是账户层。
  evmLedgerLive(ChainFamily.evm, "m/44'/60'/{i}'/0/0"),

  /// BIP84 原生隔离见证，`bc1q` 开头。
  btcNativeSegwit(ChainFamily.bitcoin, "m/84'/0'/0'/0/{i}"),

  /// BIP86 Taproot，`bc1p` 开头。
  btcTaproot(ChainFamily.bitcoin, "m/86'/0'/0'/0/{i}"),

  /// BIP49 嵌套隔离见证，`3` 开头。
  btcNestedSegwit(ChainFamily.bitcoin, "m/49'/0'/0'/0/{i}"),

  /// BIP44 传统地址，`1` 开头。
  btcLegacy(ChainFamily.bitcoin, "m/44'/0'/0'/0/{i}"),

  /// Phantom 等大多数 Solana 钱包。
  solanaStandard(ChainFamily.solana, "m/44'/501'/{i}'/0'"),

  /// 旧式 Solana 路径。
  solanaLegacy(ChainFamily.solana, "m/44'/501'/{i}'"),

  tronStandard(ChainFamily.tron, "m/44'/195'/0'/0/{i}");

  const DerivationScheme(this.family, this.pathTemplate);

  final ChainFamily family;

  /// `{i}` 处填入地址序号。
  final String pathTemplate;

  /// 第 [index] 个地址的完整路径。
  String pathFor(int index) {
    if (index < 0) {
      throw ArgumentError.value(index, 'index', '序号不能为负');
    }
    return pathTemplate.replaceFirst('{i}', '$index');
  }

  /// 每个链家族的默认方案排在最前。
  static List<DerivationScheme> forFamily(ChainFamily family) =>
      values.where((s) => s.family == family).toList();
}
