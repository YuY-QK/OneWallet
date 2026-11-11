import 'package:flutter/material.dart';

import '../theme/ow_colors.dart';
import '../theme/ow_metrics.dart';
import '../theme/ow_text_styles.dart';

/// [OwSegmented] 的一个选项。
@immutable
class OwSegment<T> {
  const OwSegment({required this.value, required this.label});

  /// 选项的值。
  final T value;

  /// 显示的文字。
  final String label;
}

/// 分段控件：`brandSoft` 底，选中项为 `surface` 底的小块。
///
/// 每个选项的可点击区域高 44，等宽排列。选中项在读屏软件里标记为"已选中"。
class OwSegmented<T> extends StatelessWidget {
  const OwSegmented({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
  });

  /// 全部选项，至少一个。
  final List<OwSegment<T>> segments;

  /// 当前选中的值。
  final T value;

  /// 选中另一个选项时回调；点击已选中项不回调。
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.ow;
    return Material(
      color: c.brandSoft,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(OwMetrics.inputRadius),
      child: Row(
        children: [
          for (final s in segments)
            Expanded(
              child: _Segment(
                label: s.label,
                selected: s.value == value,
                onTap: () {
                  if (s.value != value) onChanged(s.value);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ow;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        hoverColor: c.surface.withValues(alpha: 0.5),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: OwMetrics.minTapSize),
          // 3 像素的外边距算在可点击区域内，整体高度仍是 44。
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: selected ? c.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OwTextStyles.body.copyWith(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                      color: selected ? c.ink : c.muted,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
