import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

void main() {
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
  });
}
