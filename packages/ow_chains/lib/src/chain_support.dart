import 'package:decimal/decimal.dart';
import 'package:ow_domain/ow_domain.dart';

/// 整数最小单位换算为以币为单位的 [Decimal]，精确无舍入（整数移位，不经过浮点）。
Decimal scaleAmount(BigInt raw, int decimals) =>
    Decimal.fromBigInt(raw).shift(-decimals);

/// 校验用户配置的自定义端点：必须是带主机的 https 地址。
/// 合法返回 null，否则返回 [ValidationFailure]。
Failure? validateCustomEndpoint(Uri custom, String chainId) {
  if (custom.scheme != 'https' || custom.host.isEmpty) {
    return ValidationFailure('自定义节点必须是 https chain=$chainId');
  }
  return null;
}

/// 地址只允许字母和数字（Base58、Bech32 都满足），防止地址被拼进 URL 路径时
/// 夹带 `/`、`..`、`?` 等字符。
final RegExp _safeAddress = RegExp(r'^[A-Za-z0-9]{1,128}$');

/// [address] 是否可以安全拼进 URL 路径。
bool isPathSafeAddress(String address) => _safeAddress.hasMatch(address);

/// 去掉路径末尾的 `/`，用于自定义端点的路径前缀。
String trimTrailingSlash(String path) =>
    path.endsWith('/') ? path.substring(0, path.length - 1) : path;
