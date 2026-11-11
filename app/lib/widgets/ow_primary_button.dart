import 'package:flutter/material.dart';

import 'ow_button_style.dart';

/// 主按钮：`brand` 背景，整行宽，高 46（不小于 44）。
///
/// 每个页面至多放一个。[label] 写动作（"保存""测试并保存"），不写"确定"。
/// [onPressed] 为空时按钮置灰且不可点击。
class OwPrimaryButton extends StatelessWidget {
  const OwPrimaryButton({super.key, required this.label, this.onPressed});

  /// 按钮文字。
  final String label;

  /// 点击回调；为空表示禁用。
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: owFilledButtonStyle(context),
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}
