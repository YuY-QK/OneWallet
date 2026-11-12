import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../../bootstrap/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../router/route_names.dart';
import '../../../theme/ow_colors.dart';
import '../../../theme/ow_text_styles.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/formatters.dart';
import '../../../widgets/ow_amount_text.dart';
import '../../../widgets/ow_avatar.dart';
import '../../../widgets/ow_card.dart';
import '../../../widgets/ow_list_group.dart';
import '../../../widgets/ow_notice.dart';
import '../../../widgets/ow_pill.dart';
import '../../../widgets/ow_row.dart';
import '../../../widgets/ow_secondary_button.dart';
import '../../../widgets/ow_segmented.dart';
import '../../../widgets/ow_skeleton.dart';
import '../../shared/labels.dart';
import '../../shared/sync_failure.dart';
import '../controllers/wallet_detail_controller.dart';
import '../controllers/wallet_detail_view.dart';
import 'widgets/address_sheet.dart';
import 'widgets/wallet_asset_row.dart';

enum _Tab { assets, addresses }

/// P07 钱包账户详情基础版：摘要、资产与地址两个分段、地址操作面板。
class WalletDetailPage extends ConsumerStatefulWidget {
  const WalletDetailPage({super.key, required this.accountId});

  final String accountId;

  @override
  ConsumerState<WalletDetailPage> createState() => _WalletDetailPageState();
}

class _WalletDetailPageState extends ConsumerState<WalletDetailPage> {
  _Tab _tab = _Tab.assets;
  bool _showUnpriced = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref
            .read(walletDetailActionsProvider(widget.accountId))
            .syncIfNeverSynced(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final view = ref.watch(walletDetailViewProvider(widget.accountId));
    final account = view.value?.account;
    return Scaffold(
      appBar: AppBar(title: Text(account?.name ?? l.tabAccounts)),
      body: switch (view) {
        AsyncData(value: null) => EmptyState(
          icon: Icons.account_balance_wallet_outlined,
          title: l.tabAccounts,
          body: l.walletDetailNotFound,
        ),
        AsyncData(:final value?)
            when value.status == WalletDetailStatus.loading =>
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
    WalletDetailView v,
  ) {
    final quote = ref.watch(quoteProvider);
    final hidden = ref.watch(hideAmountsProvider);
    final now = ref.watch(clockProvider).nowUtc();
    final (backupText, backupTone) = backupLabel(l, v.account.backupLevel);
    return RefreshIndicator(
      onRefresh: ref
          .read(walletDetailActionsProvider(widget.accountId))
          .refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        children: [
          if (v.failure != null) ...[
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
                    l.walletDetailTotal,
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
                  // 备份状态在本任务只读；操作面板属于 M3-06。
                  OwPill(label: backupText, tone: backupTone),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          OwSegmented<_Tab>(
            segments: [
              OwSegment(value: _Tab.assets, label: l.walletDetailTabAssets),
              OwSegment(
                value: _Tab.addresses,
                label: l.walletDetailTabAddresses,
              ),
            ],
            value: _tab,
            onChanged: (t) => setState(() => _tab = t),
          ),
          const SizedBox(height: 12),
          if (_tab == _Tab.assets)
            ..._assets(context, l, v, quote, hidden)
          else
            ..._addresses(context, l, v, quote, hidden),
        ],
      ),
    );
  }

  Widget _failureNotice(AppLocalizations l, WalletDetailView v, DateTime now) {
    final reason = syncFailureText(
      l,
      failureFromTypeName(v.failure!.failureType),
    );
    final last = v.lastSuccessAt;
    final lastText = last == null
        ? l.walletDetailNeverSucceeded
        : l.walletDetailLastSuccess(
            formatRelativeTime(last, now: now, l10n: l),
          );
    return OwNotice(
      tone: OwNoticeTone.error,
      message: '${l.walletDetailFailedTitle}：$reason $lastText',
    );
  }

  List<Widget> _assets(
    BuildContext context,
    AppLocalizations l,
    WalletDetailView v,
    Quote quote,
    bool hidden,
  ) {
    if (v.priced.isEmpty && v.unpriced.isEmpty) {
      // 同步失败时顶部已有说明，不再重复"没有资产"。
      if (v.failure != null) return const [];
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text(
            l.walletDetailNoAssets,
            textAlign: TextAlign.center,
            style: OwTextStyles.body.copyWith(color: context.ow.muted),
          ),
        ),
      ];
    }
    Widget tile(WalletAssetRow r) => WalletAssetRowTile(
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
              title: l.walletDetailUnpriced(v.unpriced.length),
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

  List<Widget> _addresses(
    BuildContext context,
    AppLocalizations l,
    WalletDetailView v,
    Quote quote,
    bool hidden,
  ) {
    final codec = ref.read(addressCodecProvider);
    final canDelete = v.addresses.length > 1;
    final widgets = <Widget>[];
    ChainFamily? current;
    var group = <Widget>[];
    void flush() {
      if (current == null) return;
      widgets
        ..add(
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 6),
            child: Text(
              chainFamilyLabel(l, current),
              style: OwTextStyles.caption.copyWith(color: context.ow.muted),
            ),
          ),
        )
        ..add(OwListGroup(children: group))
        ..add(const SizedBox(height: 12));
      group = [];
    }

    for (final row in v.addresses) {
      final a = row.address;
      if (a.family != current) {
        flush();
        current = a.family;
      }
      final display = codec.display(a.address, a.family);
      group.add(
        OwRow(
          key: ValueKey(a.id),
          avatar: OwAvatar(label: _familyMark(a.family)),
          title: shortenAddress(display),
          monoTitle: true,
          subtitle: a.family == ChainFamily.evm
              ? l.walletDetailChainCount(a.enabledChainIds.length)
              : Chains.ofFamily(a.family).first.name,
          trailing: OwAmountText(
            formatFiat(row.value ?? Decimal.zero, symbol: fiatSymbol(quote)),
            hidden: hidden,
          ),
          onTap: () =>
              showAddressSheet(context, address: a, canDelete: canDelete),
        ),
      );
    }
    flush();
    return [
      ...widgets,
      OwSecondaryButton(
        label: l.walletDetailAddAddress,
        onPressed: () => context.pushNamed(
          RouteNames.walletAdd,
          queryParameters: {'accountId': widget.accountId},
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          l.walletDetailAddressesHint,
          textAlign: TextAlign.center,
          style: OwTextStyles.caption.copyWith(color: context.ow.muted),
        ),
      ),
    ];
  }

  String _familyMark(ChainFamily f) => switch (f) {
    ChainFamily.evm => 'EVM',
    ChainFamily.bitcoin => 'BTC',
    ChainFamily.solana => 'SOL',
    ChainFamily.tron => 'TRX',
  };
}
