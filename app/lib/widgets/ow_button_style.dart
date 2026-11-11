import 'package:flutter/material.dart';

import '../theme/ow_colors.dart';
import '../theme/ow_metrics.dart';
import '../theme/ow_text_styles.dart';

// 三种按钮共用的样式，只在 widgets/ 内部使用。

/// 实心主按钮样式：`brand` 底、`brandInk` 字，整行宽，高度不小于 44。
ButtonStyle owFilledButtonStyle(BuildContext context) {
  final c = context.ow;
  return FilledButton.styleFrom(
    backgroundColor: c.brand,
    foregroundColor: c.brandInk,
    minimumSize: const Size.fromHeight(OwMetrics.buttonHeight),
    shape: const RoundedRectangleBorder(
      borderRadius: OwMetrics.cardBorderRadius,
    ),
    textStyle: OwTextStyles.body.copyWith(fontWeight: FontWeight.w600),
  );
}

/// 描边按钮样式：透明底、1 像素 `line` 边框、[foreground] 色文字。
///
/// [compact] 为真时用小按钮规格（圆角 7、较小内边距），但可点击区域
/// 仍不小于 44×44，靠 `MaterialTapTargetSize.padded` 补足。
ButtonStyle owOutlinedButtonStyle(
  BuildContext context, {
  required Color foreground,
  bool compact = false,
}) {
  final c = context.ow;
  return OutlinedButton.styleFrom(
    foregroundColor: foreground,
    side: BorderSide(color: c.line),
    minimumSize: compact
        ? const Size(0, 32)
        : const Size.fromHeight(OwMetrics.buttonHeight),
    padding: compact
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 5)
        : null,
    tapTargetSize: MaterialTapTargetSize.padded,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(
        compact ? OwMetrics.smallRadius : OwMetrics.cardRadius,
      ),
    ),
    textStyle: compact
        ? OwTextStyles.caption.copyWith(fontWeight: FontWeight.w500)
        : OwTextStyles.body.copyWith(fontWeight: FontWeight.w600),
  );
}
