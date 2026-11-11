/// OneWallet 领域层：实体、值对象、仓储接口、平台能力接口、业务规则。
///
/// 纯 Dart，不做任何 IO，不依赖 Flutter 和其他 `ow_*` 包。
library;

export 'src/account/account.dart';
export 'src/account/backup_status.dart';
export 'src/account/exchange_id.dart';
export 'src/account/watch_address.dart';
export 'src/adapter/adapters.dart';
export 'src/asset/asset.dart';
export 'src/asset/holding.dart';
export 'src/asset/holding_location.dart';
export 'src/asset/price.dart';
export 'src/asset/token_key.dart';
export 'src/asset/token_ref.dart';
export 'src/chain/address_checksum.dart';
export 'src/chain/address_codec.dart';
export 'src/chain/chain_family.dart';
export 'src/chain/chain_info.dart';
export 'src/chain/derivation_scheme.dart';
export 'src/core/failure.dart';
export 'src/core/result.dart';
export 'src/core/sensitive.dart';
export 'src/core/services.dart';
export 'src/exchange/exchange_credentials.dart';
export 'src/platform/device_security.dart';
export 'src/platform/platform_capabilities.dart';
export 'src/portfolio/holding_distribution.dart';
export 'src/portfolio/portfolio_calculator.dart';
export 'src/portfolio/portfolio_math.dart' show ratioScale, shareOf;
export 'src/portfolio/portfolio_summary.dart';
export 'src/repository/repositories.dart';
export 'src/settings/app_settings.dart';
export 'src/snapshot/snapshot.dart';
export 'src/sync/sync_record.dart';
export 'src/vault/vault_item_meta.dart';
