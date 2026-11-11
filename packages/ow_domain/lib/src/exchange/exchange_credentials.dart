import '../core/sensitive.dart';

/// 交易所只读 API 凭据。
///
/// 全部字段是 [Sensitive]。本类刻意不实现内容相等与哈希，
/// 不得放入状态对象、日志或路由参数；`toString()` 不输出任何内容。
final class ExchangeCredentials {
  const ExchangeCredentials({
    required this.apiKey,
    required this.apiSecret,
    this.passphrase,
  });

  final Sensitive apiKey;
  final Sensitive apiSecret;

  /// 仅 OKX、Bitget 需要。
  final Sensitive? passphrase;

  @override
  String toString() => 'ExchangeCredentials(***)';
}

/// 交易所账户的充值地址（只读展示，PRD R1）。
final class DepositAddress {
  const DepositAddress({
    required this.symbol,
    required this.network,
    required this.address,
    this.memo,
  });

  /// 交易所给出的币种符号。
  final String symbol;

  /// 交易所给出的网络名，如 `ERC20`、`TRC20`。
  final String network;
  final String address;

  /// 部分币种需要的备注或标签。
  final String? memo;

  @override
  bool operator ==(Object other) =>
      other is DepositAddress &&
      other.symbol == symbol &&
      other.network == network &&
      other.address == address &&
      other.memo == memo;

  @override
  int get hashCode => Object.hash(symbol, network, address, memo);

  @override
  String toString() => 'DepositAddress($symbol, $network)';
}

/// API Key 的权限范围。
enum KeyPermission {
  /// 只读，符合要求。
  readOnly,

  /// 带交易权限。
  canTrade,

  /// 带提现权限。
  canWithdraw,

  /// 交易所未提供权限信息。
  unknown,
}

/// 凭据校验的结果。
final class CredentialCheck {
  const CredentialCheck({required this.permission});

  final KeyPermission permission;

  @override
  bool operator ==(Object other) =>
      other is CredentialCheck && other.permission == permission;

  @override
  int get hashCode => permission.hashCode;

  @override
  String toString() => 'CredentialCheck(${permission.name})';
}
