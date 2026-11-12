import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:ow_platform/ow_platform.dart';

void main() {
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
}
