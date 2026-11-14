import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/ow_colors.dart';
import '../../../../theme/ow_text_styles.dart';
import '../../../../widgets/failure_text.dart';
import '../../../../widgets/ow_danger_button.dart';
import '../../../../widgets/ow_input_decoration.dart';
import '../../../../widgets/ow_notice.dart';
import '../../../../widgets/ow_primary_button.dart';
import '../../../../widgets/ow_secondary_button.dart';
import '../../controllers/data_sources_controller.dart';
import 'endpoint_editor.dart';

/// 打开某个服务商的编辑面板（底部弹层）。
Future<void> showDataSourceEditor(
  BuildContext context, {
  required String providerId,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => DataSourceEditor(providerId: providerId),
);

/// 服务商编辑面板：Key 输入（密码型，可切换显示）、保存、清除、测试连接，
/// Alchemy 另有折叠的自定义 RPC 端点。
///
/// 输入框里的内容只存在于输入框自己的控制器中：保存成功后立即清空，
/// 已保存的 Key 不会被读回输入框，也不会出现在界面的任何文字里
/// （最多显示前 4 位加 `***`）。
class DataSourceEditor extends ConsumerStatefulWidget {
  const DataSourceEditor({super.key, required this.providerId});

  final String providerId;

  @override
  ConsumerState<DataSourceEditor> createState() => _DataSourceEditorState();
}

class _DataSourceEditorState extends ConsumerState<DataSourceEditor> {
  final TextEditingController _input = TextEditingController();
  bool _obscure = true;
  bool _showEmptyError = false;
  bool _justSaved = false;
  bool _advancedOpen = false;

  bool get _isMempool => widget.providerId == DataSourceIds.mempool;

  String _name(AppLocalizations l) => switch (widget.providerId) {
    DataSourceIds.alchemy => l.sourcesAlchemyName,
    DataSourceIds.mempool => l.sourcesMempoolName,
    DataSourceIds.helius => l.sourcesHeliusName,
    DataSourceIds.trongrid => l.sourcesTrongridName,
    DataSourceIds.coingecko => l.sourcesCoingeckoName,
    _ => widget.providerId,
  };

  String _requirement(AppLocalizations l) => switch (widget.providerId) {
    DataSourceIds.alchemy => l.sourcesAlchemyRequired,
    DataSourceIds.mempool => l.sourcesMempoolRequired,
    DataSourceIds.helius => l.sourcesHeliusRequired,
    DataSourceIds.trongrid => l.sourcesTrongridRequired,
    DataSourceIds.coingecko => l.sourcesCoingeckoOptional,
    _ => '',
  };

  List<ChainInfo>? get _advancedChains => switch (widget.providerId) {
    DataSourceIds.alchemy => Chains.ofFamily(ChainFamily.evm),
    DataSourceIds.mempool => [Chains.byId('bitcoin')],
    DataSourceIds.helius => [Chains.byId('solana')],
    DataSourceIds.trongrid => [Chains.byId('tron')],
    _ => null,
  };

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  DataSourcesController get _controller =>
      ref.read(dataSourcesProvider.notifier);

  Future<void> _save() async {
    final result = await _controller.saveKey(widget.providerId, _input.text);
    if (!mounted) return;
    if (result.isOk) {
      _input.clear();
      setState(() {
        _showEmptyError = false;
        _justSaved = true;
      });
    } else {
      setState(() {
        _showEmptyError = true;
        _justSaved = false;
      });
    }
  }

  Future<void> _clear() async {
    await _controller.clearKey(widget.providerId);
    if (mounted) setState(() => _justSaved = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.ow;
    final state = ref.watch(dataSourcesProvider).value;
    final status = state?.statusOf(widget.providerId);
    final testing = state?.testing.contains(widget.providerId) ?? false;
    final outcome = state?.outcomes[widget.providerId];
    final hasUnsaved = !_isMempool && _input.text.trim().isNotEmpty;
    final name = _name(l);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.sourcesEditTitle(name), style: OwTextStyles.emphasis),
              const SizedBox(height: 4),
              Text(
                _requirement(l),
                style: OwTextStyles.caption.copyWith(color: c.muted),
              ),
              const SizedBox(height: 12),
              if (!_isMempool) ...[
                OwFieldLabel(l.sourcesKeyLabel),
                TextField(
                  controller: _input,
                  obscureText: _obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: OwTextStyles.mono.copyWith(color: c.ink),
                  decoration: owInputDecoration(
                    context,
                    hint: (status?.configured ?? false)
                        ? l.sourcesKeyHintReplace
                        : l.sourcesKeyHint,
                    error: _showEmptyError,
                    suffixIcon: IconButton(
                      tooltip: _obscure ? l.sourcesKeyShow : l.sourcesKeyHide,
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                if (_showEmptyError)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      l.sourcesKeyEmpty,
                      style: OwTextStyles.caption.copyWith(color: c.down),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
              Text(
                status?.configured ?? false
                    ? (status?.preview == null
                          ? l.sourcesConfigured
                          : l.sourcesConfiguredPreview(status!.preview!))
                    : l.sourcesNotConfigured,
                style: OwTextStyles.caption.copyWith(
                  color: (status?.configured ?? false) ? c.up : c.warn,
                ),
              ),
              if (_justSaved)
                Text(
                  l.sourcesSaved,
                  style: OwTextStyles.caption.copyWith(color: c.up),
                ),
              const SizedBox(height: 12),
              if (!_isMempool) ...[
                OwPrimaryButton(label: l.sourcesSave, onPressed: _save),
                const SizedBox(height: 8),
              ],
              OwSecondaryButton(
                label: testing ? l.sourcesTesting : l.sourcesTest,
                onPressed: (testing || hasUnsaved)
                    ? null
                    : () => _controller.testConnection(widget.providerId),
              ),
              if (hasUnsaved)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    l.sourcesTestSaveFirst,
                    style: OwTextStyles.caption.copyWith(color: c.muted),
                  ),
                ),
              if (outcome != null && !testing) ...[
                const SizedBox(height: 8),
                switch (outcome) {
                  TestPassed() => OwNotice(
                    message: l.sourcesTestOk,
                    tone: OwNoticeTone.info,
                  ),
                  TestFailed(:final failure) => OwNotice(
                    message: failureText(l, failure),
                    tone: OwNoticeTone.error,
                  ),
                },
              ],
              if (!_isMempool && (status?.configured ?? false)) ...[
                const SizedBox(height: 8),
                OwDangerButton(label: l.sourcesClear, onPressed: _clear),
              ],
              if (_advancedChains != null) ..._advanced(l, c, state),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _advanced(AppLocalizations l, OwColors c, DataSourcesState? s) {
    return [
      const SizedBox(height: 12),
      InkWell(
        onTap: () => setState(() => _advancedOpen = !_advancedOpen),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(l.sourcesAdvanced, style: OwTextStyles.rowTitle),
              ),
              Icon(
                _advancedOpen
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
              ),
            ],
          ),
        ),
      ),
      if (_advancedOpen && s != null) ...[
        Text(
          l.sourcesEndpointNote,
          style: OwTextStyles.caption.copyWith(color: c.muted),
        ),
        const SizedBox(height: 8),
        EndpointEditors(chains: _advancedChains),
      ],
    ];
  }
}
