import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../../theme/ow_colors.dart';
import '../../../../theme/ow_metrics.dart';
import '../../../../theme/ow_text_styles.dart';
import '../../../../widgets/formatters.dart';
import '../../../../widgets/ow_amount_text.dart';
import '../../../../widgets/ow_avatar.dart';
import '../../../../widgets/ow_share_bar.dart';

/// P02 分布列表的一行：图标、名称（可带数量）、占比条、估值与占比。
class DistributionRow extends StatelessWidget {
  const DistributionRow({
    super.key,
    required this.mark,
    required this.title,
    required this.value,
    required this.share,
    required this.symbol,
    required this.hidden,
    this.quantity,
    this.shape = OwAvatarShape.circle,
    this.onTap,
  });

  /// 头像标记（币种代码或名称首字）。
  final String mark;
  final String title;

  /// 已格式化前的数量；按币种分布时显示在名称后。
  final Decimal? quantity;
  final Decimal value;

  /// 占总额的百分数（0–100）。
  final Decimal share;
  final String symbol;
  final bool hidden;
  final OwAvatarShape shape;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ow;
    final percent = '${share.toStringAsFixed(1)}%';
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: OwMetrics.rowMinHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            OwAvatar(label: mark, shape: shape),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: OwTextStyles.rowTitle.copyWith(color: c.ink),
                        ),
                      ),
                      if (quantity != null) ...[
                        const SizedBox(width: 6),
                        OwAmountText(
                          formatQuantity(quantity!),
                          hidden: hidden,
                          tone: OwAmountTone.muted,
                          style: OwTextStyles.caption,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  OwShareBar(
                    fraction: share.toDouble() / 100,
                    semanticLabel: percent,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                OwAmountText(formatFiat(value, symbol: symbol), hidden: hidden),
                Text(
                  percent,
                  style: OwTextStyles.caption.copyWith(color: c.muted),
                ),
              ],
            ),
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
        child: content,
      ),
    );
  }
}
