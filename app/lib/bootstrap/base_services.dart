import 'package:ow_domain/ow_domain.dart';
import 'package:uuid/uuid.dart';

/// 系统时钟。统一返回 UTC。
final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}

/// 生成 UUID v4 作为实体 id。`uuid` 的 v4 默认使用密码学安全随机数。
final class UuidIdGenerator implements IdGenerator {
  UuidIdGenerator() : _uuid = const Uuid();

  final Uuid _uuid;

  @override
  String newId() => _uuid.v4();
}
