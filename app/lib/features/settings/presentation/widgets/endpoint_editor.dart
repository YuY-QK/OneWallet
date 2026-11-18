import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/ow_colors.dart';
import '../../../../theme/ow_text_styles.dart';
import '../../../../widgets/ow_input_decoration.dart';
import '../../../../widgets/ow_secondary_button.dart';
import '../../controllers/data_sources_controller.dart';

/// 自定义 RPC 端点编辑（高级选项）。[chains] 缺省时显示六条 EVM 链。
class EndpointEditors extends StatelessWidget {
  const EndpointEditors({super.key, this.chains});

  final List<ChainInfo>? chains;

  @override
  Widget build(BuildContext context) {
    final list = chains ?? Chains.ofFamily(ChainFamily.evm);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final chain in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _EndpointRow(chain: chain),
          ),
      ],
    );
  }
}

class _EndpointRow extends ConsumerStatefulWidget {
  const _EndpointRow({required this.chain});

  final ChainInfo chain;

  @override
  ConsumerState<_EndpointRow> createState() => _EndpointRowState();
}

class _EndpointRowState extends ConsumerState<_EndpointRow> {
  final TextEditingController _input = TextEditingController();
  bool _invalid = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final result = await ref
        .read(dataSourcesProvider.notifier)
        .saveEndpoint(widget.chain.id, _input.text);
    if (!mounted) return;
    setState(() => _invalid = !result.isOk);
    if (result.isOk) _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.ow;
    final host = ref.watch(
      dataSourcesProvider.select(
        (s) => s.value?.endpointHosts[widget.chain.id],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OwFieldLabel(widget.chain.name),
        TextField(
          controller: _input,
          keyboardType: TextInputType.url,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: (_) {
            if (_invalid) setState(() => _invalid = false);
          },
          style: OwTextStyles.mono.copyWith(color: c.ink),
          decoration: owInputDecoration(
            context,
            hint: l.sourcesEndpointHint,
            error: _invalid,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _invalid
              ? l.sourcesEndpointInvalid
              : (host == null
                    ? l.sourcesEndpointDefault
                    : l.sourcesEndpointSet(host)),
          style: OwTextStyles.caption.copyWith(
            color: _invalid ? c.down : c.muted,
          ),
        ),
        Row(
          children: [
            OwSecondaryButton(
              label: l.sourcesEndpointSave,
              compact: true,
              onPressed: _save,
            ),
            const SizedBox(width: 8),
            if (host != null)
              OwSecondaryButton(
                label: l.sourcesEndpointClear,
                compact: true,
                onPressed: () => ref
                    .read(dataSourcesProvider.notifier)
                    .clearEndpoint(widget.chain.id),
              ),
          ],
        ),
      ],
    );
  }
}
