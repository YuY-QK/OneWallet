import 'package:flutter/material.dart';

import '../theme/ow_colors.dart';
import '../theme/ow_text_styles.dart';
import 'formatters.dart';

/// 金额文字的颜色语义。
enum OwAmountTone {
  /// 主要文字色。
  neutral,

  /// 次要文字色。
  muted,

  /// 上涨、成功。
  up,

  /// 下跌、失败。
  down,
}

/// 金额与数量文字：IBM Plex Mono 加等宽数字，数字上下对齐。
///
/// 文字内容由调用方用 `formatters.dart` 的函数格式化后传入。
/// [hidden] 为真（"隐藏金额"开启）时显示 `****`，原数字不进入组件树。
/// 涨跌用颜色之外，还应在 [text] 里带正负号或箭头。
class OwAmountText extends StatelessWidget {
  const OwAmountText(
    this.text, {
    super.key,
    this.hidden = false,
    this.tone = OwAmountTone.neutral,
    this.style,
    this.textAlign,
  });

  /// 已格式化的金额或数量。
  final String text;

  /// 是否隐藏。
  final bool hidden;

  /// 颜色语义。
  final OwAmountTone tone;

  /// 在等宽样式之上叠加的样式（字号、字重等）。字体族仍保持等宽，
  /// 除非显式覆盖。
  final TextStyle? style;

  /// 对齐方式。
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final c = context.ow;
    final color = switch (tone) {
      OwAmountTone.neutral => c.ink,
      OwAmountTone.muted => c.muted,
      OwAmountTone.up => c.up,
      OwAmountTone.down => c.down,
    };
    return Text(
      maskIfHidden(text, hidden: hidden),
      textAlign: textAlign,
      style: OwTextStyles.mono.copyWith(color: color).merge(style),
    );
  }
}
