import 'package:flutter/material.dart';

import '../theme/ow_colors.dart';
import '../theme/ow_metrics.dart';

/// 列表容器：一个圆角容器内的若干行，行与行之间用 1 像素 `line` 分隔线。
///
/// 通常放 [OwRow]。容器本身不带内边距，行自己负责左右 14 的内边距。
class OwListGroup extends StatelessWidget {
  const OwListGroup({super.key, required this.children});

  /// 列表的各行。
  final List<Widget> children;

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: c.line),
            children[i],
          ],
        ],
      ),
    );
  }
}
