import 'package:flutter/material.dart';

import '../../../../theme/ow_colors.dart';
import '../../../../theme/ow_metrics.dart';

/// 总览的骨架屏：与正常布局相近的灰色块（静态，不做动画）。
class OverviewSkeleton extends StatelessWidget {
  const OverviewSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.ow;
    Widget block(double height, {double? width}) => DecoratedBox(
      decoration: BoxDecoration(
        color: c.line,
        borderRadius: BorderRadius.circular(OwMetrics.smallRadius),
      ),
      child: SizedBox(height: height, width: width ?? double.infinity),
    );
    return Semantics(
      label: 'loading',
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: c.surface,
              border: Border.all(color: c.line),
              borderRadius: OwMetrics.cardBorderRadius,
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  block(12, width: 90),
                  const SizedBox(height: 10),
                  block(30, width: 200),
                  const SizedBox(height: 10),
                  block(12, width: 140),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          block(44),
          const SizedBox(height: 12),
          for (var i = 0; i < 4; i++) ...[block(54), const SizedBox(height: 8)],
        ],
      ),
    );
  }
}
