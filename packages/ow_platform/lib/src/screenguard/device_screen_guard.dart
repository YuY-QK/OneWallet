import 'dart:async';

import 'package:flutter/services.dart';
import 'package:ow_domain/ow_domain.dart';

/// 敏感页面的显示保护。
///
/// 通过平台通道 `ow.platform/screen_guard` 与原生系统交互：
/// - Android: 设置 `FLAG_SECURE` 禁止截屏并在任务切换器中隐藏内容
/// - iOS: 监听录屏与投屏状态
final class DeviceScreenGuard implements ScreenGuard {
  DeviceScreenGuard({
    MethodChannel? channel,
    EventChannel? eventChannel,
    this.captureActiveStream,
  }) : _channel = channel ?? const MethodChannel('ow.platform/screen_guard'),
       _eventChannel =
           eventChannel ??
           const EventChannel('ow.platform/screen_guard_events');

  final MethodChannel _channel;
  final EventChannel _eventChannel;
  final Stream<bool>? captureActiveStream;

  @override
  Future<void> enable() async {
    try {
      await _channel.invokeMethod<void>('enable');
    } on MissingPluginException {
      // 桌面端或测试环境不支持
    } on PlatformException {
      // 忽略平台异常
    }
  }

  @override
  Future<void> disable() async {
    try {
      await _channel.invokeMethod<void>('disable');
    } on MissingPluginException {
      // 桌面端或测试环境不支持
    } on PlatformException {
      // 忽略平台异常
    }
  }

  @override
  Stream<bool> get captureActive {
    final stream = captureActiveStream;
    if (stream != null) return stream;
    try {
      return _eventChannel
          .receiveBroadcastStream()
          .map((event) => event == true)
          .handleError((Object _) => false);
    } catch (_) {
      return Stream.value(false);
    }
  }
}
