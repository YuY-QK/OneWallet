import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../../bootstrap/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../../router/route_names.dart';
import '../../../shell/list_detail_layout.dart';
import '../../../theme/ow_colors.dart';
import '../../../theme/ow_text_styles.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/formatters.dart';
import '../../../widgets/ow_amount_text.dart';
import '../../../widgets/ow_avatar.dart';
import '../../../widgets/ow_input_decoration.dart';
import '../../../widgets/ow_list_group.dart';
import '../../../widgets/ow_pill.dart';
import '../../../widgets/ow_row.dart';
import '../../../widgets/ow_segmented.dart';
import '../../shared/labels.dart';
import '../controllers/accounts_list_controller.dart';

enum _AccountTab { accounts, addresses }

/// P03 账户列表。[detail] 是并排显示的账户详情（P07/P08）：窄屏时它替换列表
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

/// P03 的列表栏：顶部分段控件、分组列表、排序与右上角"+"、空状态。
class AccountsListPane extends ConsumerWidget {
  const AccountsListPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final data = ref.watch(accountsListProvider);
    final sortOrder = ref.watch(accountSortOrderProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.tabAccounts),
        actions: [
          PopupMenuButton<AccountSortOrder>(
            key: const ValueKey('accounts-sort-button'),
            tooltip: l.accountsSort,
            icon: const Icon(Icons.sort_rounded),
            onSelected: (order) {
              ref.read(accountSortOrderProvider.notifier).setOrder(order);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: AccountSortOrder.valuation,
                child: Row(
                  children: [
                    if (sortOrder == AccountSortOrder.valuation)
                      const Icon(Icons.check_rounded, size: 18)
                    else
                      const SizedBox(width: 18),
                    const SizedBox(width: 8),
                    Text(l.accountsSortByValuation),
                  ],
                ),
              ),
              PopupMenuItem(
                value: AccountSortOrder.name,
                child: Row(
                  children: [
                    if (sortOrder == AccountSortOrder.name)
                      const Icon(Icons.check_rounded, size: 18)
                    else
                      const SizedBox(width: 18),
                    const SizedBox(width: 8),
                    Text(l.accountsSortByName),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            tooltip: l.accountsAdd,
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.goNamed(RouteNames.accountAdd),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: OwSegmented<_AccountTab>(
              segments: [
                OwSegment(
                  value: _AccountTab.accounts,
                  label: l.accountsTabAccounts,
                ),
                OwSegment(
                  value: _AccountTab.addresses,
                  label: l.accountsTabAddressBook,
                ),
              ],
              value: _AccountTab.accounts,
              onChanged: (tab) {
                if (tab == _AccountTab.addresses) {
                  context.goNamed(RouteNames.addressBook);
                }
              },
            ),
          ),
          Expanded(
            child: switch (data) {
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
          ),
        ],
      ),
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
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Center(
            child: Text(
              l.accountsFooterHint,
              style: OwTextStyles.caption.copyWith(color: context.ow.muted),
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountRow extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final a = data.account;
    final isWallet = a.type == AccountType.wallet;
    final source = isWallet
        ? walletSourceLabel(l, a.walletSource, walletSourceId: a.walletSourceId)
        : (a.exchange == null ? null : exchangeLabel(l, a.exchange!));

    final (backupText, backupTone) = isWallet
        ? backupLabel(l, a.backupLevel)
        : (null, null);

    void showActions() =>
        _showAccountActionSheet(context, account: a, ref: ref);

    return OwRow(
      avatar: OwAvatar(
        label: avatarMark(a.name),
        shape: isWallet ? OwAvatarShape.circle : OwAvatarShape.roundedSquare,
      ),
      title: a.name,
      subtitle: source,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
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
                    style: OwTextStyles.caption.copyWith(
                      color: context.ow.muted,
                    ),
                  ),
                )
              else if (data.syncFailed)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: OwPill(
                    label: l.accountsSyncFailed,
                    tone: OwPillTone.red,
                  ),
                )
              else if (isWallet && backupText != null && backupTone != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: OwPill(label: backupText, tone: backupTone),
                ),
            ],
          ),
          const SizedBox(width: 4),
          IconButton(
            key: ValueKey('account-more-${a.id}'),
            icon: const Icon(Icons.more_vert_rounded, size: 20),
            tooltip: l.accountsMoreActions,
            onPressed: showActions,
          ),
        ],
      ),
      onTap: () => context.goNamed(
        isWallet ? RouteNames.walletDetail : RouteNames.exchangeDetail,
        pathParameters: {'id': a.id},
      ),
      onLongPress: showActions,
      onSecondaryTap: showActions,
    );
  }
}

