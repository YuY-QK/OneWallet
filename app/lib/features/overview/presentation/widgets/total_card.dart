import 'package:flutter/material.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/ow_colors.dart';
import '../../../../theme/ow_text_styles.dart';
import '../../../../widgets/formatters.dart';
import '../../../../widgets/ow_amount_text.dart';
import '../../../../widgets/ow_card.dart';

/// P02 总资产卡片：总估值、计价货币、24 小时变化、上次同步时间。
class OverviewTotalCard extends StatelessWidget {
  const OverviewTotalCard({
    super.key,
    required this.summary,
    required this.quote,
    required this.hidden,
    required this.lastSyncedAt,
    required this.now,
  });

  final PortfolioSummary summary;
  final Quote quote;
  final bool hidden;
  final DateTime? lastSyncedAt;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.ow;
    final synced = lastSyncedAt;
    return OwCard(
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.overviewTotalLabel(quoteCode(quote)),
              style: OwTextStyles.caption.copyWith(color: c.muted),
            ),
            OwAmountText(
              formatFiat(summary.total, symbol: fiatSymbol(quote)),
              hidden: hidden,
              style: OwTextStyles.display,
            ),
            _change(context, l),
            const SizedBox(height: 4),
            Text(
              synced == null
                  ? l.overviewNeverSynced
                  : l.overviewLastSynced(
                      formatRelativeTime(synced, now: now, l10n: l),
                    ),
              style: OwTextStyles.caption.copyWith(color: c.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _change(BuildContext context, AppLocalizations l) {
    final amount = summary.change24h;
    final percent = summary.change24hPercent;
    if (amount == null || percent == null) {
      return OwAmountText(
        l.overviewChangeUnknown,
        tone: OwAmountTone.muted,
        style: OwTextStyles.caption,
      );
    }
    final up = amount.sign >= 0;
    final text =
        '${up ? '▲' : '▼'} ${formatFiat(amount.abs(), symbol: fiatSymbol(quote))}'
        '（${formatPercent(percent)}）';
    return Row(
      children: [
        OwAmountText(
          text,
          hidden: hidden,
          tone: up ? OwAmountTone.up : OwAmountTone.down,
        ),
        const SizedBox(width: 6),
        Text(
          l.overviewChange24h,
          style: OwTextStyles.caption.copyWith(color: context.ow.muted),
        ),
      ],
    );
  }
}
