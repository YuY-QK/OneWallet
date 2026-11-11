/// 生成实体标识（UUID v4）。由应用层注入，领域层不自行生成。
abstract interface class IdGenerator {
  /// 返回一个新的、不重复的标识。
  String newId();
}

/// 当前时间的来源。业务代码不得直接调用 `DateTime.now()`，以便测试控制时间。
abstract interface class Clock {
  /// 当前时间，UTC。
  DateTime nowUtc();
}
