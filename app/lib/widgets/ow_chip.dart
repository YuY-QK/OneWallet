import 'package:flutter/material.dart';

import '../theme/ow_colors.dart';
import '../theme/ow_metrics.dart';
import '../theme/ow_text_styles.dart';

/// 选择标签：用于多选或单选的小标签（链选择、备份状态初始值）。
///
/// 选中时 `brand` 边框、`brandSoft` 底、`brand` 文字，并带对勾图标（[Icons.check]）——
/// 选中状态不只靠颜色表达。[onTap] 为空时不可点击（只展示）。
/// 可点击区域不小于 44 高；需要放在 [Material] 之上。
class OwChip extends StatelessWidget {
  const OwChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
  });

  /// 文字。
  final String label;

  /// 是否选中。
  final bool selected;

  /// 点击回调；为空表示不可点击。
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ow;
    final border = selected ? c.brand : c.line;
    final chip = DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? c.brandSoft : c.surface,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(OwMetrics.smallRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (selected) ...[
              Icon(Icons.check, size: 14, color: c.brand),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: OwTextStyles.caption.copyWith(
                color: selected ? c.brand : c.ink,
                fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
    if (onTap == null) return chip;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(OwMetrics.smallRadius),
        hoverColor: c.brandSoft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: OwMetrics.minTapSize),
          child: Center(widthFactor: 1, child: chip),
        ),
      ),
    );
  }
}
