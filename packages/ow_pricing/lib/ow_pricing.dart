/// OneWallet 价格与币种映射：内置币种映射表与 CoinGecko 价格源。
///
/// 纯 Dart。网络访问经由 `ow_net`。
library;

export 'src/catalog/built_in_asset_catalog.dart';
export 'src/coingecko/coingecko_price_source.dart';
export 'src/coingecko/exact_json.dart'
    show JsonNumber, decimalFromJson, parseJsonExact;
