import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ow_platform/ow_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MethodChannel channel;
  late DevicePlatformIntegrity integrity;

  setUp(() {
    channel = const MethodChannel('ow.platform/device_integrity');
    integrity = DevicePlatformIntegrity(channel: channel);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('looksCompromised_通道返回true时_返回true', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'looksCompromised') return true;
          return null;
        });

    expect(await integrity.looksCompromised(), isTrue);
  });

  test('looksCompromised_通道返回false时_返回false', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'looksCompromised') return false;
          return null;
        });

    expect(await integrity.looksCompromised(), isFalse);
  });

  test('looksCompromised_通道未注册或未实现时_优雅降级返回false', () async {
    expect(await integrity.looksCompromised(), isFalse);
  });

  test('looksCompromised_通道抛出PlatformException时_捕获并返回false', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: 'ERROR', message: 'Failed to inspect');
        });

    expect(await integrity.looksCompromised(), isFalse);
  });
}
