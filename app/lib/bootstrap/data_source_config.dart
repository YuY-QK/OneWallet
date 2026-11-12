import 'package:ow_domain/ow_domain.dart';

/// 数据源配置的 [DataSourceConfig] 实现，全部存在 [SecretStore] 中。
///
/// 键名约定（见 IMPLEMENTATION_SPEC 7.5）：
/// - API Key：`ow.datasource.<providerId>.key`
/// - 自定义端点：`ow.datasource.<chainId>.endpoint`
///
/// 自定义端点放在 [SecretStore] 而不是 `SettingsRepository`：后者是 `AppSettings`
/// 的整体读写，端点 URL 也可能带令牌路径，按密钥对待更稳妥。
///
/// 密钥与端点不出现在日志、异常和 [toString] 中。
final class SecretStoreDataSourceConfig implements DataSourceConfig {
  SecretStoreDataSourceConfig(this._store);

  final SecretStore _store;

  static final _idPattern = RegExp(r'^[a-z0-9_-]{1,40}$');

  /// [providerId] 对应的 API Key 的存储键。
  static String apiKeyStoreKey(String providerId) =>
      'ow.datasource.${_checkId(providerId)}.key';

  /// [chainId] 对应的自定义端点的存储键。
  static String endpointStoreKey(String chainId) =>
      'ow.datasource.${_checkId(chainId)}.endpoint';

  @override
  Future<String?> apiKey(String providerId) async {
    final value = await _store.read(apiKeyStoreKey(providerId));
    return (value == null || value.isEmpty) ? null : value;
  }

  @override
  Future<Uri?> customEndpoint(String chainId) async {
    final value = await _store.read(endpointStoreKey(chainId));
    if (value == null) return null;
    // 存储内容被改坏时按"未配置"处理，不把非 https 地址交给网络层。
    return _parseHttps(value);
  }

  /// 保存 [providerId] 的 API Key。空白内容返回 [ValidationFailure]，不写入。
  Future<Result<void>> setApiKey(String providerId, String apiKey) async {
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      return const Err(ValidationFailure('API Key 不能为空'));
    }
    await _store.write(apiKeyStoreKey(providerId), trimmed);
    return const Ok(null);
  }

  /// 清除 [providerId] 的 API Key。
  Future<void> clearApiKey(String providerId) =>
      _store.delete(apiKeyStoreKey(providerId));

  /// 保存 [chainId] 的自定义端点。只接受 https 且不含用户名密码的地址，
  /// 否则返回 [ValidationFailure]，不写入。
  Future<Result<void>> setCustomEndpoint(
    String chainId,
    String endpoint,
  ) async {
    final uri = _parseHttps(endpoint.trim());
    if (uri == null) {
      return const Err(ValidationFailure('自定义端点必须是 https 地址'));
    }
    await _store.write(endpointStoreKey(chainId), uri.toString());
    return const Ok(null);
  }

  /// 清除 [chainId] 的自定义端点。
  Future<void> clearCustomEndpoint(String chainId) =>
      _store.delete(endpointStoreKey(chainId));

  static Uri? _parseHttps(String input) {
    final uri = Uri.tryParse(input);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      return null;
    }
    return uri;
  }

  static String _checkId(String id) {
    if (!_idPattern.hasMatch(id)) {
      throw ArgumentError.value(id, 'id', '标识只能包含小写字母、数字、下划线与连字符');
    }
    return id;
  }

  @override
  String toString() => 'SecretStoreDataSourceConfig';
}
