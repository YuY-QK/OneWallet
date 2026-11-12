import 'dart:async';

/// 两个流各自至少发出一个值后，任一流再发出新值时，用两者的最新值调用 [combine]
/// 并发出结果。其余行为同 [combineLatest3]。
Stream<R> combineLatest2<A, B, R>(
  Stream<A> a,
  Stream<B> b,
  R Function(A a, B b) combine,
) => combineLatest3<A, B, int, R>(
  a,
  b,
  // 第三路只是占位：一个立即结束的流，不影响其余两路的合并与结束。
  Stream.value(0),
  (x, y, _) => combine(x, y),
);

/// 三个流各自至少发出一个值后，任一流再发出新值时，用三者的最新值调用 [combine]
/// 并发出结果。
///
/// 输出为单订阅流：被监听时才订阅上游，取消时取消全部上游订阅；
/// 暂停与恢复会传给上游。任一上游出错时转发错误；全部上游结束时结束。
Stream<R> combineLatest3<A, B, C, R>(
  Stream<A> a,
  Stream<B> b,
  Stream<C> c,
  R Function(A a, B b, C c) combine,
) {
  late final StreamController<R> controller;
  final subs = <StreamSubscription<Object?>>[];
  (A,)? lastA;
  (B,)? lastB;
  (C,)? lastC;
  var open = 3;

  void emit() {
    if (lastA case (final va,)) {
      if (lastB case (final vb,)) {
        if (lastC case (final vc,)) controller.add(combine(va, vb, vc));
      }
    }
  }

  void done() {
    if (--open == 0) controller.close();
  }

  controller = StreamController<R>(
    onListen: () {
      subs
        ..add(
          a.listen(
            (v) {
              lastA = (v,);
              emit();
            },
            onError: controller.addError,
            onDone: done,
          ),
        )
        ..add(
          b.listen(
            (v) {
              lastB = (v,);
              emit();
            },
            onError: controller.addError,
            onDone: done,
          ),
        )
        ..add(
          c.listen(
            (v) {
              lastC = (v,);
              emit();
            },
            onError: controller.addError,
            onDone: done,
          ),
        );
    },
    onPause: () {
      for (final s in subs) {
        s.pause();
      }
    },
    onResume: () {
      for (final s in subs) {
        s.resume();
      }
    },
    onCancel: () => Future.wait([for (final s in subs) s.cancel()]),
  );
  return controller.stream;
}

/// [source] 每发出一个值，就改为订阅 [project] 由它得到的流，并取消上一个内层流。
///
/// 输出为单订阅流。外层出错或内层出错都会转发；外层结束且当前内层结束后结束。
Stream<T> switchLatest<S, T>(Stream<S> source, Stream<T> Function(S) project) {
  late final StreamController<T> controller;
  StreamSubscription<S>? outer;
  StreamSubscription<T>? inner;
  var outerDone = false;

  void maybeClose() {
    if (outerDone && inner == null) controller.close();
  }

  controller = StreamController<T>(
    onListen: () {
      outer = source.listen(
        (s) {
          final previous = inner;
          inner = null;
          // 不等待旧订阅取消完成：取消后它不会再投递值。
          unawaited(previous?.cancel());
          final sub = project(s)
              .listen(controller.add, onError: controller.addError);
          sub.onDone(() {
            if (identical(inner, sub)) inner = null;
            maybeClose();
          });
          inner = sub;
        },
        onError: controller.addError,
        onDone: () {
          outerDone = true;
          maybeClose();
        },
      );
    },
    onPause: () {
      outer?.pause();
      inner?.pause();
    },
    onResume: () {
      outer?.resume();
      inner?.resume();
    },
    onCancel: () async {
      await inner?.cancel();
      await outer?.cancel();
    },
  );
  return controller.stream;
}
