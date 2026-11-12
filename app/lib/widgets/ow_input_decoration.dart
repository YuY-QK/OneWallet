import 'package:flutter/material.dart';

import '../theme/ow_colors.dart';
import '../theme/ow_metrics.dart';
import '../theme/ow_text_styles.dart';

/// 输入框的统一外观：`surface` 底、1 像素 `line` 边框、圆角 8。
InputDecoration owInputDecoration(
  BuildContext context, {
  String? hint,
  Widget? suffixIcon,
  bool readOnly = false,
  bool error = false,
}) {
  final c = context.ow;
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(OwMetrics.inputRadius),
    borderSide: BorderSide(color: color),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: OwTextStyles.body.copyWith(color: c.muted),
    filled: true,
    fillColor: readOnly ? c.brandSoft : c.surface,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    suffixIcon: suffixIcon,
    enabledBorder: border(error ? c.down : c.line),
    focusedBorder: border(error ? c.down : c.brand),
    border: border(c.line),
  );
}

/// 表单字段的小标题（说明色）。
class OwFieldLabel extends StatelessWidget {
  const OwFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Text(
      text,
      style: OwTextStyles.caption.copyWith(color: context.ow.muted),
    ),
  );
}
