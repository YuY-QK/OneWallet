import 'package:flutter/material.dart';

import '../theme/ow_colors.dart';
import 'breakpoints.dart';

/// 列表加详情的布局。
///
/// 窄屏只显示 [list]，详情通过路由逐级进入；中屏和宽屏并排显示，
/// 没有选中项时右侧显示 [placeholder]。
class ListDetailLayout extends StatelessWidget {
  const ListDetailLayout({
    super.key,
    required this.list,
    this.detail,
    this.placeholder,
    this.listWidth = 360,
  });

  final Widget list;
  final Widget? detail;
  final Widget? placeholder;
  final double listWidth;

  /// 当前档位下详情是否与列表并排显示。
  static bool showsDetailInline(BuildContext context) =>
      Breakpoints.of(context) != ScreenSize.compact;

  @override
  Widget build(BuildContext context) {
    if (!showsDetailInline(context)) return list;
    return Row(
      children: [
        SizedBox(width: listWidth, child: list),
        VerticalDivider(width: 1, color: context.ow.line),
        Expanded(child: detail ?? placeholder ?? const SizedBox.shrink()),
      ],
    );
  }
}
