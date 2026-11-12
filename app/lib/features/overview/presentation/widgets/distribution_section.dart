import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../router/route_names.dart';
import '../../../../theme/ow_colors.dart';
import '../../../../theme/ow_text_styles.dart';
import '../../../../widgets/formatters.dart';
import '../../../../widgets/ow_avatar.dart';
import '../../../../widgets/ow_list_group.dart';
import '../../../../widgets/ow_segmented.dart';
import '../../../shared/labels.dart';
import 'distribution_row.dart';

/// 分布的三种切换。
enum DistributionMode { coin, account, type }

/// P02 的分布切换、分布列表与底部统计行。
class DistributionSection extends StatefulWidget {
  const DistributionSection({
    super.key,
    required this.summary,
    required this.accounts,
    required this.quote,
    required this.hidden,
  });

  final PortfolioSummary summary;
  final List<Account> accounts;
  final Quote quote;
  final bool hidden;

  @override
  State<DistributionSection> createState() => _DistributionSectionState();
}

class _DistributionSectionState extends State<DistributionSection> {
  DistributionMode _mode = DistributionMode.coin;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final rows = _rows(context, l);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OwSegmented<DistributionMode>(
          segments: [
            OwSegment(value: DistributionMode.coin, label: l.overviewDistCoin),
            OwSegment(
              value: DistributionMode.account,
              label: l.overviewDistAccount,
            ),
            OwSegment(value: DistributionMode.type, label: l.overviewDistType),
          ],
          value: _mode,
          onChanged: (m) => setState(() => _mode = m),
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              l.overviewDistEmpty,
              textAlign: TextAlign.center,
              style: OwTextStyles.body.copyWith(color: context.ow.muted),
            ),
          )
        else
          OwListGroup(children: rows),
        _footer(context, l),
      ],
    );
  }

  List<Widget> _rows(BuildContext context, AppLocalizations l) {
    final s = widget.summary;
    final symbol = fiatSymbol(widget.quote);
    switch (_mode) {
      case DistributionMode.coin:
        return [
          for (final a in s.byAsset)
            DistributionRow(
              key: ValueKey('coin-${a.assetId}'),
              mark: a.displaySymbol,
              title: a.displaySymbol,
              quantity: a.amount,
              value: a.value,
              share: shareOf(a.value, s.total),
              symbol: symbol,
              hidden: widget.hidden,
              onTap: () => context.pushNamed(
                RouteNames.assetDetail,
                pathParameters: {'assetId': a.assetId},
              ),
            ),
        ];
      case DistributionMode.account:
        final byId = {for (final a in widget.accounts) a.id: a};
        return [
          for (final slice in s.byAccount)
            if (byId[slice.accountId] case final account?)
              DistributionRow(
                key: ValueKey('account-${account.id}'),
                mark: avatarMark(account.name),
                title: account.name,
                shape: account.type == AccountType.exchange
                    ? OwAvatarShape.roundedSquare
                    : OwAvatarShape.circle,
                value: slice.value,
                share: shareOf(slice.value, s.total),
                symbol: symbol,
                hidden: widget.hidden,
                onTap: () => _openAccount(context, account),
              ),
        ];
      case DistributionMode.type:
        if (s.total.sign == 0 && s.byAccount.isEmpty) return const [];
        return [
          DistributionRow(
            mark: '链',
            title: l.overviewTypeOnChain,
            value: s.onChainTotal,
            share: shareOf(s.onChainTotal, s.total),
            symbol: symbol,
            hidden: widget.hidden,
          ),
          DistributionRow(
            mark: '所',
            title: l.overviewTypeExchange,
            shape: OwAvatarShape.roundedSquare,
            value: s.exchangeTotal,
            share: shareOf(s.exchangeTotal, s.total),
            symbol: symbol,
            hidden: widget.hidden,
          ),
        ];
    }
  }

  /// 账户行：钱包进 P07，交易所进 P08（目前是说明页）。
  void _openAccount(BuildContext context, Account account) {
    if (account.type == AccountType.wallet) {
      context.goNamed(
        RouteNames.walletDetail,
        pathParameters: {'id': account.id},
      );
    } else {
      context.goNamed(
        RouteNames.exchangeDetail,
        pathParameters: {'id': account.id},
      );
    }
  }

  Widget _footer(BuildContext context, AppLocalizations l) {
    final s = widget.summary;
    final parts = [
      if (s.unpricedCount > 0) l.overviewFooterUnpriced(s.unpricedCount),
      if (s.hiddenSmallCount > 0) l.overviewFooterHidden(s.hiddenSmallCount),
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        parts.join(' · '),
        textAlign: TextAlign.center,
        style: OwTextStyles.caption.copyWith(color: context.ow.muted),
      ),
    );
  }
}
