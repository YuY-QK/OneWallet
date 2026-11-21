import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:ow_platform/ow_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MethodChannel channel;
  late DeviceBiometricAuth auth;

  setUp(() {
    channel = const MethodChannel('ow.platform/biometrics');
    auth = DeviceBiometricAuth(channel: channel);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('isAvailable_通道返回true时_返回true', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'isAvailable') return true;
          return null;
        });

    expect(await auth.isAvailable(), isTrue);
  });

  test('isAvailable_通道未实现时_优雅降级返回false', () async {
    expect(await auth.isAvailable(), isFalse);
  });

  test('authenticate_成功时返回Ok', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'authenticate') {
            final args = call.arguments as Map<dynamic, dynamic>;
            expect(args['reason'], 'test reason');
            return true;
          }
          return null;
        });

    final res = await auth.authenticate(reason: 'test reason');
    expect(res, isA<Ok<void>>());
  });

  test('authenticate_失败时返回Err(ValidationFailure)', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'authenticate') return false;
          return null;
        });

    final res = await auth.authenticate(reason: 'test reason');
    expect(res, isA<Err<void>>());
  });
}
