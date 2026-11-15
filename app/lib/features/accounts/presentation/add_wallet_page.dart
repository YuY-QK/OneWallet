import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_directory/ow_directory.dart';

import '../../../l10n/app_localizations.dart';
import '../../../router/route_names.dart';
import '../../../theme/ow_colors.dart';
import '../../../theme/ow_text_styles.dart';
import '../../../widgets/failure_text.dart';
import '../../../widgets/ow_chip.dart';
import '../../../widgets/ow_input_decoration.dart';
import '../../../widgets/ow_notice.dart';
import '../../../widgets/ow_primary_button.dart';
import '../../shared/labels.dart';
import '../controllers/add_wallet_controller.dart';
import '../controllers/add_wallet_state.dart';
import 'widgets/address_entry_card.dart';

/// P05 添加钱包账户（观察地址）。[accountId] 非空时是"给已有账户添加地址"，
/// 名称与来源只读。
class AddWalletPage extends ConsumerStatefulWidget {
  const AddWalletPage({super.key, this.accountId});

  final String? accountId;

  @override
  ConsumerState<AddWalletPage> createState() => _AddWalletPageState();
}

class _AddWalletPageState extends ConsumerState<AddWalletPage> {
  late final TextEditingController _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  AddWalletController get _controller =>
      ref.read(addWalletControllerProvider(widget.accountId).notifier);

  Future<void> _save() async {
    final id = await _controller.save();
    if (id != null && mounted) {
      context.goNamed(RouteNames.walletDetail, pathParameters: {'id': id});
    }
  }

  Future<void> _paste(int key) async {
    final ok = await _controller.paste(key);
    if (!ok && mounted) {
      final l = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.walletAddClipboardEmpty)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final s = ref.watch(addWalletControllerProvider(widget.accountId));
    return Scaffold(
      appBar: AppBar(
        title: Text(s.isAppendMode ? l.walletAddExtraTitle : l.walletAddTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          if (s.accountMissing)
            OwNotice(
              message: l.walletAddAccountMissing,
              tone: OwNoticeTone.error,
            )
          else ...[
            _nameField(context, l, s),
            const SizedBox(height: 12),
            _sourceField(context, l, s),
            const SizedBox(height: 12),
            for (var i = 0; i < s.entries.length; i++) ...[
              AddressEntryCard(
                key: ValueKey(s.entries[i].key),
                entry: s.entries[i],
                index: i,
                showErrors: s.showErrors,
                removable: s.entries.length > 1,
                onChanged: (v) => _controller.setAddress(s.entries[i].key, v),
                onPaste: () => _paste(s.entries[i].key),
                onToggleChain: (c) =>
                    _controller.toggleChain(s.entries[i].key, c),
                onRemove: () => _controller.removeEntry(s.entries[i].key),
              ),
              const SizedBox(height: 12),
            ],
            AddAnotherAddressButton(onPressed: _controller.addEntry),
            if (s.hasEvmEntry && s.alchemyKeyMissing) ...[
              const SizedBox(height: 12),
              OwNotice(message: l.walletAddKeyMissing, tone: OwNoticeTone.info),
            ],
            if (!s.isAppendMode) ...[
              const SizedBox(height: 12),
              _backupField(l, s),
            ],
            if (s.saveFailure != null) ...[
              const SizedBox(height: 12),
              OwNotice(
                message: failureText(l, s.saveFailure!),
                tone: OwNoticeTone.error,
              ),
            ],
            const SizedBox(height: 16),
            OwPrimaryButton(
              label: s.saving ? l.walletAddSaving : l.walletAddSave,
              onPressed: s.saving ? null : _save,
            ),
          ],
        ],
      ),
    );
  }

