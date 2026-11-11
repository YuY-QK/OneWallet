import 'package:flutter/material.dart';

import '../theme/ow_colors.dart';
import 'ow_button_style.dart';

/// 危险按钮：`down` 色文字加边框，整行宽。
///
/// [label] 必须写明动作，如"删除账户"，不用"确定"。
class OwDangerButton extends StatelessWidget {
  const OwDangerButton({super.key, required this.label, this.onPressed});

  /// 按钮文字。
  final String label;

  /// 点击回调；为空表示禁用。
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: owOutlinedButtonStyle(context, foreground: context.ow.down),
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}
