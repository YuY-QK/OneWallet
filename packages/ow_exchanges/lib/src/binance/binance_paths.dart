/// Binance 适配器用到的全部请求路径。全部是只读（查询）接口。
///
/// 测试会遍历假适配器收到的每个请求，逐一比对本集合（见
/// `common/holdings.dart` 的 `pathsOutsideAllowlist`）。新增路径必须同时登记在
/// [binanceReadOnlyPaths]，并在 docs/EXTERNAL_APIS.md 的 Binance 一节记录。
abstract final class BinancePaths {
  /// 公开：服务器时间（现货主机）。
  static const serverTime = '/api/v3/time';

  /// 现货账户余额。
  static const spotAccount = '/api/v3/account';

  /// API Key 权限查询。
  static const apiRestrictions = '/sapi/v1/account/apiRestrictions';

  /// 资金账户余额（POST，但只读）。
  static const fundingAssets = '/sapi/v1/asset/get-funding-asset';

  /// 全仓杠杆账户。
  static const crossMargin = '/sapi/v1/margin/account';

  /// 逐仓杠杆账户。
  static const isolatedMargin = '/sapi/v1/margin/isolated/account';

  /// U 本位合约账户余额（主机 fapi）。
  static const usdmBalance = '/fapi/v3/balance';

  /// 币本位合约账户余额（主机 dapi）。
  static const coinmBalance = '/dapi/v1/balance';

  /// 活期理财持仓。
  static const flexiblePosition = '/sapi/v1/simple-earn/flexible/position';

  /// 定期理财持仓。
  static const lockedPosition = '/sapi/v1/simple-earn/locked/position';
}

/// 只读路径白名单：适配器发出的请求路径必须全部在其中。
const binanceReadOnlyPaths = <String>{
  BinancePaths.serverTime,
  BinancePaths.spotAccount,
  BinancePaths.apiRestrictions,
  BinancePaths.fundingAssets,
  BinancePaths.crossMargin,
  BinancePaths.isolatedMargin,
  BinancePaths.usdmBalance,
  BinancePaths.coinmBalance,
  BinancePaths.flexiblePosition,
  BinancePaths.lockedPosition,
};
