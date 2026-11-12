import '../account/exchange_id.dart';
import '../asset/asset.dart';
import '../asset/holding.dart';
import '../asset/holding_location.dart';
import '../asset/price.dart';
import '../asset/token_ref.dart';
import '../chain/chain_family.dart';
import '../chain/chain_info.dart';
import '../core/result.dart';
import '../exchange/exchange_credentials.dart';

// 数据源适配器接口。实现在 `ow_chains`、`ow_exchanges`、`ow_pricing`。
// 只读：不得包含任何签名、转账、下单、划转、提现。
// 服务商的错误一律映射为 `Failure`（DEV_GUIDELINES 第 5 节）返回，不抛异常。

/// 一个链家族的余额查询。
abstract interface class ChainAdapter {
  ChainFamily get family;

  /// [address] 为规范化形式，[chain] 属于 [family]。
  /// 返回原生币与代币余额（数量为 0 的可省略）；失败时返回对应的 `Failure`。
  Future<Result<List<RawHolding>>> fetchHoldings(
    String address,
    ChainInfo chain,
  );

  /// 地址在 [chain] 上是否有过交易，用于派生地址列表的提示（P16）。
  Future<Result<bool>> hasActivity(String address, ChainInfo chain);
}

/// 一家交易所的只读接入。
abstract interface class ExchangeAdapter {
  ExchangeId get id;

  /// 是否需要 API Passphrase（OKX、Bitget）。
  bool get needsPassphrase;

  /// 校验凭据并返回其权限范围；凭据无效时返回 `UnauthorizedFailure` 等。
  Future<Result<CredentialCheck>> verify(ExchangeCredentials c);

  /// 全部子账户的余额（合约账户以账户权益计，R12）。
  Future<Result<List<(ExchangeSubAccount, RawHolding)>>> fetchHoldings(
    ExchangeCredentials c,
  );

  /// 已有的充值地址（只读，不新建）。
  Future<Result<List<DepositAddress>>> fetchDepositAddresses(
    ExchangeCredentials c,
  );
}

/// 价格源。
abstract interface class PriceSource {
  /// 查询 [assets] 以 [quote] 计价的价格；查不到价格的币种不出现在结果中。
  Future<Result<List<Price>>> fetchPrices(Set<Asset> assets, Quote quote);

  /// 为内置映射表中没有的合约代币查找标准币种；查不到的不出现在结果中。
  Future<Result<Map<ContractToken, Asset>>> lookupContracts(
    Set<ContractToken> tokens,
  );
}

/// 内置币种映射表（PRD R8）。
abstract interface class AssetCatalog {
  /// 把原始代币标识归一化为标准币种；无法识别时返回 null。
  Asset? resolve(TokenRef token);

  /// 不存在时返回 null。
  Asset? byId(String assetId);

  /// 按价格源标识（CoinGecko id）反查币种；不存在时返回 null。
  ///
  /// 价格源据此把"价格源认为是某个已知币种"的合约代币合并到该币种。
  Asset? byPriceId(String priceId);
}

/// 按家族或交易所取适配器。
abstract interface class AdapterRegistry {
  /// 每个家族都有适配器；装配缺失属于程序缺陷，抛出异常。
  ChainAdapter chain(ChainFamily family);

  /// 每家交易所都有适配器；装配缺失属于程序缺陷，抛出异常。
  ExchangeAdapter exchange(ExchangeId id);
}

/// 用户自定义的数据源配置（P20）。API Key 存于 `SecretStore`。
abstract interface class DataSourceConfig {
  /// [providerId] 对应服务商的用户自填 API Key；未填写时返回 null。
  Future<String?> apiKey(String providerId);

  /// [chainId] 的自定义节点地址；未设置时返回 null，使用内置地址。
  Future<Uri?> customEndpoint(String chainId);
}
