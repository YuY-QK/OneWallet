import 'package:flutter/painting.dart';

/// 字体族名称，与 `pubspec.yaml` 中注册的一致。
abstract final class OwFonts {
  /// 正文与标题的西文字体（IBM Plex Sans）。
  static const sans = 'IBMPlexSans';

  /// 数字、地址、助记词字体（IBM Plex Mono）。
  static const mono = 'IBMPlexMono';

  /// 中文及 Plex 未覆盖字形的后备字体，按平台顺序列出。
  static const fallback = <String>[
    'PingFang SC',
    'Noto Sans SC',
    'Noto Sans CJK SC',
    'Microsoft YaHei',
    'sans-serif',
  ];
}

/// 字号表，取值见 docs/UI_DESIGN_SYSTEM_v1.0.md 第 3 节。
///
/// 这里的样式不带颜色，颜色由使用处通过 `context.ow` 或所在的
/// `DefaultTextStyle` 决定，这样同一份样式在浅色、深色下都适用。
/// 行高按"行高 / 字号"换算为 [TextStyle.height]。
abstract final class OwTextStyles {
  static TextStyle _sans(double size, double lineHeight, FontWeight weight) =>
      TextStyle(
        fontFamily: OwFonts.sans,
        fontFamilyFallback: OwFonts.fallback,
        fontSize: size,
        height: lineHeight / size,
        fontWeight: weight,
      );

  /// 大数字：28 / 34，600，等宽数字。用于总资产。
  static final TextStyle display = mono.copyWith(
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
  );

  /// 页面标题：17 / 24，600。用于顶栏。
  static final TextStyle title = _sans(17, 24, FontWeight.w600);

  /// 强调：16 / 24，600。用于卡片标题。
  static final TextStyle emphasis = _sans(16, 24, FontWeight.w600);

  /// 正文：14 / 21，400。用于列表、表单。
  static final TextStyle body = _sans(14, 21, FontWeight.w400);

  /// 行标题：14 / 21，500。
  static final TextStyle rowTitle = _sans(14, 21, FontWeight.w500);

  /// 说明：12.5 / 18，400。用于次要信息。
  static final TextStyle caption = _sans(12.5, 18, FontWeight.w400);

  /// 标签：11.5 / 16，500。用于状态胶囊。
  static final TextStyle label = _sans(11.5, 16, FontWeight.w500);

  /// 等宽数字样式：IBM Plex Mono 加等宽数字特性，14 / 21，400。
  ///
  /// 金额、数量、地址都用它；需要别的字号或字重时在其上 `copyWith`。
  static const TextStyle mono = TextStyle(
    fontFamily: OwFonts.mono,
    fontFamilyFallback: OwFonts.fallback,
    fontSize: 14,
    height: 21 / 14,
    fontWeight: FontWeight.w400,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
