import 'package:flutter/material.dart';

import '../theme/ow_colors.dart';
import '../theme/ow_metrics.dart';
import '../theme/ow_text_styles.dart';

/// 头像的形状。
enum OwAvatarShape {
  /// 圆形：币种与钱包。
  circle,

  /// 圆角方形：交易所与保险库条目。
  roundedSquare,
}

/// 头像：`brandSoft` 底，中间是等宽字体的简短标记（如币种代码）。
///
/// 圆形表示币种与钱包；圆角方形表示交易所与保险库条目。
/// 标记过长时整体缩小以适应，不会溢出。
class OwAvatar extends StatelessWidget {
  const OwAvatar({
    super.key,
    required this.label,
    this.shape = OwAvatarShape.circle,
    this.size = 30,
  });

  /// 显示在头像中的简短文字，如 `ETH`。
  final String label;

  /// 形状，默认圆形。
  final OwAvatarShape shape;

  /// 边长（直径），默认 30。
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.ow;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.brandSoft,
        shape: shape == OwAvatarShape.circle
            ? BoxShape.circle
            : BoxShape.rectangle,
        borderRadius: shape == OwAvatarShape.circle
            ? null
            : BorderRadius.circular(OwMetrics.smallRadius),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          maxLines: 1,
          style: OwTextStyles.mono.copyWith(
            fontSize: 11,
            height: 1,
            fontWeight: FontWeight.w600,
            color: c.brand,
          ),
        ),
      ),
    );
  }
}
