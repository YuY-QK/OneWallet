import 'dart:async';

import 'package:ow_application/src/util/stream_combine.dart';
import 'package:test/test.dart';

void main() {
  group('combineLatest3', () {
    test('combineLatest3_三者都有值之前_不发出；之后任一变化都发出', () async {
      final a = StreamController<int>();
      final b = StreamController<int>();
      final c = StreamController<int>();
      final out = <String>[];
      final sub = combineLatest3(
        a.stream,
        b.stream,
        c.stream,
        (x, y, z) => '$x$y$z',
      ).listen(out.add);

      a.add(1);
      b.add(2);
      await pumpEventQueue();
      expect(out, isEmpty);
      c.add(3);
      b.add(5);
      await pumpEventQueue();
      expect(out, ['123', '153']);
      await sub.cancel();
    });

    test('combineLatest3_上游出错_转发错误；全部结束_输出结束', () async {
      final a = StreamController<int>();
      final errors = <Object>[];
      final done = Completer<void>();
      combineLatest3(
        a.stream,
        Stream.value(1),
        Stream.value(2),
        (x, y, z) => x + y + z,
      ).listen((_) {}, onError: errors.add, onDone: done.complete);

      a.addError(StateError('x'));
      await a.close();
      await done.future;
      expect(errors.single, isA<StateError>());
    });

    test('combineLatest3_暂停与恢复_传给上游', () async {
      final a = StreamController<int>();
      final out = <int>[];
      final sub = combineLatest3(
        a.stream,
        Stream.value(0),
        Stream.value(0),
        (x, y, z) => x,
      ).listen(out.add);
      await pumpEventQueue();
      sub.pause();
      expect(a.isPaused, isTrue);
      sub.resume();
      a.add(4);
      await pumpEventQueue();
      expect(out, [4]);
      await sub.cancel();
      expect(a.hasListener, isFalse);
    });
  });

  group('switchLatest', () {
    test('switchLatest_外层发出新值_取消旧内层并改订新内层', () async {
      final outer = StreamController<String>();
      final inners = {
        'x': StreamController<int>.broadcast(),
        'y': StreamController<int>.broadcast(),
      };
      final out = <int>[];
      final sub = switchLatest(
        outer.stream,
        (String k) => inners[k]?.stream ?? const Stream<int>.empty(),
      ).listen(out.add);

      outer.add('x');
      await pumpEventQueue();
      inners['x']?.add(1);
      outer.add('y');
      await pumpEventQueue();
      inners['x']?.add(2);
      inners['y']?.add(3);
      await pumpEventQueue();
      expect(out, [1, 3]);

      sub.pause();
      sub.resume();
      await sub.cancel();
    });

    test('switchLatest_外层与当前内层都结束_输出结束并转发错误', () async {
      final errors = <Object>[];
      final done = Completer<void>();
      switchLatest(
        Stream.fromIterable([1, 2]),
        (int v) =>
            v == 2 ? Stream<int>.error(StateError('inner')) : Stream.value(v),
      ).listen((_) {}, onError: errors.add, onDone: done.complete);
      await done.future;
      expect(errors.single, isA<StateError>());
    });
  });
}
