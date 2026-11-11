import 'package:flutter/material.dart';

import '../theme/ow_colors.dart';
import '../theme/ow_metrics.dart';

/// 卡片：`surface` 背景、1 像素 `line` 边框、圆角 10、内边距 14，无阴影。
///
/// 只用于摘要和需要突出的内容。内部用 [Material] 承载，里面的
/// 水波纹与悬停效果才能画在卡片背景之上。
class OwCard extends StatelessWidget {
  const OwCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  /// 卡片内容。
  final Widget child;

  /// 内边距，默认 14。
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = context.ow;
    return Material(
      color: c.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: OwMetrics.cardBorderRadius,
        side: BorderSide(color: c.line),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
