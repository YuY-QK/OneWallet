import 'package:flutter/material.dart';

import '../theme/ow_colors.dart';
import 'ow_button_style.dart';

/// 次按钮：透明背景加边框，文字用 `brand` 色。
///
/// 默认整行宽；[compact] 为真时是行内的小按钮（如列表行右侧的"复制"），
/// 外观变小但可点击区域仍不小于 44×44。
class OwSecondaryButton extends StatelessWidget {
  const OwSecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.compact = false,
  });

  /// 按钮文字。
  final String label;

  /// 点击回调；为空表示禁用。
  final VoidCallback? onPressed;

  /// 是否使用小按钮规格。
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: owOutlinedButtonStyle(
        context,
        foreground: context.ow.brand,
        compact: compact,
      ),
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}
