import 'package:decimal/decimal.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

Snapshot snap({
  DateTime? date,
  String total = '100',
  bool complete = true,
  Map<String, Decimal>? byAccount,
  Map<String, Decimal>? byAsset,
}) => Snapshot(
  date: date ?? DateTime.utc(2026, 3, 1),
  totalUsd: Decimal.parse(total),
  complete: complete,
  byAccountUsd: byAccount ?? {'acc-1': Decimal.parse('60')},
  byAssetUsd: byAsset ?? {'ETH': Decimal.parse('100')},
);

void main() {
  group('Snapshot', () {
    test('Snapshot_构造后_字段可读', () {
      final s = snap();
      expect(s.date, DateTime.utc(2026, 3, 1));
      expect(s.totalUsd, Decimal.parse('100'));
      expect(s.complete, isTrue);
      expect(s.byAccountUsd, {'acc-1': Decimal.parse('60')});
      expect(s.byAssetUsd, {'ETH': Decimal.parse('100')});
    });

    test('Snapshot_同步未全部成功_complete为false', () {
      expect(snap(complete: false).complete, isFalse);
    });

    test('Snapshot_字段相同_相等且哈希相同', () {
      final a = snap();
      final b = snap();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('Snapshot_映射键值顺序不同_相等且哈希相同', () {
      final a = snap(
        byAccount: {'acc-1': Decimal.parse('60'), 'acc-2': Decimal.parse('40')},
      );
      final b = snap(
        byAccount: {'acc-2': Decimal.parse('40'), 'acc-1': Decimal.parse('60')},
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('Snapshot_任一字段不同_不相等', () {
      final base = snap();
      expect(snap(date: DateTime.utc(2026, 3, 2)), isNot(base));
      expect(snap(total: '101'), isNot(base));
      expect(snap(complete: false), isNot(base));
      expect(snap(byAccount: {'acc-1': Decimal.parse('61')}), isNot(base));
      expect(snap(byAccount: {'acc-9': Decimal.parse('60')}), isNot(base));
      expect(
        snap(byAccount: {'acc-1': Decimal.parse('60'), 'acc-2': Decimal.one}),
        isNot(base),
      );
      expect(snap(byAsset: {'BTC': Decimal.parse('100')}), isNot(base));
    });

    test('Snapshot_构造后修改源映射_快照不受影响', () {
      final source = {'acc-1': Decimal.parse('60')};
      final s = snap(byAccount: source);
      source['acc-2'] = Decimal.parse('40');
      expect(s.byAccountUsd, {'acc-1': Decimal.parse('60')});
    });

    test('Snapshot_映射不可修改', () {
      final s = snap();
      expect(
        () => s.byAccountUsd['acc-2'] = Decimal.one,
        throwsUnsupportedError,
      );
      expect(() => s.byAssetUsd.remove('ETH'), throwsUnsupportedError);
    });

    test('toString_含日期与总额', () {
      expect(snap().toString(), 'Snapshot(2026-03-01T00:00:00.000Z, 100)');
    });
  });
}
