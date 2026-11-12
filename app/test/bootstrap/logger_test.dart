import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/bootstrap/logger.dart';

void main() {
  test('发布级别_不输出debug_输出info及以上', () {
    final records = <OwLogRecord>[];
    OwLogger(minLevel: OwLogLevel.info, sink: records.add)
      ..debug('t', 'd')
      ..info('t', 'i')
      ..warn('t', 'w')
      ..error('t', 'e');
    expect(records.map((r) => r.level), [
      OwLogLevel.info,
      OwLogLevel.warn,
      OwLogLevel.error,
    ]);
  });

  test('调试级别_全部输出_带标签', () {
    final records = <OwLogRecord>[];
    OwLogger(minLevel: OwLogLevel.debug, sink: records.add).debug('net', 'x');
    expect(records.single.tag, 'net');
    expect(records.single.message, 'x');
  });

  test('error级别过滤_只输出error', () {
    final records = <OwLogRecord>[];
    OwLogger(minLevel: OwLogLevel.error, sink: records.add)
      ..warn('t', 'w')
      ..error('t', 'e');
    expect(records.map((r) => r.message), ['e']);
  });

  test('默认sink不抛异常', () {
    OwLogger(minLevel: OwLogLevel.debug)
      ..debug('t', 'a')
      ..info('t', 'b')
      ..warn('t', 'c')
      ..error('t', 'd');
  });
}
