import 'package:flutter/painting.dart';

/// 间距、圆角与最小尺寸，取值见 docs/UI_DESIGN_SYSTEM_v1.0.md 第 4 节。
abstract final class OwMetrics {
  /// 间距刻度：4、6、8、12、16、20、28。
  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s28 = 28;

  /// 卡片与列表圆角。
  static const double cardRadius = 10;

  /// 输入框与分段控件圆角。
  static const double inputRadius = 8;

  /// 小按钮圆角。
  static const double smallRadius = 7;

  /// 列表行最小高度。
  static const double rowMinHeight = 54;

  /// 可点击区域的最小边长。
  static const double minTapSize = 44;

  /// 主要按钮的高度下限（不小于 44）。
  static const double buttonHeight = 46;

  static const BorderRadius cardBorderRadius = BorderRadius.all(
    Radius.circular(cardRadius),
  );
}
