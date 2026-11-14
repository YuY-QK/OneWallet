import 'package:flutter/material.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/ow_colors.dart';
import '../../../../theme/ow_text_styles.dart';
import '../../../../widgets/failure_text.dart';
import '../../../../widgets/ow_chip.dart';
import '../../../../widgets/ow_input_decoration.dart';
import '../../../../widgets/ow_secondary_button.dart';
import '../../../shared/labels.dart';
import '../../controllers/add_wallet_state.dart';

/// P05 中的一个地址输入：输入框、粘贴、识别结果、链选择、重复提示。
class AddressEntryCard extends StatefulWidget {
  const AddressEntryCard({
    super.key,
    required this.entry,
    required this.index,
    required this.showErrors,
    required this.removable,
    required this.onChanged,
    required this.onPaste,
    required this.onToggleChain,
    required this.onRemove,
  });

  final AddressEntry entry;

  /// 序号（从 0 起），第二个起标题带序号。
  final int index;
  final bool showErrors;
  final bool removable;
  final ValueChanged<String> onChanged;
  final VoidCallback onPaste;
  final ValueChanged<String> onToggleChain;
  final VoidCallback onRemove;

  @override
  State<AddressEntryCard> createState() => _AddressEntryCardState();
}

class _AddressEntryCardState extends State<AddressEntryCard> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.entry.raw,
  );

  @override
  void didUpdateWidget(AddressEntryCard old) {
    super.didUpdateWidget(old);
    // 粘贴按钮会从控制器改写内容，同步回输入框。
    if (_controller.text != widget.entry.raw) {
      _controller.text = widget.entry.raw;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final e = widget.entry;
    final error = _errorText(l);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: OwFieldLabel(
                widget.index == 0
                    ? l.walletAddAddress
                    : l.walletAddAddressN(widget.index + 1),
              ),
            ),
            if (widget.removable)
              IconButton(
                tooltip: l.walletAddRemove,
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: widget.onRemove,
              ),
          ],
        ),
        TextField(
          controller: _controller,
          onChanged: widget.onChanged,
          autocorrect: false,
          enableSuggestions: false,
          style: OwTextStyles.mono.copyWith(color: context.ow.ink),
          decoration: owInputDecoration(
            context,
            hint: l.walletAddAddressHint,
            error: error != null,
            suffixIcon: TextButton(
              onPressed: widget.onPaste,
              child: Text(l.walletAddPaste),
            ),
          ),
        ),
        const SizedBox(height: 6),
        _status(context, l, error),
        if (e.family != null) ...[
          const SizedBox(height: 8),
          _chains(context, l),
        ],
      ],
    );
  }

  /// 要显示的错误；没有则为 null。
  String? _errorText(AppLocalizations l) {
    final e = widget.entry;
    if (e.unrecognized) return l.walletAddUnrecognized;
    if (e.duplicate != null) return failureText(l, e.duplicate!);
    if (!widget.showErrors) return null;
    if (e.isEmpty) return l.walletAddAddressRequired;
    if (e.chainIds.isEmpty && e.family != null) return l.walletAddChainRequired;
    return null;
  }

  Widget _status(BuildContext context, AppLocalizations l, String? error) {
    final c = context.ow;
    final family = widget.entry.family;
    if (error != null) {
      return Text(error, style: OwTextStyles.caption.copyWith(color: c.down));
    }
    if (family == null) return const SizedBox.shrink();
    return Row(
      children: [
        Icon(Icons.check, size: 14, color: c.up),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            l.walletAddRecognized(chainFamilyLabel(l, family)),
            style: OwTextStyles.caption.copyWith(color: c.up),
          ),
        ),
      ],
    );
  }

  Widget _chains(BuildContext context, AppLocalizations l) {
    final family = widget.entry.family!;
    final chains = Chains.ofFamily(family);
    if (family != ChainFamily.evm) {
      return Text(
        l.walletAddChainAuto(chains.first.name),
        style: OwTextStyles.caption.copyWith(color: context.ow.muted),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OwFieldLabel(l.walletAddChains),
        Wrap(
          spacing: 6,
          runSpacing: 0,
          children: [
            for (final chain in chains)
              OwChip(
                label: chain.name,
                selected: widget.entry.chainIds.contains(chain.id),
                onTap: () => widget.onToggleChain(chain.id),
              ),
          ],
        ),
      ],
    );
  }
}

/// "再添加一个地址"按钮。
class AddAnotherAddressButton extends StatelessWidget {
  const AddAnotherAddressButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: IntrinsicWidth(
      child: OwSecondaryButton(
        label: AppLocalizations.of(context)!.walletAddAnother,
        compact: true,
        onPressed: onPressed,
      ),
    ),
  );
}
