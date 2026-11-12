import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// 日志级别，由低到高。
enum OwLogLevel { debug, info, warn, error }

/// 极简的统一日志入口。不使用 `print`。
///
/// 规则（DEV_GUIDELINES 第 6 节）：调用方不得把助记词、私钥、密码、API Key、
/// 完整地址等敏感内容传进来；网络日志已由 `ow_net` 脱敏后才会到这里。
/// 发布构建不输出 debug 级别。
final class OwLogger {
  /// [minLevel] 默认：调试构建输出全部，发布构建从 info 起。
  /// [sink] 供测试截获输出；默认写入 `dart:developer` 的日志。
  OwLogger({OwLogLevel? minLevel, void Function(OwLogRecord record)? sink})
    : minLevel = minLevel ?? (kDebugMode ? OwLogLevel.debug : OwLogLevel.info),
      _sink = sink ?? _developerSink;

  final OwLogLevel minLevel;
  final void Function(OwLogRecord record) _sink;

  void debug(String tag, String message) =>
      _log(OwLogLevel.debug, tag, message);

  void info(String tag, String message) => _log(OwLogLevel.info, tag, message);

  void warn(String tag, String message) => _log(OwLogLevel.warn, tag, message);

  void error(String tag, String message) =>
      _log(OwLogLevel.error, tag, message);

  void _log(OwLogLevel level, String tag, String message) {
    if (level.index < minLevel.index) return;
    _sink(OwLogRecord(level: level, tag: tag, message: message));
  }

  static void _developerSink(OwLogRecord r) {
    developer.log(
      r.message,
      name: 'onewallet.${r.tag}',
      level: switch (r.level) {
        OwLogLevel.debug => 500,
        OwLogLevel.info => 800,
        OwLogLevel.warn => 900,
        OwLogLevel.error => 1000,
      },
    );
  }
}

/// 一条日志。
final class OwLogRecord {
  const OwLogRecord({
    required this.level,
    required this.tag,
    required this.message,
  });

  final OwLogLevel level;
  final String tag;
  final String message;
}
