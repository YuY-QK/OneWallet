import 'dart:typed_data';

/// 密钥类数据的容器：助记词、私钥、种子、密码、API Secret。
///
/// - `toString()` 固定返回 `***`，防止被日志或异常信息带出。
/// - 以字节持有，用完调用 [wipe] 覆写清零。
/// - 不实现 `==` 的内容比较，避免被当作 Map 的键或进入状态对象。
final class Sensitive {
  /// 接管 [bytes] 的所有权；调用方不应再保留对它的引用。
  Sensitive(Uint8List bytes) : _bytes = bytes;

  Uint8List _bytes;
  bool _wiped = false;

  bool get isWiped => _wiped;

  /// 在 [action] 中读取内容。[action] 不得把参数保存到外部。
  R use<R>(R Function(Uint8List bytes) action) {
    if (_wiped) {
      throw StateError('敏感数据已被清除');
    }
    return action(_bytes);
  }

  /// 覆写清零。可重复调用。
  void wipe() {
    _bytes.fillRange(0, _bytes.length, 0);
    _bytes = Uint8List(0);
    _wiped = true;
  }

  @override
  String toString() => '***';
}
