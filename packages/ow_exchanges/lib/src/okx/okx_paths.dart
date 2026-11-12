/// OKX 适配器用到的全部请求路径。全部是只读（查询）接口。
///
/// 测试会遍历假适配器收到的每个请求，逐一比对本集合（见
/// `common/holdings.dart` 的 `pathsOutsideAllowlist`）。新增路径必须同时登记在
/// [okxReadOnlyPaths]，并在 docs/EXTERNAL_APIS.md 的 OKX 一节记录。
abstract final class OkxPaths {
  /// 公开：服务器时间（响应 `data[0].ts`，毫秒）。
  static const publicTime = '/api/v5/public/time';

  /// API Key 配置与权限（`data[0].perm`）。
  static const accountConfig = '/api/v5/account/config';

  /// 交易账户余额（统一账户；`data[0].details[]`）。
  static const accountBalance = '/api/v5/account/balance';

  /// 资金账户余额。
  static const fundingBalances = '/api/v5/asset/balances';

  /// 余币宝（简单赚币）持仓。
  static const savingsBalance = '/api/v5/finance/savings/balance';

  /// 链上赚币（质押等）进行中的订单；只读查询，路径中的 `orders` 不代表下单。
  static const stakingActiveOrders =
      '/api/v5/finance/staking-defi/orders-active';
}

/// 只读路径白名单：适配器发出的请求路径必须全部在其中。
const okxReadOnlyPaths = <String>{
  OkxPaths.publicTime,
  OkxPaths.accountConfig,
  OkxPaths.accountBalance,
  OkxPaths.fundingBalances,
  OkxPaths.savingsBalance,
  OkxPaths.stakingActiveOrders,
};
