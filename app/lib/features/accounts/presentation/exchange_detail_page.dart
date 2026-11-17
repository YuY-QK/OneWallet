import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ow_directory/ow_directory.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../../bootstrap/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../router/route_names.dart';
import '../../../theme/ow_colors.dart';
import '../../../theme/ow_text_styles.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/failure_text.dart';
import '../../../widgets/formatters.dart';
import '../../../widgets/ow_amount_text.dart';
import '../../../widgets/ow_avatar.dart';
import '../../../widgets/ow_card.dart';
import '../../../widgets/ow_danger_button.dart';
import '../../../widgets/ow_external_link.dart';
import '../../../widgets/ow_list_group.dart';
import '../../../widgets/ow_notice.dart';
import '../../../widgets/ow_pill.dart';
import '../../../widgets/ow_row.dart';
import '../../../widgets/ow_secondary_button.dart';
import '../../../widgets/ow_segmented.dart';
import '../../../widgets/ow_skeleton.dart';
import '../../shared/labels.dart';
import '../../shared/sync_failure.dart';
import '../controllers/exchange_detail_controller.dart';
import '../controllers/exchange_detail_view.dart';
import 'widgets/exchange_asset_row.dart';
import 'widgets/exchange_sub_account_row.dart';

enum _Tab { assets, subAccounts }

/// P08 交易所账户详情：摘要卡片、按币种与按子账户分段、充值地址区、更换 Key 与删除账户。
class ExchangeDetailPage extends ConsumerStatefulWidget {
  const ExchangeDetailPage({super.key, required this.accountId});

  final String accountId;

  @override
  ConsumerState<ExchangeDetailPage> createState() => _ExchangeDetailPageState();
}

class _ExchangeDetailPageState extends ConsumerState<ExchangeDetailPage> {
  _Tab _tab = _Tab.assets;
  bool _showUnpriced = false;
  bool _showDepositAddresses = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref
            .read(exchangeDetailActionsProvider(widget.accountId))
            .syncIfNeverSynced(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final view = ref.watch(exchangeDetailViewProvider(widget.accountId));
    final account = view.value?.account;

    return Scaffold(
      appBar: AppBar(title: Text(account?.name ?? l.tabAccounts)),
      body: switch (view) {
        AsyncData(value: null) => EmptyState(
          icon: Icons.account_balance_outlined,
          title: l.tabAccounts,
          body: l.exchangeDetailNotFound,
        ),
        AsyncData(:final value?)
            when value.status == ExchangeDetailStatus.loading =>
          const OwSkeleton(),
        AsyncData(:final value?) => _content(context, l, value),
        AsyncError() => EmptyState(
          icon: Icons.error_outline_rounded,
          title: l.tabAccounts,
          body: l.accountsLoadFailed,
        ),
        _ => const OwSkeleton(),
      },
    );
  }

  Widget _content(
    BuildContext context,
    AppLocalizations l,
    ExchangeDetailView v,
  ) {
    final quote = ref.watch(quoteProvider);
    final hidden = ref.watch(hideAmountsProvider);
    final now = ref.watch(clockProvider).nowUtc();

    return RefreshIndicator(
      onRefresh: ref
          .read(exchangeDetailActionsProvider(widget.accountId))
          .refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        children: [
          if (v.apiKeyStatus == ApiKeyStatus.expired) ...[
            OwNotice(
              tone: OwNoticeTone.error,
              message: l.exchangeDetailKeyExpiredNotice,
              onTap: () => context.pushNamed(
                RouteNames.exchangeAdd,
                queryParameters: {'accountId': widget.accountId},
              ),
            ),
            const SizedBox(height: 12),
          ] else if (v.failure != null) ...[
            _failureNotice(l, v, now),
            const SizedBox(height: 12),
          ],
          OwCard(
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.exchangeDetailTotal,
                    style: OwTextStyles.caption.copyWith(
                      color: context.ow.muted,
                    ),
                  ),
                  OwAmountText(
                    formatFiat(v.total, symbol: fiatSymbol(quote)),
                    hidden: hidden,
                    style: OwTextStyles.display,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (v.apiKeyStatus == ApiKeyStatus.expired)
                        OwPill(
                          label: l.exchangeDetailKeyStatusExpired,
                          tone: OwPillTone.red,
                        )
                      else
                        OwPill(
                          label: l.exchangeDetailKeyStatusNormal,
                          tone: OwPillTone.green,
                        ),
                      if (v.account.exchange != null)
                        () {
                          final exId = v.account.exchange!;
                          final label = exchangeLabel(l, exId);
                          final entry = ThirdPartyDirectory.builtin().byId(
                            exId.name,
                          );
                          final website = entry?.link(LinkKind.website);
                          final websiteUrl = website != null
                              ? Uri.tryParse(website)
                              : null;
                          if (websiteUrl != null) {
                            return OwExternalLink(
                              url: websiteUrl,
                              label: label,
                              showHost: false,
                            );
                          }
                          return Text(
                            label,
                            style: OwTextStyles.caption.copyWith(
                              color: context.ow.muted,
                            ),
                          );
                        }(),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (v.notIncluded.isNotEmpty) ...[
            const SizedBox(height: 12),
            OwNotice(
              tone: OwNoticeTone.info,
              message: l.exchangeDetailNotIncluded(v.notIncluded.join('、')),
            ),
          ],
          const SizedBox(height: 12),
          OwSegmented<_Tab>(
            segments: [
              OwSegment(value: _Tab.assets, label: l.exchangeDetailTabAssets),
              OwSegment(
                value: _Tab.subAccounts,
                label: l.exchangeDetailTabSubAccounts,
              ),
            ],
            value: _tab,
            onChanged: (t) => setState(() => _tab = t),
          ),
          const SizedBox(height: 12),
          if (_tab == _Tab.assets)
            ..._assets(context, l, v, quote, hidden)
          else
            ..._subAccounts(context, l, v, quote, hidden),
          const SizedBox(height: 12),
          _depositAddressCard(context, l, v),
          const SizedBox(height: 20),
          OwSecondaryButton(
            label: l.exchangeDetailReplaceKey,
            onPressed: () => context.pushNamed(
              RouteNames.exchangeAdd,
              queryParameters: {'accountId': widget.accountId},
            ),
          ),
          const SizedBox(height: 10),
          OwDangerButton(
            label: l.exchangeDetailDeleteAccount,
            onPressed: () => _confirmDelete(context, l),
          ),
        ],
      ),
    );
  }