  Widget _nameField(
    BuildContext context,
    AppLocalizations l,
    AddWalletState s,
  ) {
    if (s.isAppendMode) {
      return _readOnly(context, l.walletAddName, s.existing?.name ?? '');
    }
    final error = s.showErrors && !s.nameValid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OwFieldLabel(l.walletAddName),
        TextField(
          controller: _name,
          onChanged: _controller.setName,
          inputFormatters: [
            LengthLimitingTextInputFormatter(maxAccountNameLength),
          ],
          style: OwTextStyles.body.copyWith(color: context.ow.ink),
          decoration: owInputDecoration(
            context,
            hint: l.walletAddNameHint,
            error: error,
          ),
        ),
        if (error)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              l.walletAddNameRequired,
              style: OwTextStyles.caption.copyWith(color: context.ow.down),
            ),
          ),
      ],
    );
  }

  Widget _sourceField(
    BuildContext context,
    AppLocalizations l,
    AddWalletState s,
  ) {
    if (s.isAppendMode) {
      return _readOnly(
        context,
        l.walletAddSource,
        walletSourceLabel(
              l,
              s.existing?.walletSource,
              walletSourceId: s.existing?.walletSourceId,
            ) ??
            '—',
      );
    }
    final selectedLabel =
        walletSourceLabel(l, s.source, walletSourceId: s.walletSourceId) ??
        l.walletSourceOther;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OwFieldLabel(l.walletAddSource),
        InkWell(
          key: const ValueKey('wallet-source-field'),
          onTap: () => _showWalletSourcePicker(context, l, s),
          borderRadius: BorderRadius.circular(10),
          child: InputDecorator(
            decoration: owInputDecoration(
              context,
              suffixIcon: const Icon(Icons.arrow_drop_down),
            ),
            child: Text(
              selectedLabel,
              style: OwTextStyles.body.copyWith(color: context.ow.ink),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showWalletSourcePicker(
    BuildContext context,
    AppLocalizations l,
    AddWalletState s,
  ) async {
    final directory = ThirdPartyDirectory.builtin();
    final verifiedWallets = directory.verifiedOnly
        .where((e) => e.kind == DirectoryKind.wallet)
        .toList(growable: false);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _WalletSourcePickerSheet(
        wallets: verifiedWallets,
        selectedId: s.walletSourceId,
        onSelected: (id) {
          _controller.setSourceId(id);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  Widget _readOnly(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OwFieldLabel(label),
        InputDecorator(
          decoration: owInputDecoration(context, readOnly: true),
          child: Text(
            value,
            style: OwTextStyles.body.copyWith(color: context.ow.muted),
          ),
        ),
      ],
    );
  }

  Widget _backupField(AppLocalizations l, AddWalletState s) {
    final options = [
      (BackupChoice.none, l.walletAddBackupNone),
      (BackupChoice.offline, l.walletAddBackupOffline),
      (BackupChoice.keyless, l.walletAddBackupKeyless),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OwFieldLabel(l.walletAddBackup),
        Wrap(
          spacing: 6,
          children: [
            for (final (choice, label) in options)
              OwChip(
                label: label,
                selected: s.backup == choice,
                onTap: () => _controller.setBackup(choice),
              ),
          ],
        ),
      ],
    );
  }
}

class _WalletSourcePickerSheet extends StatefulWidget {
  const _WalletSourcePickerSheet({
    required this.wallets,
    required this.selectedId,
    required this.onSelected,
  });

  final List<DirectoryEntry> wallets;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  State<_WalletSourcePickerSheet> createState() =>
      _WalletSourcePickerSheetState();
}

class _WalletSourcePickerSheetState extends State<_WalletSourcePickerSheet> {
  final TextEditingController _query = TextEditingController();
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _query.addListener(() {
      setState(() => _filter = _query.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.ow;

    final filtered = widget.wallets
        .where((w) {
          if (_filter.isEmpty) return true;
          if (w.name.toLowerCase().contains(_filter)) return true;
          return w.aliases.any((a) => a.toLowerCase().contains(_filter));
        })
        .toList(growable: false);

    final showOther =
        _filter.isEmpty ||
        l.walletSourceOther.toLowerCase().contains(_filter) ||
        'other'.contains(_filter);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(l.walletAddSource, style: OwTextStyles.emphasis),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _query,
              style: OwTextStyles.body.copyWith(color: c.ink),
              decoration: owInputDecoration(
                context,
                hint: l.walletAddSourceSearch,
                prefixIcon: const Icon(Icons.search, size: 20),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                for (final w in filtered)
                  ListTile(
                    title: Text(w.name, style: OwTextStyles.body),
                    trailing: widget.selectedId == w.id
                        ? Icon(Icons.check, color: c.brand, size: 20)
                        : null,
                    onTap: () => widget.onSelected(w.id),
                  ),
                if (showOther)
                  ListTile(
                    title: Text(l.walletSourceOther, style: OwTextStyles.body),
                    trailing: widget.selectedId == null
                        ? Icon(Icons.check, color: c.brand, size: 20)
                        : null,
                    onTap: () => widget.onSelected(null),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
