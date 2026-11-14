import 'package:ow_domain/ow_domain.dart';

/// [failure] 的类型名，写入 `SyncRecord.failureType`。
///
/// 不用 `runtimeType.toString()`：发布构建开启混淆后类型名会被改写，
/// 写进数据库的值就不再稳定。新增 `Failure` 子类时这里会编译失败，须补一行。
String failureTypeName(Failure failure) => switch (failure) {
  NetworkFailure() => 'NetworkFailure',
  RateLimitedFailure() => 'RateLimitedFailure',
  UnauthorizedFailure() => 'UnauthorizedFailure',
  KeyExpiredFailure() => 'KeyExpiredFailure',
  ClockSkewFailure() => 'ClockSkewFailure',
  ServiceDownFailure() => 'ServiceDownFailure',
  ValidationFailure() => 'ValidationFailure',
  DuplicateAddressFailure() => 'DuplicateAddressFailure',
  WrongPasswordFailure() => 'WrongPasswordFailure',
  VaultCorruptedFailure() => 'VaultCorruptedFailure',
  VaultVersionUnsupportedFailure() => 'VaultVersionUnsupportedFailure',
  VaultNotFoundFailure() => 'VaultNotFoundFailure',
  VaultAlreadyExistsFailure() => 'VaultAlreadyExistsFailure',
  VaultItemNotFoundFailure() => 'VaultItemNotFoundFailure',
  BackupCorruptedFailure() => 'BackupCorruptedFailure',
  BackupVersionUnsupportedFailure() => 'BackupVersionUnsupportedFailure',
  UnsupportedFailure(:final reason) => switch (reason) {
    UnsupportedReason.platform => 'UnsupportedFailure',
    UnsupportedReason.notIntegrated => 'UnsupportedFailure.notIntegrated',
  },
  UnknownFailure() => 'UnknownFailure',
};