  Widget _failureNotice(
    AppLocalizations l,
    ExchangeDetailView v,
    DateTime now,
  ) {
    final reason = failureText(l, failureFromTypeName(v.failure!.failureType));
    final last = v.lastSuccessAt;
    final lastText = last == null
        ? l.exchangeDetailNeverSucceeded
        : l.exchangeDetailLastSuccess(
            formatRelativeTime(last, now: now, l10n: l),
          );
    return OwNotice(
      tone: OwNoticeTone.error,
      message: '${l.exchangeDetailFailedTitle}：$reason $lastText',
    );
  }

  List<Widget> _assets(
    BuildContext context,
    AppLocalizations l,
    ExchangeDetailView v,
    Quote quote,
    bool hidden,
  ) {
    if (v.priced.isEmpty && v.unpriced.isEmpty) {
      if (v.failure != null) return const [];
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text(
            l.exchangeDetailNoAssets,
            textAlign: TextAlign.center,
            style: OwTextStyles.body.copyWith(color: context.ow.muted),
          ),
        ),
      ];
    }
    Widget tile(ExchangeAssetRow r) => ExchangeAssetRowTile(
      key: ValueKey(r.key),
      row: r,
      quote: quote,
      hidden: hidden,
    );
    return [
      if (v.priced.isNotEmpty)
        OwListGroup(children: [for (final r in v.priced) tile(r)]),
      if (v.unpriced.isNotEmpty) ...[
        const SizedBox(height: 12),
        OwListGroup(
          children: [
            OwRow(
              title: l.exchangeDetailUnpriced(v.unpriced.length),
              trailing: Icon(
                _showUnpriced
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
              ),
              onTap: () => setState(() => _showUnpriced = !_showUnpriced),
            ),
            if (_showUnpriced)
              for (final r in v.unpriced) tile(r),
          ],
        ),
      ],
    ];
  }

  List<Widget> _subAccounts(
    BuildContext context,
    AppLocalizations l,
    ExchangeDetailView v,
    Quote quote,
    bool hidden,
  ) {
    if (v.subAccounts.isEmpty) {
      if (v.failure != null) return const [];
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text(
            l.exchangeDetailNoAssets,
            textAlign: TextAlign.center,
            style: OwTextStyles.body.copyWith(color: context.ow.muted),
          ),
        ),
      ];
    }
    return [
      OwListGroup(
        children: [
          for (final row in v.subAccounts)
            ExchangeSubAccountRowTile(
              key: ValueKey(row.sub),
              row: row,
              quote: quote,
              hidden: hidden,
            ),
        ],
      ),
    ];
  }

  Widget _depositAddressCard(
    BuildContext context,
    AppLocalizations l,
    ExchangeDetailView v,
  ) {
    final c = context.ow;
    return OwListGroup(
      children: [
        OwRow(
          avatar: const OwAvatar(
            label: '充',
            shape: OwAvatarShape.roundedSquare,
          ),
          title: l.exchangeDetailDepositAddressesTitle,
          subtitle: l.exchangeDetailDepositAddressesSubtitle,
          trailing: Icon(
            _showDepositAddresses
                ? Icons.expand_less_rounded
                : Icons.expand_more_rounded,
            color: c.muted,
          ),
          onTap: () =>
              setState(() => _showDepositAddresses = !_showDepositAddresses),
        ),
        if (_showDepositAddresses) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: OwNotice(
              tone: OwNoticeTone.info,
              message: l.exchangeDetailDepositAddressesNotice,
            ),
          ),
          if (v.depositAddresses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                l.exchangeDetailDepositAddressesEmpty,
                textAlign: TextAlign.center,
                style: OwTextStyles.caption.copyWith(color: c.muted),
              ),
            )
          else
            for (final d in v.depositAddresses)
              OwRow(
                title: '${d.symbol} (${d.network})',
                subtitle: d.memo != null
                    ? '${d.address}\n${l.exchangeDetailDepositAddressMemo(d.memo!)}'
                    : d.address,
                trailing: IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: () => ref.read(clipboardWriterProvider)(d.address),
                ),
              ),
        ],
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, AppLocalizations l) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.exchangeDetailDeleteConfirmTitle),
        content: Text(l.exchangeDetailDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.exchangeDetailDeleteCancelAction),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l.exchangeDetailDeleteConfirmAction),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref
          .read(exchangeDetailActionsProvider(widget.accountId))
          .deleteAccount();
      if (mounted) {
        context.pop();
      }
    }
  }
}
