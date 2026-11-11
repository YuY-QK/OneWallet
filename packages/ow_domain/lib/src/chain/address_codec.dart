import 'address_checksum.dart';
import 'chain_family.dart';

/// 地址的格式判断、规范化与显示。纯函数，不联网。
///
/// 只看前缀、长度和字符集的操作（[detectFamily]、[normalize]、[shorten]）是静态方法；
/// 需要校验和的操作（[isValid]、[display]）是实例方法，校验和实现
/// [AddressChecksum] 由构造函数注入（`ow_chains` 提供）。不注入时只做格式判断。
final class AddressCodec {
  /// [checksum] 为 null 时只做格式判断。
  const AddressCodec({this._checksum});

  final AddressChecksum? _checksum;

  static const _base58 = '[1-9A-HJ-NP-Za-km-z]';
  static const _bech32 = '[qpzry9x8gf2tvdw0s3jn54khce6mua7l]';
  static const _bech32Upper = '[QPZRY9X8GF2TVDW0S3JN54KHCE6MUA7L]';

  static final _evm = RegExp(r'^0x[0-9a-fA-F]{40}$');
  static final _btcBase58 = RegExp('^[13]$_base58{25,34}\$');
  static final _btcSegwit = RegExp('^bc1q(?:$_bech32{38}|$_bech32{58})\$');
  static final _btcTaproot = RegExp('^bc1p$_bech32{58}\$');
  // BIP173 允许全大写的 bech32 地址（如二维码场景）；大小写混用一律不匹配。
  static final _btcSegwitUpper = RegExp(
    '^BC1Q(?:$_bech32Upper{38}|$_bech32Upper{58})\$',
  );
  static final _btcTaprootUpper = RegExp('^BC1P$_bech32Upper{58}\$');
  static final _solana = RegExp('^$_base58{32,44}\$');
  static final _tron = RegExp('^T$_base58{33}\$');

  /// 按格式识别 [input] 属于哪个链家族，识别不了返回 null。首尾空白忽略。
  ///
  /// 不验证校验和。按 EVM、Tron、Bitcoin、Solana 的顺序判断：Tron 地址和
  /// `1`、`3` 开头的 Bitcoin 地址同时满足 Solana 的字符集与长度，先判断前者。
  /// 因此极少数恰好以 `T`、`1`、`3` 开头且长度落在对方区间内的 Solana 地址
  /// 会被识别为 Tron 或 Bitcoin。界面应使用能校验校验和的 [detect]，
  /// 本方法只用于没有注入校验和的场合。
  static ChainFamily? detectFamily(String input) {
    final s = input.trim();
    for (final family in _detectOrder) {
      if (_matchesFormat(s, family)) return family;
    }
    return null;
  }

  /// 识别 [input] 属于哪个链家族：按 EVM、Tron、Bitcoin、Solana 的顺序，
  /// 返回第一个**格式与校验和都通过**的家族，都不通过返回 null。首尾空白忽略。
  ///
  /// 用校验和消除歧义：以 `T`、`1`、`3` 开头的合法 Solana 地址格式上也满足
  /// Tron 或 Bitcoin，但校验和不会通过，于是继续往后判断，最终得到 solana。
  /// 未注入 [AddressChecksum] 时退化为 [detectFamily]。界面一律用本方法。
  ChainFamily? detect(String input) {
    if (_checksum == null) return detectFamily(input);
    for (final family in _detectOrder) {
      if (isValid(input, family)) return family;
    }
    return null;
  }

  static const _detectOrder = [
    ChainFamily.evm,
    ChainFamily.tron,
    ChainFamily.bitcoin,
    ChainFamily.solana,
  ];

  /// [input] 是否是 [family] 的合法地址。首尾空白忽略。
  ///
  /// 先做格式判断；通过后，若注入了 [AddressChecksum]，再验证校验和。
  /// 失败时返回 false，不抛异常。
  bool isValid(String input, ChainFamily family) {
    final s = input.trim();
    if (!_matchesFormat(s, family)) return false;
    final checksum = _checksum;
    return checksum == null || checksum.verify(s, family);
  }

  /// 存储与查重用的规范化形式：EVM 去首尾空白并转小写；Bitcoin 的全大写
  /// bech32 地址（`BC1…`）转为小写；其余情况只去首尾空白。
  ///
  /// 不做校验；调用方应先用 [isValid] 确认地址合法。Base58 地址大小写有意义，
  /// 大小写混用的 bech32 地址也原样返回（它通不过 [isValid]）。
  static String normalize(String input, ChainFamily family) {
    final s = input.trim();
    return switch (family) {
      ChainFamily.evm => s.toLowerCase(),
      ChainFamily.bitcoin when _isUpperBech32(s) => s.toLowerCase(),
      _ => s,
    };
  }

  static bool _isUpperBech32(String s) =>
      _btcSegwitUpper.hasMatch(s) || _btcTaprootUpper.hasMatch(s);

  /// 完整显示用的形式：EVM 转为 EIP-55 大小写混合，其余家族原样返回。
  ///
  /// [normalized] 应为 [normalize] 的结果。未注入 [AddressChecksum]，
  /// 或 [normalized] 不符合 EVM 格式时，原样返回。
  String display(String normalized, ChainFamily family) {
    final checksum = _checksum;
    if (family != ChainFamily.evm ||
        checksum == null ||
        !_evm.hasMatch(normalized)) {
      return normalized;
    }
    return checksum.toEip55(normalized.toLowerCase());
  }

  /// 列表与日志中的缩略形式：前 6 位加 `…` 加后 4 位，如 `0x12ab…9f3c`。
  ///
  /// 不超过 11 个字符的输入缩略后不会更短，原样返回。
  static String shorten(String address) {
    if (address.length <= 11) return address;
    return '${address.substring(0, 6)}…'
        '${address.substring(address.length - 4)}';
  }

  static bool _matchesFormat(String s, ChainFamily family) => switch (family) {
    ChainFamily.evm => _evm.hasMatch(s),
    ChainFamily.bitcoin =>
      _btcBase58.hasMatch(s) ||
          _btcSegwit.hasMatch(s) ||
          _btcTaproot.hasMatch(s) ||
          _isUpperBech32(s),
    ChainFamily.solana => _solana.hasMatch(s),
    ChainFamily.tron => _tron.hasMatch(s),
  };
}
