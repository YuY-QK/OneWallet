import 'package:flutter/material.dart';

import '../theme/ow_colors.dart';

/// 占比条：4 像素高，`line` 底，`brand` 填充。
///
/// [fraction] 是 0 到 1 之间的占比（只用于画图，不是金额，所以用 `double`）；
/// 超出范围时截到 0 和 1。
class OwShareBar extends StatelessWidget {
  const OwShareBar({super.key, required this.fraction, this.semanticLabel});

  /// 占比，0 到 1。
  final double fraction;

  /// 读屏软件读出的说明，如"占总资产 42%"。为空时该条不被读出。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.ow;
    final f = fraction.isNaN ? 0.0 : fraction.clamp(0.0, 1.0);
    return Semantics(
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: SizedBox(
          height: 4,
          width: double.infinity,
          child: ColoredBox(
            color: c.line,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: FractionallySizedBox(
                widthFactor: f,
                heightFactor: 1,
                child: ColoredBox(color: c.brand),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