Future<void> _showAccountActionSheet(
  BuildContext context, {
  required Account account,
  required WidgetRef ref,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (sheetContext) {
    final l = AppLocalizations.of(context)!;
    final isWallet = account.type == AccountType.wallet;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  OwAvatar(
                    label: avatarMark(account.name),
                    shape: isWallet
                        ? OwAvatarShape.circle
                        : OwAvatarShape.roundedSquare,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      account.name,
                      style: OwTextStyles.title.copyWith(color: context.ow.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l.accountsMenuRename),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _showRenameDialog(context, account: account, ref: ref);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline_rounded,
                color: context.ow.down,
              ),
              title: Text(
                l.accountsMenuDelete,
                style: TextStyle(color: context.ow.down),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _showDeleteDialog(context, account: account, ref: ref);
              },
            ),
          ],
        ),
      ),
    );
  },
);

Future<void> _showRenameDialog(
  BuildContext context, {
  required Account account,
  required WidgetRef ref,
}) async {
  final l = AppLocalizations.of(context)!;
  final controller = TextEditingController(text: account.name);
  String? errorText;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) {
        Future<void> submit() async {
          final trimmed = controller.text.trim();
          final length = trimmed.runes.length;
          if (length == 0 || length > maxAccountNameLength) {
            setState(() {
              errorText = l.accountsRenameHint;
            });
            return;
          }
          final res = await ref
              .read(accountsListActionsProvider)
              .rename(accountId: account.id, newName: trimmed);
          switch (res) {
            case Ok():
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            case Err(:final failure):
              setState(() {
                errorText = failure is ValidationFailure
                    ? (failure.detail ?? l.accountsRenameHint)
                    : failure.toString();
              });
          }
        }

        return AlertDialog(
          title: Text(l.accountsRenameTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(maxAccountNameLength),
                ],
                style: OwTextStyles.body.copyWith(color: context.ow.ink),
                decoration: owInputDecoration(
                  context,
                  hint: l.accountsRenameHint,
                  error: errorText != null,
                ),
                onSubmitted: (_) => submit(),
              ),
              if (errorText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    errorText!,
                    style: OwTextStyles.caption.copyWith(
                      color: context.ow.down,
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l.accountsRenameCancel),
            ),
            TextButton(onPressed: submit, child: Text(l.accountsRenameSave)),
          ],
        );
      },
    ),
  );
}

Future<void> _showDeleteDialog(
  BuildContext context, {
  required Account account,
  required WidgetRef ref,
}) async {
  final l = AppLocalizations.of(context)!;
  final isWallet = account.type == AccountType.wallet;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        isWallet ? l.accountsDeleteWalletTitle : l.accountsDeleteExchangeTitle,
      ),
      content: Text(
        isWallet
            ? l.accountsDeleteWalletMessage
            : l.accountsDeleteExchangeMessage,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l.accountsDeleteCancelAction),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text(l.accountsDeleteConfirmAction),
        ),
      ],
    ),
  );

  if (confirmed == true && context.mounted) {
    await ref.read(accountsListActionsProvider).delete(account.id);
    if (context.mounted) {
      context.go(AppRoutes.accounts);
    }
  }
}
