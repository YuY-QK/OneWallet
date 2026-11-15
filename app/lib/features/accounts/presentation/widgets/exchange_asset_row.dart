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

/// P08 资产分段的一行：按币种汇总，点击展开各子账户明细。
class ExchangeAssetRowTile extends StatefulWidget {
  const ExchangeAssetRowTile({
    super.key,
    required this.row,
    required this.quote,
    required this.hidden,
  });

  final ExchangeAssetRow row;
  final Quote quote;
  final bool hidden;

  @override
  State<ExchangeAssetRowTile> createState() => _ExchangeAssetRowTileState();
}

class _ExchangeAssetRowTileState extends State<ExchangeAssetRowTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.ow;
    final row = widget.row;
    final value = row.value;
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
                    OwAvatar(label: row.symbol),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              row.symbol,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: OwTextStyles.rowTitle.copyWith(
                                color: c.ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: OwAmountText(
                              formatQuantity(row.amount),
                              hidden: widget.hidden,
                              tone: OwAmountTone.muted,
                              style: OwTextStyles.caption,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    OwAmountText(
                      value == null
                          ? '—'
                          : formatFiat(value, symbol: fiatSymbol(widget.quote)),
                      hidden: widget.hidden && value != null,
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
          for (final d in row.details)
            Padding(
              padding: const EdgeInsets.fromLTRB(54, 0, 14, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      subAccountLabel(l, d.sub),
                      style: OwTextStyles.caption.copyWith(color: c.muted),
                    ),
                  ),
                  OwAmountText(
                    formatQuantity(d.amount),
                    hidden: widget.hidden,
                    tone: OwAmountTone.muted,
                    style: OwTextStyles.caption,
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
