import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/l10n/app_localizations_zh.dart';
import 'package:onewallet/widgets/failure_text.dart';
import 'package:ow_domain/ow_domain.dart';

void main() {
  final l10n = AppLocalizationsZh();

  // 每一种 Failure 与它应得的文案。新增 Failure 类型时 failure_text.dart 的
  // switch 会先编译失败，这里再补一行样例。
  final cases = <Failure, String>{
    const NetworkFailure(): l10n.failureNetwork,
    const RateLimitedFailure(): l10n.failureRateLimited,
    const UnauthorizedFailure(): l10n.failureUnauthorized,
    const KeyExpiredFailure(): l10n.failureKeyExpired,
    const ClockSkewFailure(): l10n.failureClockSkew,
    const ServiceDownFailure(): l10n.failureServiceDown,
    const ValidationFailure(): l10n.failureValidation,
    const WrongPasswordFailure(): l10n.failureWrongPassword,
    const UnsupportedFailure(): l10n.failureUnsupported,
    const UnknownFailure(): l10n.failureUnknown,
  };

  for (final entry in cases.entries) {
    test('failureText_${entry.key.runtimeType}_返回对应文案', () {
      final text = failureText(l10n, entry.key);
      expect(text, entry.value);
      expect(text, isNotEmpty);
    });
  }

  test('failureText_每种失败的文案互不相同', () {
    final texts = cases.keys.map((f) => failureText(l10n, f)).toSet();
    expect(texts.length, cases.length);
  });

  test('failureText_带detail_不把原始信息显示给用户', () {
    const secretLooking = 'HTTP 500 internal: stack trace';
    final text = failureText(l10n, const UnknownFailure(secretLooking));
    expect(text, isNot(contains(secretLooking)));
    expect(text, l10n.failureUnknown);
  });
}
