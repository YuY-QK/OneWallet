import 'package:flutter/material.dart';

import '../theme/ow_colors.dart';
import '../theme/ow_text_styles.dart';
import 'formatters.dart';

/// 地址文字：等宽字体。默认缩略为前 6 后 4，[full] 为真时显示完整地址。
///
/// 完整地址允许换行。读屏软件始终读出完整地址，避免缩略后听不出差别。
class OwAddressText extends StatelessWidget {
  const OwAddressText(
    this.address, {
    super.key,
    this.full = false,
    this.style,
    this.textAlign,
  });

  /// 完整地址。
  final String address;

  /// 是否显示完整地址（详情面板用）。
  final bool full;

  /// 在等宽样式之上叠加的样式。
  final TextStyle? style;

  /// 对齐方式。
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final c = context.ow;
    final shown = full ? address : shortenAddress(address);
    return Semantics(
      label: address,
      excludeSemantics: true,
      child: Text(
        shown,
        textAlign: textAlign,
        maxLines: full ? null : 1,
        overflow: full ? TextOverflow.clip : TextOverflow.ellipsis,
        style: OwTextStyles.mono.copyWith(color: c.ink).merge(style),
      ),
    );
  }
}
