import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

void main() {
  group('Failure 子类', () {
    test('Failure_各子类_detail原样保留且是Failure', () {
      final failures = <Failure>[
        const NetworkFailure('n'),
        const RateLimitedFailure('r'),
        const UnauthorizedFailure('u'),
        const KeyExpiredFailure('k'),
        const ClockSkewFailure('c'),
        const ServiceDownFailure('s'),
        const ValidationFailure('v'),
        const WrongPasswordFailure('w'),
        const UnsupportedFailure('p'),
        const UnknownFailure('x'),
      ];
      expect(failures.map((f) => f.detail), [
        'n',
        'r',
        'u',
        'k',
        'c',
        's',
        'v',
        'w',
        'p',
        'x',
      ]);
    });

    test('Failure_无detail_toString只输出类型名', () {
      expect(const NetworkFailure().toString(), 'NetworkFailure');
      expect(const UnknownFailure().detail, isNull);
    });

    test('Failure_有detail_toString附带detail', () {
      expect(
        const RateLimitedFailure('请稍后再试').toString(),
        'RateLimitedFailure(请稍后再试)',
      );
    });

    test('DuplicateAddressFailure_可携带detail', () {
      const f = DuplicateAddressFailure(
        shortAddress: '0x12ab…9f3c',
        detail: '调试信息',
      );
      expect(f.detail, '调试信息');
      expect(f.toString(), 'DuplicateAddressFailure(调试信息)');
    });
  });

  group('DuplicateAddressFailure', () {
    test('DuplicateAddressFailure_有所属账户名_不属于输入内重复', () {
      const f = DuplicateAddressFailure(
        shortAddress: '0x12ab…9f3c',
        existingAccountName: '主钱包',
      );
      expect(f.isWithinInput, isFalse);
      expect(f.shortAddress, '0x12ab…9f3c');
      expect(f.existingAccountName, '主钱包');
      expect(f, isA<Failure>());
    });

    test('DuplicateAddressFailure_无所属账户名_属于输入内重复', () {
      const f = DuplicateAddressFailure(shortAddress: '0x12ab…9f3c');
      expect(f.isWithinInput, isTrue);
      expect(f.detail, isNull);
      expect(f.toString(), 'DuplicateAddressFailure');
    });

    test('DuplicateAddressFailure_所属账户缺失_既不是输入内重复也没有账户名', () {
      const f = DuplicateAddressFailure(
        shortAddress: '0x12ab…9f3c',
        ownerMissing: true,
      );
      expect(f.kind, DuplicateAddressKind.ownerMissing);
      expect(f.isWithinInput, isFalse);
      expect(f.existingAccountName, isNull);
    });

    test('DuplicateAddressFailure_kind_三种情形各自对应', () {
      expect(
        const DuplicateAddressFailure(
          shortAddress: 'a',
          existingAccountName: '主钱包',
        ).kind,
        DuplicateAddressKind.existing,
      );
      expect(
        const DuplicateAddressFailure(shortAddress: 'a').kind,
        DuplicateAddressKind.withinInput,
      );
    });
  });

  group('UnsupportedFailure', () {
    test('UnsupportedFailure_默认原因为platform', () {
      const f = UnsupportedFailure('x');
      expect(f.reason, UnsupportedReason.platform);
      expect(f.detail, 'x');
    });

    test('UnsupportedFailure_notIntegrated构造_原因为notIntegrated', () {
      const f = UnsupportedFailure.notIntegrated('尚未接入');
      expect(f.reason, UnsupportedReason.notIntegrated);
      expect(f.detail, '尚未接入');
      expect(f, isA<UnsupportedFailure>());
    });
  });
}
