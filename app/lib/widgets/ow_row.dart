import 'package:flutter/material.dart';

import '../theme/ow_colors.dart';
import '../theme/ow_metrics.dart';
import '../theme/ow_text_styles.dart';

/// 列表行：头像（可选）、标题与副标题、右侧内容（可选）。
///
/// 最小高度 54。有 [onTap] 时整行可点击，带悬停与键盘焦点样式（`brandSoft`
/// 底），并以"按钮"的语义暴露给读屏软件；没有 [onTap] 时是纯展示行。
/// 需要放在 [Material] 之上（[OwListGroup]、[OwCard] 与 `Scaffold` 都提供）。
class OwRow extends StatelessWidget {
  const OwRow({
    super.key,
    required this.title,
    this.avatar,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.monoTitle = false,
    this.monoSubtitle = false,
  });

  /// 标题，单行，过长时省略。
  final String title;

  /// 左侧头像，通常是 [OwAvatar]。
  final Widget? avatar;

  /// 副标题，单行，过长时省略。
  final String? subtitle;

  /// 右侧内容，如 [OwAmountText]、[OwPill]。右对齐，不会被压缩。
  final Widget? trailing;

  /// 点击回调。为空时该行不可点击。
  final VoidCallback? onTap;

  /// 标题用等宽字体（标题是地址时使用）。
  final bool monoTitle;

  /// 副标题用等宽字体（副标题是地址时使用）。
  final bool monoSubtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.ow;
    final titleBase = monoTitle ? OwTextStyles.mono : OwTextStyles.rowTitle;
    final subtitleBase = monoSubtitle
        ? OwTextStyles.mono.copyWith(fontSize: 12.5, height: 18 / 12.5)
        : OwTextStyles.caption;

    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: OwMetrics.rowMinHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            if (avatar != null) ...[avatar!, const SizedBox(width: 10)],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleBase.copyWith(color: c.ink),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: subtitleBase.copyWith(color: c.muted),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 10), trailing!],
          ],
        ),
      ),
    );

    if (onTap == null) return content;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        hoverColor: c.brandSoft,
        focusColor: c.brandSoft,
        splashColor: c.brandSoft,
        highlightColor: c.brandSoft,
        child: content,
      ),
    );
  }
}
