import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 字体文件必须是真正的 TrueType 文件，而不是下载失败留下的网页。
void main() {
  const files = [
    'IBMPlexSans-Regular.ttf',
    'IBMPlexSans-Medium.ttf',
    'IBMPlexSans-SemiBold.ttf',
    'IBMPlexMono-Regular.ttf',
    'IBMPlexMono-Medium.ttf',
    'IBMPlexMono-SemiBold.ttf',
  ];
  final pubspec = File('pubspec.yaml').readAsStringSync();

  for (final name in files) {
    test('字体文件_${name}_是有效TTF且已在pubspec注册', () {
      final file = File('assets/fonts/$name');
      expect(file.existsSync(), isTrue);
      final bytes = file.readAsBytesSync();
      expect(bytes.length, greaterThan(50 * 1024));
      // TrueType 文件头：0x00010000。
      expect(bytes.sublist(0, 4), [0x00, 0x01, 0x00, 0x00]);
      expect(pubspec, contains('assets/fonts/$name'));
    });
  }

  test('字体许可_OFL文件_存在且为SIL开放字体许可', () {
    final text = File('assets/fonts/OFL.txt').readAsStringSync();
    expect(text, contains('SIL OPEN FONT LICENSE Version 1.1'));
  });
}
