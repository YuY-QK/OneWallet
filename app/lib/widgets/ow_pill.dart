import 'package:flutter/material.dart';

import '../theme/ow_colors.dart';
import '../theme/ow_text_styles.dart';

/// 状态胶囊的语义。
enum OwPillTone {
  /// 绿：已入库、成功、已备份。
  green,

  /// 红：未备份、失败。
  red,

  /// 橙：需注意。
  orange,
}

/// 状态胶囊：对应语义的浅色底加深色字，全圆角。
///
/// 状态不能只靠颜色表达，所以 [label] 必填。
class OwPill extends StatelessWidget {
  const OwPill({super.key, required this.label, required this.tone});

  /// 状态文字。
  final String label;

  /// 语义色。
  final OwPillTone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.ow;
    final (bg, fg) = switch (tone) {
      OwPillTone.green => (c.upSoft, c.up),
      OwPillTone.red => (c.downSoft, c.down),
      OwPillTone.orange => (c.warnSoft, c.warn),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: OwTextStyles.label.copyWith(color: fg),
        ),
      ),
    );
  }
}
