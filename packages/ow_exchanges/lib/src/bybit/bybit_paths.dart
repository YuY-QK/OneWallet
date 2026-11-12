/// Bybit 适配器用到的全部请求路径。全部是只读（查询）接口。
///
/// 测试会遍历假适配器收到的每个请求，逐一比对本集合（见
/// `common/holdings.dart` 的 `pathsOutsideAllowlist`）。新增路径必须同时登记在
/// [bybitReadOnlyPaths]，并在 docs/EXTERNAL_APIS.md 的 Bybit 一节记录。
abstract final class BybitPaths {
  /// 公开：服务器时间（响应 `result.timeNano`，纳秒）。
  static const serverTime = '/v5/market/time';

  /// API Key 信息与权限（`result.readOnly`、`result.permissions`）。
  static const apiKeyInfo = '/v5/user/query-api';

  /// 统一交易账户的币种余额（`accountType=UNIFIED`）。
  static const walletBalance = '/v5/account/wallet-balance';

  /// 资金账户各币种余额（`accountType=FUND`）。
  /// 路径中的 `transfer` 只是接口分组名，本接口只查询余额，不发起划转；
  /// 已登记为白名单例外，见 tools/ci/check_deps.dart 与 docs/EXTERNAL_APIS.md。
  static const fundBalance = '/v5/asset/transfer/query-account-coins-balance';

  /// 灵活储蓄与链上赚币的持仓（`category=FlexibleSaving` 或 `OnChain`）。
  static const earnPosition = '/v5/earn/position';

  /// 定期理财持仓。
  static const fixedTermPosition = '/v5/earn/fixed-term/position';
}

/// 只读路径白名单：适配器发出的请求路径必须全部在其中。
const bybitReadOnlyPaths = <String>{
  BybitPaths.serverTime,
  BybitPaths.apiKeyInfo,
  BybitPaths.walletBalance,
  BybitPaths.fundBalance,
  BybitPaths.earnPosition,
  BybitPaths.fixedTermPosition,
};
