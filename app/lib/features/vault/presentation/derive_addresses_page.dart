import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../../bootstrap/adapter_providers.dart';
import '../../../bootstrap/foundation_providers.dart';
import '../../../bootstrap/vault_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/ow_colors.dart';
import '../../../theme/ow_text_styles.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/failure_text.dart';
import '../../../widgets/ow_card.dart';
import '../../../widgets/ow_input_decoration.dart';
import '../../../widgets/ow_notice.dart';
import '../../../widgets/ow_pill.dart';
import '../../../widgets/ow_primary_button.dart';

/// P16 派生地址页。
class DeriveAddressesPage extends ConsumerStatefulWidget {
  const DeriveAddressesPage({super.key, required this.itemId});

  final String itemId;

  @override
  ConsumerState<DeriveAddressesPage> createState() =>
      _DeriveAddressesPageState();
}

class _DeriveAddressesPageState extends ConsumerState<DeriveAddressesPage> {
  ChainFamily _selectedFamily = ChainFamily.evm;
  late DerivationScheme _selectedScheme;

  bool _isDeriving = false;
  bool _isCheckingBalance = false;
  String? _errorMessage;

  List<DerivedAddress> _derivedList = [];
  int _displayedCount = 5;
  final Set<String> _selectedAddresses = {};
  final Map<String, bool?> _activityStatus = {};

  bool _isNewAccount = true;
  late final TextEditingController _newAccountNameController;
  String? _selectedExistingAccountId;

  @override
  void initState() {
    super.initState();
    _selectedScheme = DerivationScheme.forFamily(_selectedFamily).first;
    _newAccountNameController = TextEditingController();
  }

  @override
  void dispose() {
    _newAccountNameController.dispose();
    super.dispose();
  }

  void _onFamilyChanged(ChainFamily family) {
    if (_selectedFamily == family) return;
    setState(() {
      _selectedFamily = family;
      _selectedScheme = DerivationScheme.forFamily(family).first;
      _derivedList = [];
      _selectedAddresses.clear();
      _activityStatus.clear();
      _displayedCount = 5;
      _errorMessage = null;
    });
  }

  void _onSchemeChanged(DerivationScheme scheme) {
    if (_selectedScheme == scheme) return;
    setState(() {
      _selectedScheme = scheme;
      _derivedList = [];
      _selectedAddresses.clear();
      _activityStatus.clear();
      _displayedCount = 5;
      _errorMessage = null;
    });
  }

