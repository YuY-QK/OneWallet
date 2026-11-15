import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/ow_colors.dart';
import '../../../theme/ow_text_styles.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/formatters.dart';
import '../../../widgets/ow_amount_text.dart';
import '../../../widgets/ow_card.dart';
import '../../../widgets/ow_list_group.dart';
import '../../../widgets/ow_skeleton.dart';
import '../controllers/asset_detail_controller.dart';
import '../controllers/asset_detail_view.dart';
import 'widgets/asset_contract_row.dart';
import 'widgets/asset_distribution_row.dart';

/// P09 币种详情页。
class AssetDetailPage extends ConsumerWidget {
  const AssetDetailPage({super.key, required this.assetId});

  final String assetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final viewAsync = ref.watch(assetDetailViewProvider(assetId));

    return Scaffold(
      appBar: AppBar(title: Text(viewAsync.value?.symbol ?? assetId)),
      body: switch (viewAsync) {
        AsyncData(:final value) => _content(context, ref, l, value),
        AsyncError() => EmptyState(
          icon: Icons.error_outline_rounded,
          title: l.assetDetailTitle,
          body: l.assetDetailNotFound,
        ),
        _ => const OwSkeleton(),
      },
    );
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    AssetDetailView v,
  ) {
    final quote = ref.watch(quoteProvider);
    final hidden = ref.watch(hideAmountsProvider);
    final symbol = fiatSymbol(quote);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      children: [
        OwCard(
          child: Column(
            children: [
              _priceRow(context, l, v, symbol),
              const SizedBox(height: 12),
              _kvRow(
                context,
                label: l.assetDetailHoldings,
                valueWidget: OwAmountText(
                  formatQuantity(v.totalAmount),
                  hidden: hidden,
                  style: OwTextStyles.mono,
                ),
              ),
              const SizedBox(height: 12),
              _kvRow(
                context,
                label: l.assetDetailValuation,
                valueWidget: v.totalValue != null
                    ? OwAmountText(
                        formatFiat(v.totalValue!, symbol: symbol),
                        hidden: hidden,
                        style: OwTextStyles.mono,
                      )
                    : Text(
                        '—',
                        style: OwTextStyles.mono.copyWith(
                          color: context.ow.muted,
                        ),
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 6),
          child: Text(
            l.assetDetailDistributionTitle,
            style: OwTextStyles.caption.copyWith(color: context.ow.muted),
          ),
        ),
        if (v.distributions.isEmpty)
          OwCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  l.assetDetailDistributionEmpty,
                  style: OwTextStyles.caption.copyWith(color: context.ow.muted),
                ),
              ),
            ),
          )
        else
          OwListGroup(
            children: [
              for (final item in v.distributions)
                AssetDistributionRowTile(
                  key: ValueKey('${item.account.id}-${item.location}'),
                  item: item,
                  quote: quote,
                  hidden: hidden,
                ),
            ],
          ),
        if (v.contracts.isNotEmpty) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 6),
            child: Text(
              l.assetDetailContractsTitle,
              style: OwTextStyles.caption.copyWith(color: context.ow.muted),
            ),
          ),
          OwListGroup(
            children: [
              for (final item in v.contracts)
                AssetContractRowTile(key: ValueKey(item.chainId), item: item),
            ],
          ),
        ],
      ],
    );
  }

  Widget _kvRow(
    BuildContext context, {
    required String label,
    required Widget valueWidget,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: OwTextStyles.caption.copyWith(color: context.ow.muted),
        ),
        valueWidget,
      ],
    );
  }

  Widget _priceRow(
    BuildContext context,
    AppLocalizations l,
    AssetDetailView v,
    String symbol,
  ) {
    final c = context.ow;
    final price = v.price;

    final Widget priceWidget;
    if (price != null) {
      final change = price.change24hPercent;
      final Color changeColor;
      if (change == null || change == Decimal.zero) {
        changeColor = c.muted;
      } else if (change > Decimal.zero) {
        changeColor = c.up;
      } else {
        changeColor = c.down;
      }

      priceWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatPrice(price.price, symbol: symbol),
            style: OwTextStyles.mono.copyWith(color: c.ink),
          ),
          if (change != null) ...[
            const SizedBox(width: 6),
            Text(
              formatPercent(change),
              style: OwTextStyles.caption.copyWith(
                color: changeColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      );
    } else {
      priceWidget = Text(
        '—',
        style: OwTextStyles.mono.copyWith(color: c.muted),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          l.assetDetailCurrentPrice,
          style: OwTextStyles.caption.copyWith(color: c.muted),
        ),
        priceWidget,
      ],
    );
  }
}
