import 'dart:typed_data';

import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

void main() {
  group('Result', () {
    test('Ok_map_转换值', () {
      const Result<int> r = Ok(2);
      expect(r.map((v) => v * 3).valueOrNull, 6);
      expect(r.isOk, isTrue);
    });

    test('Err_map_保留失败', () {
      const Result<int> r = Err(RateLimitedFailure());
      final mapped = r.map((v) => v * 3);
      expect(mapped.isOk, isFalse);
      expect(
        mapped.when(ok: (_) => null, err: (f) => f),
        isA<RateLimitedFailure>(),
      );
    });
  });

  group('Sensitive', () {
    test('toString_任何时候_不泄露内容', () {
      final s = Sensitive(Uint8List.fromList('legal winner'.codeUnits));
      expect(s.toString(), '***');
      expect('$s', isNot(contains('legal')));
    });

    test('wipe_之后_原字节被清零且不可再读', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final s = Sensitive(bytes);
      expect(s.use((b) => b.length), 4);
      s.wipe();
      expect(bytes, everyElement(0));
      expect(s.isWiped, isTrue);
      expect(() => s.use((b) => b), throwsStateError);
    });
  });
}
