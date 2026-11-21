import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:ow_platform/ow_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Android_防截屏block_有相机_无硬件密钥与生物识别', () {
    final c = DevicePlatformCapabilities(platform: TargetPlatform.android);
    expect(c.screenProtection, ScreenProtection.block);
    expect(c.camera, isTrue);
    expect(c.hardwareKeystore, isFalse);
    expect(c.biometrics, isFalse);
  });

  test('iOS_detect_有相机', () {
    final c = DevicePlatformCapabilities(platform: TargetPlatform.iOS);
    expect(c.screenProtection, ScreenProtection.detect);
    expect(c.camera, isTrue);
  });

  test('桌面_none_无相机', () {
    for (final p in [
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      final c = DevicePlatformCapabilities(platform: p);
      expect(c.screenProtection, ScreenProtection.none);
      expect(c.camera, isFalse);
    }
  });

  test('probe_探测移动端硬件与生物识别能力', () async {
    const bioChannel = MethodChannel('mock.bio');
    const ksChannel = MethodChannel('mock.ks');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bioChannel, (call) async {
          if (call.method == 'isAvailable') return true;
          return null;
        });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ksChannel, (call) async {
          if (call.method == 'isAvailable') return true;
          return null;
        });

    final c = await DevicePlatformCapabilities.probe(
      platform: TargetPlatform.iOS,
      biometricsChannel: bioChannel,
      keystoreChannel: ksChannel,
    );

    expect(c.hardwareKeystore, isTrue);
    expect(c.biometrics, isTrue);
    expect(c.screenProtection, ScreenProtection.detect);
    expect(c.camera, isTrue);
  });
}
