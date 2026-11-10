import 'package:flutter/widgets.dart';

/// 屏幕档位。规则见 PRD 7.3。
enum ScreenSize {
  /// 手机：底部导航，单栏。
  compact,

  /// 平板、小窗口：图标侧栏，双栏。
  medium,

  /// 桌面：带文字的侧栏，双栏或三栏。
  expanded,
}

abstract final class Breakpoints {
  static const double medium = 600;
  static const double expanded = 1024;

  static ScreenSize of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  static ScreenSize fromWidth(double width) {
    if (width >= expanded) return ScreenSize.expanded;
    if (width >= medium) return ScreenSize.medium;
    return ScreenSize.compact;
  }
}
