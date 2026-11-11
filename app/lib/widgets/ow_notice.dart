import 'package:flutter/material.dart';

import '../theme/ow_colors.dart';
import '../theme/ow_metrics.dart';
import '../theme/ow_text_styles.dart';

/// 提醒条的类型。
enum OwNoticeTone {
  /// 橙色浅底：需要注意。
  warn,

  /// 红色浅底：出错或危险。
  error,

  /// `brandSoft` 底：一般信息。
  info,
}

/// 提醒条：浅底圆角条，左侧一个图标，中间是说明文字。
///
/// 图标和文字一起表达类型，不只靠颜色。给了 [onTap] 时整行可点击，
/// 右侧出现箭头，并以"按钮"的语义暴露给读屏软件。
/// 需要放在 [Material] 之上（`Scaffold` 与 [OwCard] 都提供）。
class OwNotice extends StatelessWidget {
  const OwNotice({
    super.key,
    required this.message,
    this.tone = OwNoticeTone.warn,
    this.onTap,
  });

  /// 说明文字。
  final String message;

  /// 类型，默认 [OwNoticeTone.warn]。
  final OwNoticeTone tone;

  /// 点击回调。为空时不可点击，也不显示箭头。
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ow;
    final (bg, fg, icon) = switch (tone) {
      OwNoticeTone.warn => (c.warnSoft, c.warn, Icons.warning_amber_rounded),
      OwNoticeTone.error => (c.downSoft, c.down, Icons.error_outline_rounded),
      OwNoticeTone.info => (c.brandSoft, c.ink, Icons.info_outline_rounded),
    };
    const shape = RoundedRectangleBorder(
      borderRadius: OwMetrics.cardBorderRadius,
    );

    final body = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: OwMetrics.minTapSize),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: OwTextStyles.caption.copyWith(color: fg),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, size: 20, color: fg),
            ],
          ],
        ),
      ),
    );

    return Material(
      color: bg,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? body
          : Semantics(
              button: true,
              child: InkWell(
                onTap: onTap,
                hoverColor: fg.withValues(alpha: 0.08),
                focusColor: fg.withValues(alpha: 0.12),
                child: body,
              ),
            ),
    );
  }
}
