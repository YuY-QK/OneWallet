/// OneWallet 网络基础设施：HTTP 客户端工厂、脱敏日志、失败映射、限速器。
///
/// 纯 Dart。只允许 HTTPS。数据源适配器（ow_chains、ow_exchanges、ow_pricing）
/// 通过本包访问网络；保险库及其他包不得依赖本包。
library;

export 'src/failure_mapper.dart';
export 'src/http_client_factory.dart';
export 'src/rate_limiter.dart';
export 'src/redaction.dart' show Redactor;
