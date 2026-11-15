import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/ow_colors.dart';
import '../../../../theme/ow_metrics.dart';
import '../../../../theme/ow_text_styles.dart';
import '../../../../widgets/formatters.dart';
import '../../../../widgets/ow_amount_text.dart';
import '../../../../widgets/ow_avatar.dart';
import '../../../shared/labels.dart';
import '../../controllers/exchange_detail_view.dart';

/// P08 子账户分段的一行：按子账户汇总，点击展开子账户内币种明细。
class ExchangeSubAccountRowTile extends StatefulWidget {
  const ExchangeSubAccountRowTile({
    super.key,
    required this.row,
    required this.quote,
    required this.hidden,
  });

  final ExchangeSubAccountRow row;
  final Quote quote;
  final bool hidden;

  @override
  State<ExchangeSubAccountRowTile> createState() =>
      _ExchangeSubAccountRowTileState();
}

class _ExchangeSubAccountRowTileState extends State<ExchangeSubAccountRowTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.ow;
    final row = widget.row;
    final value = row.value ?? Decimal.zero;
    final label = subAccountLabel(l, row.sub);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _expanded,
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            hoverColor: c.brandSoft,
            focusColor: c.brandSoft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: OwMetrics.rowMinHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    OwAvatar(
                      label: label.substring(0, 1),
                      shape: OwAvatarShape.roundedSquare,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: OwTextStyles.rowTitle.copyWith(color: c.ink),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OwAmountText(
                      formatFiat(value, symbol: fiatSymbol(widget.quote)),
                      hidden: widget.hidden,
                    ),
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: c.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_expanded)
          for (final a in row.assets)
            Padding(
              padding: const EdgeInsets.fromLTRB(54, 0, 14, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            a.symbol,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: OwTextStyles.body.copyWith(color: c.ink),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: OwAmountText(
                            formatQuantity(a.amount),
                            hidden: widget.hidden,
                            tone: OwAmountTone.muted,
                            style: OwTextStyles.caption,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OwAmountText(
                    a.value == null
                        ? '—'
                        : formatFiat(
                            a.value!,
                            symbol: fiatSymbol(widget.quote),
                          ),
                    hidden: widget.hidden && a.value != null,
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
