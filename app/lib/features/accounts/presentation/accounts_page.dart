import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../../bootstrap/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../router/route_names.dart';
import '../../../shell/list_detail_layout.dart';
import '../../../theme/ow_colors.dart';
import '../../../theme/ow_text_styles.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/formatters.dart';
import '../../../widgets/ow_amount_text.dart';
import '../../../widgets/ow_avatar.dart';
import '../../../widgets/ow_list_group.dart';
import '../../../widgets/ow_pill.dart';
import '../../../widgets/ow_row.dart';
import '../../shared/labels.dart';
import '../controllers/accounts_list_controller.dart';

/// P03 账户列表。[detail] 是并排显示的账户详情（P07）：窄屏时它替换列表
/// （逐级进入），中屏和宽屏与列表并排。
class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key, this.detail});

  /// 当前选中的账户详情；为空表示未选中。
  final Widget? detail;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (!ListDetailLayout.showsDetailInline(context)) {
      return detail ?? const AccountsListPane();
    }
    return ListDetailLayout(
      list: const AccountsListPane(),
      detail: detail,
      placeholder: Scaffold(
        body: EmptyState(
          icon: Icons.account_balance_wallet_outlined,
          title: l.tabAccounts,
          body: l.accountsSelectHint,
        ),
      ),
    );
  }
}

/// P03 的列表栏：分组列表、右上角"+"、空状态。
class AccountsListPane extends ConsumerWidget {
  const AccountsListPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final data = ref.watch(accountsListProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.tabAccounts),
        actions: [
          IconButton(
            tooltip: l.accountsAdd,
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.goNamed(RouteNames.accountAdd),
          ),
        ],
      ),
      body: switch (data) {
        AsyncData(:final value) when value.isEmpty => EmptyState(
          icon: Icons.account_balance_wallet_outlined,
          title: l.accountsEmptyTitle,
          body: l.accountsEmptyBody,
          actionLabel: l.overviewEmptyAction,
          onAction: () => context.goNamed(RouteNames.accountAdd),
        ),
        AsyncData(:final value) => _List(data: value),
        AsyncError() => EmptyState(
          icon: Icons.error_outline_rounded,
          title: l.tabAccounts,
          body: l.accountsLoadFailed,
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

class _List extends ConsumerWidget {
  const _List({required this.data});

  final AccountsListData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final quote = ref.watch(quoteProvider);
    final hidden = ref.watch(hideAmountsProvider);
    Widget group(String title, List<AccountRowData> rows) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 4, 2, 6),
          child: Text(
            title,
            style: OwTextStyles.caption.copyWith(color: context.ow.muted),
          ),
        ),
        OwListGroup(
          children: [
            for (final r in rows)
              _AccountRow(
                key: ValueKey(r.account.id),
                data: r,
                quote: quote,
                hidden: hidden,
              ),
          ],
        ),
      ],
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      children: [
        if (data.wallets.isNotEmpty) group(l.accountsGroupWallet, data.wallets),
        if (data.wallets.isNotEmpty && data.exchanges.isNotEmpty)
          const SizedBox(height: 12),
        if (data.exchanges.isNotEmpty)
          group(l.accountsGroupExchange, data.exchanges),
      ],
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    super.key,
    required this.data,
    required this.quote,
    required this.hidden,
  });

  final AccountRowData data;
  final Quote quote;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final a = data.account;
    final isWallet = a.type == AccountType.wallet;
    final source = isWallet
        ? walletSourceLabel(l, a.walletSource)
        : (a.exchange == null ? null : exchangeLabel(l, a.exchange!));
    return OwRow(
      avatar: OwAvatar(
        label: avatarMark(a.name),
        shape: isWallet ? OwAvatarShape.circle : OwAvatarShape.roundedSquare,
      ),
      title: a.name,
      subtitle: source,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          OwAmountText(
            formatFiat(data.value, symbol: fiatSymbol(quote)),
            hidden: hidden,
          ),
          if (data.syncing)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                l.accountsSyncing,
                style: OwTextStyles.caption.copyWith(color: context.ow.muted),
              ),
            )
          else if (data.syncFailed)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: OwPill(label: l.accountsSyncFailed, tone: OwPillTone.red),
            ),
        ],
      ),
      onTap: () => context.goNamed(
        isWallet ? RouteNames.walletDetail : RouteNames.exchangeDetail,
        pathParameters: {'id': a.id},
      ),
    );
  }
}
