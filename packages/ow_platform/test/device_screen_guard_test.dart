import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ow_platform/ow_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MethodChannel channel;
  late StreamController<bool> captureStreamController;
  late DeviceScreenGuard guard;

  setUp(() {
    channel = const MethodChannel('ow.platform/screen_guard');
    captureStreamController = StreamController<bool>.broadcast();
    guard = DeviceScreenGuard(
      channel: channel,
      captureActiveStream: captureStreamController.stream,
    );
  });

  tearDown(() async {
    await captureStreamController.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('enable_调用通道enable方法', () async {
    var enabled = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'enable') {
            enabled = true;
          }
          return null;
        });

    await guard.enable();
    expect(enabled, isTrue);
  });

  test('disable_调用通道disable方法', () async {
    var disabled = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'disable') {
            disabled = true;
          }
          return null;
        });

    await guard.disable();
    expect(disabled, isTrue);
  });

  test('captureActive_发出录屏状态事件', () async {
    final events = <bool>[];
    final sub = guard.captureActive.listen(events.add);

    captureStreamController.add(true);
    captureStreamController.add(false);

    await pumpEventQueue();
    expect(events, [true, false]);

    await sub.cancel();
  });
}
