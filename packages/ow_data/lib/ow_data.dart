/// OneWallet 数据层：Drift 数据库与仓储实现。
///
/// 纯 Dart。不负责打开数据库文件，也不处理加密：连接（`QueryExecutor`）由 app
/// 注入。读取约定见 [RowDecodeException]。
library;

export 'src/database/ow_database.dart' show OwDatabase;
export 'src/mapping/codec.dart' show RowDecodeException;
export 'src/ow_repositories.dart';
export 'src/repositories/account_repositories.dart';
export 'src/repositories/asset_repositories.dart';
export 'src/repositories/market_repositories.dart';
export 'src/repositories/misc_repositories.dart';
