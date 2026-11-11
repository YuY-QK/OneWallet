/// 请求头、查询参数与路径的脱敏规则（DEV_GUIDELINES 第 6 节：API Key 只保留前 4 位）。
///
/// - 名称（不区分大小写）含 `key|secret|sign|signature|token|passphrase|
///   authorization|password` 的视为敏感；
/// - 其中含 `secret|sign|signature|passphrase|password|authorization` 的完全替换为 `***`；
/// - 其余敏感值保留前 4 个字符加 `***`。
class Redactor {
  /// [extraSensitiveNames] 是额外的敏感名称（精确匹配、不区分大小写），
  /// 如 `X-MBX-APIKEY`、`OK-ACCESS-KEY`；按"保留前 4 位"处理。
  Redactor({Iterable<String> extraSensitiveNames = const []})
    : _extra = {for (final n in extraSensitiveNames) n.toLowerCase()};

  static final _sensitive = RegExp(
    r'key|secret|sign|signature|token|passphrase|authorization|password',
    caseSensitive: false,
  );
  static final _fullMask = RegExp(
    r'secret|sign|signature|passphrase|password|authorization',
    caseSensitive: false,
  );

  /// 值短于此长度时，即使"只保留前 4 位"也会泄漏大部分内容，改为完全替换。
  static const _minLengthForPartial = 8;

  final Set<String> _extra;

  /// 返回脱敏后的值；名称不敏感时原样返回。
  String redactValue(String name, String value) {
    final lower = name.toLowerCase();
    if (_fullMask.hasMatch(lower)) return '***';
    if (_sensitive.hasMatch(lower) || _extra.contains(lower)) {
      if (value.length < _minLengthForPartial) return '***';
      return '${value.substring(0, 4)}***';
    }
    return value;
  }

  /// 脱敏后的请求头，形如 `{name: value, ...}`。
  String formatHeaders(Map<String, Object?> headers) {
    final parts = [
      for (final e in headers.entries)
        '${e.key}: ${redactValue(e.key, '${e.value}')}',
    ];
    return '{${parts.join(', ')}}';
  }

  /// 脱敏后的查询串（不含 `?`）；没有参数时返回空串。
  String formatQuery(Map<String, List<String>> query) {
    final parts = [
      for (final e in query.entries)
        for (final v in e.value) '${e.key}=${redactValue(e.key, v)}',
    ];
    return parts.join('&');
  }

  static final _opaqueSegment = RegExp(r'^[A-Za-z0-9_\-]{16,}$');

  /// 脱敏后的路径：长度不小于 16 的不透明路径段只保留前 4 位。
  ///
  /// 有的服务商把 API Key 放在路径里，链上查询也常把地址放在路径里；
  /// 两者都不应完整进入日志。
  String formatPath(String path) => path
      .split('/')
      .map((s) => _opaqueSegment.hasMatch(s) ? '${s.substring(0, 4)}***' : s)
      .join('/');

  /// [name] 是否敏感（用于跨主机重定向时剥离敏感请求头）。
  bool isSensitive(String name) {
    final lower = name.toLowerCase();
    return _sensitive.hasMatch(lower) || _extra.contains(lower);
  }
}
