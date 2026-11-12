import 'package:ow_domain/src/core/equality.dart';
import 'package:test/test.dart';

void main() {
  group('setEquals 与 setHash', () {
    test('setEquals_同一实例_相等', () {
      final s = {1, 2};
      expect(setEquals(s, s), isTrue);
    });

    test('setEquals_元素相同顺序不同_相等且哈希相同', () {
      final a = <String>{'x', 'y', 'z'};
      final b = <String>{'z', 'y', 'x'};
      expect(setEquals(a, b), isTrue);
      expect(setHash(a), setHash(b));
    });

    test('setEquals_长度不同_不相等', () {
      expect(setEquals({1, 2}, {1, 2, 3}), isFalse);
    });

    test('setEquals_长度相同但元素不同_不相等', () {
      expect(setEquals({1, 2}, {1, 3}), isFalse);
    });
  });

  group('mapEquals 与 mapHash', () {
    test('mapEquals_同一实例_相等', () {
      final m = {'a': 1};
      expect(mapEquals(m, m), isTrue);
    });

    test('mapEquals_键值相同顺序不同_相等且哈希相同', () {
      final a = {'a': 1, 'b': 2};
      final b = {'b': 2, 'a': 1};
      expect(mapEquals(a, b), isTrue);
      expect(mapHash(a), mapHash(b));
    });

    test('mapEquals_长度不同_不相等', () {
      expect(mapEquals({'a': 1}, {'a': 1, 'b': 2}), isFalse);
    });

    test('mapEquals_键不同_不相等', () {
      expect(mapEquals({'a': 1}, {'b': 1}), isFalse);
    });

    test('mapEquals_值不同_不相等', () {
      expect(mapEquals({'a': 1}, {'a': 2}), isFalse);
    });
  });

  group('listEquals', () {
    test('listEquals_同一实例_相等', () {
      final l = [1, 2];
      expect(listEquals(l, l), isTrue);
    });

    test('listEquals_逐项相同_相等', () {
      expect(listEquals([1, 2, 3], [1, 2, 3]), isTrue);
      expect(listEquals(<int>[], <int>[]), isTrue);
    });

    test('listEquals_顺序不同_不相等', () {
      expect(listEquals([1, 2], [2, 1]), isFalse);
    });

    test('listEquals_长度不同_不相等', () {
      expect(listEquals([1, 2], [1, 2, 3]), isFalse);
    });
  });

  group('unset 占位值', () {
    test('unset_是唯一的常量对象_用于区分未传入与null', () {
      expect(identical(unset, unset), isTrue);
      expect(unset, isNot(isNull));
      expect(identical(unset, null), isFalse);
    });
  });
}
