import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/theme/ow_text_styles.dart';
import 'package:onewallet/theme/ow_theme.dart';

void main() {
  test('OwTextStyles_字号表_与设计规范一致', () {
    void expectStyle(
      TextStyle s,
      double size,
      double lineHeight,
      FontWeight weight,
    ) {
      expect(s.fontSize, size);
      expect(s.height! * s.fontSize!, closeTo(lineHeight, 0.001));
      expect(s.fontWeight, weight);
    }

    expectStyle(OwTextStyles.display, 28, 34, FontWeight.w600);
    expectStyle(OwTextStyles.title, 17, 24, FontWeight.w600);
    expectStyle(OwTextStyles.emphasis, 16, 24, FontWeight.w600);
    expectStyle(OwTextStyles.body, 14, 21, FontWeight.w400);
    expectStyle(OwTextStyles.rowTitle, 14, 21, FontWeight.w500);
    expectStyle(OwTextStyles.caption, 12.5, 18, FontWeight.w400);
    expectStyle(OwTextStyles.label, 11.5, 16, FontWeight.w500);
  });

  test('OwTextStyles.mono_默认_等宽字体加等宽数字', () {
    expect(OwTextStyles.mono.fontFamily, 'IBMPlexMono');
    expect(OwTextStyles.mono.fontFeatures, contains(isA<FontFeature>()));
    expect(
      OwTextStyles.mono.fontFeatures!.single,
      const FontFeature.tabularFigures(),
    );
    expect(OwTextStyles.display.fontFamily, 'IBMPlexMono');
  });

  test('OwTextStyles_正文样式_西文用PlexSans并带中文后备', () {
    expect(OwTextStyles.body.fontFamily, 'IBMPlexSans');
    expect(OwTextStyles.body.fontFamilyFallback, OwFonts.fallback);
    expect(OwFonts.fallback, contains('PingFang SC'));
    expect(OwFonts.fallback, contains('Noto Sans CJK SC'));
  });

  for (final b in Brightness.values) {
    test('buildOwTheme_${b.name}_默认字体为PlexSans', () {
      final t = buildOwTheme(b);
      expect(t.textTheme.bodyMedium!.fontFamily, 'IBMPlexSans');
      expect(t.textTheme.bodyMedium!.fontFamilyFallback, OwFonts.fallback);
    });
  }
}