  Future<void> _startDerivation() async {
    final l = AppLocalizations.of(context)!;
    final pwController = TextEditingController();
    var obscure = true;

    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l.vaultDeriveVerifyTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.vaultDeriveAuthPrompt,
                style: OwTextStyles.body.copyWith(color: ctx.ow.muted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pwController,
                obscureText: obscure,
                autofocus: true,
                onChanged: (_) => setDialogState(() {}),
                decoration: owInputDecoration(
                  ctx,
                  hint: l.vaultItemDeletePasswordHint,
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: Text(l.vaultImportVerifyPasswordCancel),
            ),
            FilledButton(
              onPressed: pwController.text.isNotEmpty
                  ? () => Navigator.of(ctx).pop(pwController.text)
                  : null,
              child: Text(l.vaultDeriveVerifyConfirm),
            ),
          ],
        ),
      ),
    );

    pwController.clear();
    if (password == null || password.isEmpty) return;

    setState(() {
      _isDeriving = true;
      _errorMessage = null;
    });

    final sensitivePw = Sensitive(Uint8List.fromList(utf8.encode(password)));
    try {
      final deriveUsecase = await ref.read(deriveAddressesProvider.future);
      final res = await deriveUsecase(
        itemId: widget.itemId,
        credential: PasswordCredential(sensitivePw),
        scheme: _selectedScheme,
        startIndex: 0,
        count: 20,
      );

      if (!mounted) return;

      if (res case Ok(:final value)) {
        setState(() {
          _isDeriving = false;
          _derivedList = value;
          _selectedAddresses.clear();
          for (final a in value.take(_displayedCount)) {
            if (!a.alreadyWatched) {
              _selectedAddresses.add(a.address);
            }
          }
        });
      } else if (res case Err(:final failure)) {
        setState(() {
          _isDeriving = false;
          _errorMessage = failureText(l, failure);
        });
      }
    } finally {
      sensitivePw.wipe();
    }
  }

  void _showMore() {
    setState(() {
      _displayedCount = (_displayedCount + 5).clamp(0, _derivedList.length);
      for (final a in _derivedList.take(_displayedCount)) {
        if (!a.alreadyWatched && !_selectedAddresses.contains(a.address)) {
          _selectedAddresses.add(a.address);
        }
      }
    });
  }

  Future<void> _checkBalance() async {
    if (_derivedList.isEmpty || _isCheckingBalance) return;

    setState(() => _isCheckingBalance = true);

    final displayed = _derivedList.take(_displayedCount).toList();
    final adapterRegistry = ref.read(adapterRegistryProvider);
    final adapter = adapterRegistry.chain(_selectedFamily);

    final primaryChain = switch (_selectedFamily) {
      ChainFamily.evm => Chains.byId('ethereum'),
      ChainFamily.bitcoin => Chains.byId('bitcoin'),
      ChainFamily.solana => Chains.byId('solana'),
      ChainFamily.tron => Chains.byId('tron'),
    };

    for (final da in displayed) {
      if (!mounted) break;
      try {
        final res = await adapter.hasActivity(da.address, primaryChain);
        if (!mounted) break;
        setState(() {
          if (res case Ok(:final value)) {
            _activityStatus[da.address] = value;
          } else {
            _activityStatus[da.address] = null;
          }
        });
      } catch (_) {
        if (!mounted) break;
        setState(() {
          _activityStatus[da.address] = null;
        });
      }
    }

    if (mounted) {
      setState(() => _isCheckingBalance = false);
    }
  }

  Future<void> _attach() async {
    final l = AppLocalizations.of(context)!;
    final toAttach = _derivedList
        .where(
          (a) => _selectedAddresses.contains(a.address) && !a.alreadyWatched,
        )
        .toList();

    if (toAttach.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.vaultDeriveNoSelection)));
      return;
    }

    final attachUsecase = ref.read(attachDerivedAddressesProvider);
    final res = await attachUsecase(
      itemId: widget.itemId,
      addresses: toAttach,
      newAccountName: _isNewAccount
          ? _newAccountNameController.text.trim()
          : null,
      existingAccountId: !_isNewAccount ? _selectedExistingAccountId : null,
    );

    if (!mounted) return;

    if (res case Ok()) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.vaultDeriveSuccess)));
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } else if (res case Err(:final failure)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failureText(l, failure))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.ow;

    final metaStream = ref
        .watch(vaultMetaRepositoryProvider)
        .watchAll()
        .map(
          (items) => items.where((it) => it.id == widget.itemId).firstOrNull,
        );
    final accountsStream = ref.watch(accountRepositoryProvider).watchAll();

    return StreamBuilder<VaultItemMeta?>(
      stream: metaStream,
      builder: (context, metaSnapshot) {
        final meta = metaSnapshot.data;
        if (meta == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l.vaultDeriveTitle)),
            body: Center(
              child: EmptyState(
                icon: Icons.vpn_key_off_outlined,
                title: l.vaultDeriveItemNotFound,
                body: '',
              ),
            ),
          );
        }

        if (_newAccountNameController.text.isEmpty) {
          _newAccountNameController.text = meta.name;
        }

        final isMnemonic = meta.kind == VaultItemKind.mnemonic;
        final availableFamilies = isMnemonic
            ? const [
                ChainFamily.evm,
                ChainFamily.bitcoin,
                ChainFamily.solana,
                ChainFamily.tron,
              ]
            : [meta.family ?? ChainFamily.evm];

        if (!availableFamilies.contains(_selectedFamily)) {
          _selectedFamily = availableFamilies.first;
          _selectedScheme = DerivationScheme.forFamily(_selectedFamily).first;
        }

        final schemes = DerivationScheme.forFamily(_selectedFamily);

        return Scaffold(
          appBar: AppBar(
            title: Text(l.vaultDeriveTitle),
            actions: [
              TextButton(
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
                child: Text(l.vaultDeriveSkipAction),
              ),
            ],
          ),
          body: StreamBuilder<List<Account>>(
            stream: accountsStream,
            builder: (context, accSnapshot) {
              final accounts = (accSnapshot.data ?? [])
                  .where((a) => a.type == AccountType.wallet)
                  .toList();

              if (_selectedExistingAccountId == null && accounts.isNotEmpty) {
                _selectedExistingAccountId = accounts.first.id;
              }

              final displayedAddresses = _derivedList
                  .take(_displayedCount)
                  .toList();

              return ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                children: [
                  // 1. 提示条
                  OwNotice(
                    message: l.vaultDeriveNotice,
                    tone: OwNoticeTone.info,
                  ),
                  const SizedBox(height: 16),

                  // 2. 链选择（助记词才显示）
                  if (isMnemonic) ...[
                    SegmentedButton<ChainFamily>(
                      segments: [
                        for (final fam in availableFamilies)
                          ButtonSegment<ChainFamily>(
                            value: fam,
                            label: Text(fam.name.toUpperCase()),
                          ),
                      ],
                      selected: {_selectedFamily},
                      onSelectionChanged: (set) {
                        if (set.isNotEmpty) _onFamilyChanged(set.first);
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 3. 派生路径下拉选择
                  OwCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '派生路径',
                          style: OwTextStyles.caption.copyWith(color: c.muted),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<DerivationScheme>(
                          initialValue: _selectedScheme,
                          decoration: owInputDecoration(context),
                          items: [
                            for (final s in schemes)
                              DropdownMenuItem<DerivationScheme>(
                                value: s,
                                child: Text(
                                  '${_getSchemeTitle(s, l)} · ${s.pathTemplate.replaceAll('{i}', 'i')}',
                                  style: OwTextStyles.body,
                                ),
                              ),
                          ],
                          onChanged: (val) {
                            if (val != null) _onSchemeChanged(val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 4. 地址列表或派生启动按钮
                  if (_isDeriving) ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('正在计算派生地址...'),
                          ],
                        ),
                      ),
                    ),
                  ] else if (_derivedList.isEmpty) ...[
                    OwCard(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 24,
                          horizontal: 16,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.lock_clock_outlined,
                              size: 40,
                              color: c.muted,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              l.vaultDeriveAuthPrompt,
                              textAlign: TextAlign.center,
                              style: OwTextStyles.body.copyWith(color: c.muted),
                            ),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: OwTextStyles.caption.copyWith(
                                  color: c.down,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            OwPrimaryButton(
                              label: l.vaultDeriveVerifyConfirm,
                              onPressed: _startDerivation,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    OwCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (
                            var i = 0;
                            i < displayedAddresses.length;
                            i++
                          ) ...[
                            if (i > 0) const Divider(height: 1),
                            _buildAddressRow(displayedAddresses[i], l, c),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (_displayedCount < _derivedList.length)
                          OutlinedButton(
                            onPressed: _showMore,
                            child: Text(l.vaultDeriveShowMore),
                          ),
                        const Spacer(),
                        OutlinedButton.icon(
                          icon: _isCheckingBalance
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.sync_outlined, size: 16),
                          label: Text(
                            _isCheckingBalance
                                ? l.vaultDeriveCheckingBalance
                                : l.vaultDeriveCheckBalance,
                          ),
                          onPressed: _isCheckingBalance ? null : _checkBalance,
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),

                  // 5. 目标账户
                  OwCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.vaultDeriveTargetAccount,
                          style: OwTextStyles.emphasis,
                        ),
                        const SizedBox(height: 12),
                        if (accounts.isEmpty) ...[
                          Text(
                            l.vaultDeriveNewAccount,
                            style: OwTextStyles.body.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ] else ...[
                          SegmentedButton<bool>(
                            segments: [
                              ButtonSegment<bool>(
                                value: true,
                                label: Text(l.vaultDeriveNewAccount),
                              ),
                              ButtonSegment<bool>(
                                value: false,
                                label: Text(l.vaultDeriveExistingAccount),
                              ),
                            ],
                            selected: {_isNewAccount},
                            onSelectionChanged: (set) {
                              if (set.isNotEmpty) {
                                setState(() => _isNewAccount = set.first);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (_isNewAccount)
                          TextField(
                            controller: _newAccountNameController,
                            decoration: owInputDecoration(
                              context,
                              hint: l.vaultDeriveNewAccountNameLabel,
                            ),
                          )
                        else
                          DropdownButtonFormField<String>(
                            initialValue: _selectedExistingAccountId,
                            decoration: owInputDecoration(context),
                            items: [
                              for (final acc in accounts)
                                DropdownMenuItem<String>(
                                  value: acc.id,
                                  child: Text(acc.name),
                                ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(
                                  () => _selectedExistingAccountId = val,
                                );
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 6. 底部主操作
                  OwPrimaryButton(
                    label: l.vaultDeriveAttachAction,
                    onPressed: _derivedList.isNotEmpty ? _attach : null,
                  ),
                  const SizedBox(height: 24),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildAddressRow(DerivedAddress da, AppLocalizations l, OwColors c) {
    final isSelected = _selectedAddresses.contains(da.address);
    final activity = _activityStatus[da.address];

    return InkWell(
      onTap: da.alreadyWatched
          ? null
          : () {
              setState(() {
                if (isSelected) {
                  _selectedAddresses.remove(da.address);
                } else {
                  _selectedAddresses.add(da.address);
                }
              });
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Checkbox(
              value: da.alreadyWatched ? true : isSelected,
              onChanged: da.alreadyWatched
                  ? null
                  : (val) {
                      setState(() {
                        if (val == true) {
                          _selectedAddresses.add(da.address);
                        } else {
                          _selectedAddresses.remove(da.address);
                        }
                      });
                    },
            ),
            const SizedBox(width: 8),
            Text(
              '#${da.index ?? 0}',
              style: OwTextStyles.mono.copyWith(
                fontWeight: FontWeight.w600,
                color: c.muted,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AddressCodec.shorten(da.address),
                style: OwTextStyles.mono.copyWith(fontWeight: FontWeight.w500),
              ),
            ),
            if (da.alreadyWatched)
              OwPill(
                label: l.vaultDeriveAlreadyWatched,
                tone: OwPillTone.orange,
              )
            else if (activity != null)
              activity
                  ? OwPill(label: l.vaultDeriveActive, tone: OwPillTone.green)
                  : OwPill(
                      label: l.vaultDeriveInactive,
                      tone: OwPillTone.orange,
                    ),
          ],
        ),
      ),
    );
  }

  String _getSchemeTitle(DerivationScheme scheme, AppLocalizations l) {
    return switch (scheme) {
      DerivationScheme.evmStandard => l.vaultDeriveSchemeEvmStandard,
      DerivationScheme.evmLedgerLive => l.vaultDeriveSchemeEvmLedgerLive,
      DerivationScheme.btcNativeSegwit => l.vaultDeriveSchemeBtcNativeSegwit,
      DerivationScheme.btcTaproot => l.vaultDeriveSchemeBtcTaproot,
      DerivationScheme.btcNestedSegwit => l.vaultDeriveSchemeBtcNestedSegwit,
      DerivationScheme.btcLegacy => l.vaultDeriveSchemeBtcLegacy,
      DerivationScheme.solanaStandard => l.vaultDeriveSchemeSolanaStandard,
      DerivationScheme.solanaLegacy => l.vaultDeriveSchemeSolanaLegacy,
      DerivationScheme.tronStandard => l.vaultDeriveSchemeTronStandard,
    };
  }
}
