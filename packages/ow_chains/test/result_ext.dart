import 'package:ow_domain/ow_domain.dart';

/// 测试辅助：取出失败原因，成功时为 null。
extension FailureOrNull<T> on Result<T> {
  Failure? get failureOrNull => switch (this) {
    Ok<T>() => null,
    Err<T>(:final failure) => failure,
  };
}
