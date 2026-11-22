import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../../bootstrap/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../../router/route_names.dart';
import '../../../theme/ow_colors.dart';
import '../../../theme/ow_metrics.dart';
import '../../../theme/ow_text_styles.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/failure_text.dart';
import '../../../widgets/formatters.dart';
import '../../../widgets/ow_avatar.dart';
import '../../../widgets/ow_chip.dart';
import '../../../widgets/ow_input_decoration.dart';
import '../../../widgets/ow_list_group.dart';
import '../../../widgets/ow_notice.dart';
import '../../../widgets/ow_pill.dart';
import '../../../widgets/ow_row.dart';
import '../../../widgets/ow_segmented.dart';
import '../../../widgets/ow_skeleton.dart';
import '../controllers/address_book_controller.dart';
import 'widgets/address_sheet.dart';

enum _AccountTab { accounts, addresses }

/// P10 地址簿页面（PRD P10）。
class AddressBookPage extends ConsumerStatefulWidget {
  const AddressBookPage({super.key});

  @override
  ConsumerState<AddressBookPage> createState() => _AddressBookPageState();
}

class _AddressBookPageState extends ConsumerState<AddressBookPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _familyMark(ChainFamily f) => switch (f) {
    ChainFamily.evm => 'EVM',
    ChainFamily.bitcoin => 'BTC',
    ChainFamily.solana => 'SOL',
    ChainFamily.tron => 'TRX',
  };

  String _chainLabel(AppLocalizations l, WatchAddress a) {
    if (a.family == ChainFamily.evm) {
      return l.walletDetailChainCount(a.enabledChainIds.length);
    }
    return Chains.ofFamily(a.family).first.name;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.ow;
    final asyncState = ref.watch(addressBookProvider);
    final filter = ref.watch(addressBookFilterProvider);
    final filterController = ref.read(addressBookFilterProvider.notifier);
    final addressCodec = ref.watch(addressCodecProvider);

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
      body: SafeArea(
        child: Column(
          children: [
            // 1. 顶部分段：账户 | 地址簿
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
                value: _AccountTab.addresses,
                onChanged: (tab) {
                  if (tab == _AccountTab.accounts) {
                    context.go(AppRoutes.accounts);
                  }
                },
              ),
            ),

            // 2. 搜索框与筛选芯片
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Column(
                children: [
                  TextField(
                    key: const Key('address_book_search_field'),
                    controller: _searchController,
                    decoration: owInputDecoration(
                      context,
                      hint: l.addressBookSearchHint,
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                filterController.setQuery('');
                                setState(() {});
                              },
                            )
                          : null,
                    ),
                    onChanged: (val) {
                      filterController.setQuery(val);
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        OwChip(
                          label: l.addressBookChainAll,
                          selected: filter.family == null,
                          onTap: () => filterController.setFamily(null),
                        ),
                        const SizedBox(width: 6),
                        OwChip(
                          label: 'EVM',
                          selected: filter.family == ChainFamily.evm,
                          onTap: () =>
                              filterController.setFamily(ChainFamily.evm),
                        ),
                        const SizedBox(width: 6),
                        OwChip(
                          label: 'Bitcoin',
                          selected: filter.family == ChainFamily.bitcoin,
                          onTap: () =>
                              filterController.setFamily(ChainFamily.bitcoin),
                        ),
                        const SizedBox(width: 6),
                        OwChip(
                          label: 'Solana',
                          selected: filter.family == ChainFamily.solana,
                          onTap: () =>
                              filterController.setFamily(ChainFamily.solana),
                        ),
                        const SizedBox(width: 6),
                        OwChip(
                          label: 'Tron',
                          selected: filter.family == ChainFamily.tron,
                          onTap: () =>
                              filterController.setFamily(ChainFamily.tron),
                        ),
                        if (asyncState case AsyncData(:final value)
                            when value.walletAccounts.length > 1) ...[
                          const SizedBox(width: 12),
                          PopupMenuButton<String?>(
                            initialValue: filter.accountId,
                            tooltip: l.addressBookAccountAll,
                            onSelected: filterController.setAccountId,
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: null,
                                child: Text(l.addressBookAccountAll),
                              ),
                              for (final acc in value.walletAccounts)
                                PopupMenuItem(
                                  value: acc.id,
                                  child: Text(acc.name),
                                ),
                            ],
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: filter.accountId != null
                                    ? c.brandSoft
                                    : c.surface,
                                border: Border.all(
                                  color: filter.accountId != null
                                      ? c.brand
                                      : c.line,
                                ),
                                borderRadius: BorderRadius.circular(
                                  OwMetrics.smallRadius,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      filter.accountId == null
                                          ? l.addressBookAccountAll
                                          : value.walletAccounts
                                                .firstWhere(
                                                  (a) =>
                                                      a.id == filter.accountId,
                                                  orElse: () => value
                                                      .walletAccounts
                                                      .first,
                                                )
                                                .name,
                                      style: OwTextStyles.caption.copyWith(
                                        color: filter.accountId != null
                                            ? c.brand
                                            : c.ink,
                                        fontWeight: filter.accountId != null
                                            ? FontWeight.w500
                                            : FontWeight.w400,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_drop_down_rounded,
                                      size: 16,
                                      color: filter.accountId != null
                                          ? c.brand
                                          : c.muted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 3. 地址列表与状态
            Expanded(
              child: switch (asyncState) {
                AsyncLoading() => const OwSkeleton(),
                AsyncError(:final error) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      error is Failure
                          ? failureText(l, error)
                          : failureText(l, const UnknownFailure()),
                      style: OwTextStyles.body.copyWith(color: c.down),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                AsyncData(:final value) => _buildContent(
                  context,
                  l,
                  c,
                  value,
                  addressCodec,
                ),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppLocalizations l,
    OwColors c,
    AddressBookState state,
    AddressCodec codec,
  ) {
    if (state.isCompletelyEmpty) {
      return EmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: l.addressBookEmptyTitle,
        body: l.addressBookEmptyDesc,
      );
    }

    if (state.isSearchEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: l.addressBookSearchNoResultTitle,
        body: l.addressBookSearchNoResultDesc,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OwListGroup(
            children: [
              for (final item in state.entries) ...[
                () {
                  final display = codec.display(
                    item.address.address,
                    item.address.family,
                  );
                  final chain = _chainLabel(l, item.address);
                  final vaultPart = item.address.scheme != null
                      ? ' · 🔐 ${l.addressBookVaultDerived}'
                      : '';
                  final notePart = item.address.note.isNotEmpty
                      ? ' · ${l.addressBookNote(item.address.note)}'
                      : '';
                  final subtitle =
                      '${item.account.name} · $chain$vaultPart$notePart';

                  final accountAddressesCount = state.allAddresses
                      .where((a) => a.accountId == item.address.accountId)
                      .length;
                  final canDelete = accountAddressesCount > 1;

                  return OwRow(
                    avatar: OwAvatar(label: _familyMark(item.address.family)),
                    title: shortenAddress(display),
                    monoTitle: true,
                    subtitle: subtitle,
                    trailing: item.isExactMatch
                        ? OwPill(
                            label: l.addressBookExactMatch,
                            tone: OwPillTone.green,
                          )
                        : Icon(
                            Icons.chevron_right_rounded,
                            color: c.muted,
                            size: 20,
                          ),
                    onTap: () => showAddressSheet(
                      context,
                      address: item.address,
                      canDelete: canDelete,
                    ),
                  );
                }(),
              ],
            ],
          ),
          const SizedBox(height: 16),
          OwNotice(message: l.addressBookFooterTip, tone: OwNoticeTone.info),
        ],
      ),
    );
  }
}
