import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_directory/ow_directory.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../../l10n/app_localizations.dart';
import '../../../router/route_names.dart';
import '../../../theme/ow_colors.dart';
import '../../../theme/ow_metrics.dart';
import '../../../theme/ow_text_styles.dart';
import '../../../widgets/failure_text.dart';
import '../../../widgets/ow_chip.dart';
import '../../../widgets/ow_external_link.dart';
import '../../../widgets/ow_input_decoration.dart';
import '../../../widgets/ow_notice.dart';
import '../../../widgets/ow_primary_button.dart';
import '../../shared/labels.dart';
import '../controllers/add_exchange_controller.dart';
import '../controllers/add_exchange_state.dart';

/// P06 添加交易所账户 / 更换 API Key 页面。
///
/// **安全红线**：
/// - API Key、Secret、Passphrase 仅存在于本组件的有状态生命周期内；
/// - 不存入任何状态管理对象（Riverpod State）；
/// - 保存成功或页面销毁时立即清空内存中的文字。
class AddExchangePage extends ConsumerStatefulWidget {
  const AddExchangePage({super.key, this.accountId});

  final String? accountId;

  @override
  ConsumerState<AddExchangePage> createState() => _AddExchangePageState();
}

class _AddExchangePageState extends ConsumerState<AddExchangePage> {
  late final TextEditingController _nameController = TextEditingController();
  late final TextEditingController _apiKeyController = TextEditingController();
  late final TextEditingController _apiSecretController =
      TextEditingController();
  late final TextEditingController _passphraseController =
      TextEditingController();

  AddExchangeController get _controller =>
      ref.read(addExchangeControllerProvider(widget.accountId).notifier);

  @override
  void initState() {
    super.initState();
    final s = ref.read(addExchangeControllerProvider(widget.accountId));
    _nameController.text = s.name;
  }

  @override
  void dispose() {
    _clearFields();
    _nameController.dispose();
    _apiKeyController.dispose();
    _apiSecretController.dispose();
    _passphraseController.dispose();
    super.dispose();
  }

  void _clearFields() {
    _apiKeyController.clear();
    _apiSecretController.clear();
    _passphraseController.clear();
  }

  void _onExchangeChanged(ExchangeId exchange, AddExchangeState s) {
    _controller.selectExchange(exchange);
    final updated = ref.read(addExchangeControllerProvider(widget.accountId));
    if (!updated.isUserCustomizedName && _nameController.text != updated.name) {
      _nameController.text = updated.name;
    }
  }

  Future<void> _pasteTo(TextEditingController controller) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isNotEmpty) {
      controller.text = text;
      setState(() {});
    } else if (mounted) {
      final l = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.walletAddClipboardEmpty)));
    }
  }

  Future<void> _testAndSave() async {
    final id = await _controller.testAndSave(
      apiKey: _apiKeyController.text,
      apiSecret: _apiSecretController.text,
      passphrase: _passphraseController.text,
    );
    if (!mounted) return;

    if (id != null) {
      _clearFields();
      _navigateSuccess(id);
      return;
    }

    final s = ref.read(addExchangeControllerProvider(widget.accountId));
    if (s.status == AddExchangeStatus.permissionWarning) {
      await _showPermissionWarningDialog();
    }
  }

  Future<void> _showPermissionWarningDialog() async {
    final l = AppLocalizations.of(context)!;
    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.exchangeAddPermWarningTitle),
        content: Text(l.exchangeAddPermWarningBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.exchangeAddPermWarningModify),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              l.exchangeAddPermWarningProceed,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (proceed == true) {
      final id = await _controller.confirmSave(
        apiKey: _apiKeyController.text,
        apiSecret: _apiSecretController.text,
        passphrase: _passphraseController.text,
      );
      if (id != null && mounted) {
        _clearFields();
        _navigateSuccess(id);
      }
    } else {
      _controller.dismissWarning();
    }
  }

  void _navigateSuccess(String accountId) {
    final s = ref.read(addExchangeControllerProvider(widget.accountId));
    if (s.isReplaceMode) {
      context.pop();
    } else {
      context.goNamed(
        RouteNames.exchangeDetail,
        pathParameters: {'id': accountId},
      );
    }
  }

  String _errorMessage(AppLocalizations l, Failure failure) {
    if (failure is UnauthorizedFailure) {
      if (failure.detail != null && failure.detail!.contains('ip')) {
        return l.exchangeAddErrIpRestricted;
      }
      return l.exchangeAddErrCredential;
    }
    if (failure is KeyExpiredFailure) {
      return l.exchangeAddErrCredential;
    }
    if (failure is NetworkFailure) {
      return l.exchangeAddErrNetwork;
    }
    if (failure is ClockSkewFailure) {
      return l.exchangeAddErrClockSkew;
    }
    if (failure is UnsupportedFailure) {
      return l.exchangeAddBitgetNotice;
    }
    return failureText(l, failure);
  }

  List<String> _exchangeGuideSteps(ExchangeId exchange) => switch (exchange) {
    ExchangeId.binance => const [
      '登录币安官网，进入右上角「头像 → 账户 → API 管理」',
      '点击「创建 API」，选择「系统生成 API 密钥」并填写标签（如 OneWallet）',
      '完成安全验证后，只保留「读取」权限，务必不要开启交易和提现',
      '复制 API Key 与 Secret 并粘贴到此处',
    ],
    ExchangeId.okx => const [
      '登录 OKX 官网，进入「个人中心 → API」',
      '点击「申请 V5 API」，权限类型选择「只读」',
      '设置并牢记创建时输入的 Passphrase（口令）',
      '确认未勾选交易和提现权限，复制 Key、Secret 并填入口令',
    ],
    ExchangeId.bybit => const [
      '登录 Bybit 官网，进入「头像 → API 管理」',
      '点击「新建 API 密钥」，选择「系统生成的 API 密钥」',
      '权限类型选择「只读」，确认未勾选任何写入或交易权限',
      '复制 API Key 与 Secret 粘贴到此处',
    ],
    ExchangeId.bitget => const [
      '登录 Bitget 官网，进入「API 管理」',
      '创建 API Key，权限类型选择「只读」，设置 Passphrase',
      '复制 Key、Secret 与 Passphrase 粘贴到此处',
    ],
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final s = ref.watch(addExchangeControllerProvider(widget.accountId));

    // 更换模式下现有账户被异步读出后，更新输入框初始值
    if (s.isReplaceMode &&
        s.existingLoaded &&
        _nameController.text.isEmpty &&
        s.name.isNotEmpty) {
      _nameController.text = s.name;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          s.isReplaceMode ? l.exchangeReplaceKeyTitle : l.exchangeAddTitle,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          if (s.accountMissing)
            OwNotice(
              message: l.exchangeAddErrAccountMissing,
              tone: OwNoticeTone.error,
            )
          else ...[
            _exchangeSelector(context, l, s),
            const SizedBox(height: 12),
            _nameField(context, l, s),
            const SizedBox(height: 12),
            _apiKeyField(context, l, s),
            const SizedBox(height: 12),
            _apiSecretField(context, l, s),
            if (s.needsPassphrase) ...[
              const SizedBox(height: 12),
              _passphraseField(context, l, s),
            ],
            const SizedBox(height: 14),
            OwNotice(
              message: l.exchangeAddSecurityNote,
              tone: OwNoticeTone.info,
            ),
            const SizedBox(height: 12),
            _guideCard(context, l, s),
            if (s.status == AddExchangeStatus.failed && s.failure != null) ...[
              const SizedBox(height: 12),
              OwNotice(
                message: _errorMessage(l, s.failure!),
                tone: OwNoticeTone.error,
              ),
            ],
            const SizedBox(height: 18),
            OwPrimaryButton(
              label: switch (s.status) {
                AddExchangeStatus.verifying => l.exchangeAddVerifying,
                AddExchangeStatus.saving => l.exchangeAddSaving,
                _ => l.exchangeAddTestAndSave,
              },
              onPressed: s.isBusy || !s.isSupported ? null : _testAndSave,
            ),
          ],
        ],
      ),
    );
  }

  Widget _exchangeSelector(
    BuildContext context,
    AppLocalizations l,
    AddExchangeState s,
  ) {
    if (s.isReplaceMode) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OwFieldLabel(l.exchangeAddExchange),
          DecoratedBox(
            decoration: BoxDecoration(
              color: context.ow.surface,
              border: Border.all(color: context.ow.line),
              borderRadius: BorderRadius.circular(OwMetrics.smallRadius),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Text(
                exchangeLabel(l, s.selectedExchange),
                style: OwTextStyles.body.copyWith(color: context.ow.muted),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OwFieldLabel(l.exchangeAddExchange),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final exchange in ExchangeId.values)
              OwChip(
                label: exchange == ExchangeId.bitget
                    ? '${exchangeLabel(l, exchange)} (${l.exchangeAddComingSoon})'
                    : exchangeLabel(l, exchange),
                selected: s.selectedExchange == exchange,
                onTap: s.isBusy ? null : () => _onExchangeChanged(exchange, s),
              ),
          ],
        ),
        if (!s.isSupported) ...[
          const SizedBox(height: 8),
          OwNotice(message: l.exchangeAddBitgetNotice, tone: OwNoticeTone.info),
        ],
      ],
    );
  }

  Widget _nameField(
    BuildContext context,
    AppLocalizations l,
    AddExchangeState s,
  ) {
    if (s.isReplaceMode) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OwFieldLabel(l.exchangeAddAccountName),
          DecoratedBox(
            decoration: BoxDecoration(
              color: context.ow.surface,
              border: Border.all(color: context.ow.line),
              borderRadius: BorderRadius.circular(OwMetrics.smallRadius),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Text(
                s.name,
                style: OwTextStyles.body.copyWith(color: context.ow.muted),
              ),
            ),
          ),
        ],
      );
    }

    final hasError = s.showErrors && !s.nameValid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OwFieldLabel(l.exchangeAddAccountName),
        TextField(
          controller: _nameController,
          onChanged: _controller.setName,
          inputFormatters: [
            LengthLimitingTextInputFormatter(maxAccountNameLength),
          ],
          style: OwTextStyles.body.copyWith(color: context.ow.ink),
          decoration: owInputDecoration(
            context,
            hint: l.exchangeAddAccountNameHint,
            error: hasError,
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              l.exchangeAddAccountNameRequired,
              style: OwTextStyles.caption.copyWith(color: context.ow.down),
            ),
          ),
      ],
    );
  }

  Widget _apiKeyField(
    BuildContext context,
    AppLocalizations l,
    AddExchangeState s,
  ) {
    final hasError = s.showErrors && _apiKeyController.text.trim().isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OwFieldLabel(l.exchangeAddApiKey),
        TextField(
          controller: _apiKeyController,
          autocorrect: false,
          enableSuggestions: false,
          style: OwTextStyles.mono.copyWith(color: context.ow.ink),
          decoration: owInputDecoration(
            context,
            hint: l.exchangeAddApiKeyHint,
            error: hasError,
            suffixIcon: TextButton(
              onPressed: () => _pasteTo(_apiKeyController),
              child: Text(l.exchangeAddPaste),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              l.exchangeAddApiKeyRequired,
              style: OwTextStyles.caption.copyWith(color: context.ow.down),
            ),
          ),
      ],
    );
  }

  Widget _apiSecretField(
    BuildContext context,
    AppLocalizations l,
    AddExchangeState s,
  ) {
    final hasError = s.showErrors && _apiSecretController.text.trim().isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OwFieldLabel(l.exchangeAddApiSecret),
        TextField(
          controller: _apiSecretController,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          style: OwTextStyles.mono.copyWith(color: context.ow.ink),
          decoration: owInputDecoration(
            context,
            hint: l.exchangeAddApiSecretHint,
            error: hasError,
            suffixIcon: TextButton(
              onPressed: () => _pasteTo(_apiSecretController),
              child: Text(l.exchangeAddPaste),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              l.exchangeAddApiSecretRequired,
              style: OwTextStyles.caption.copyWith(color: context.ow.down),
            ),
          ),
      ],
    );
  }

  Widget _passphraseField(
    BuildContext context,
    AppLocalizations l,
    AddExchangeState s,
  ) {
    final hasError = s.showErrors && _passphraseController.text.trim().isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OwFieldLabel(l.exchangeAddPassphrase),
        TextField(
          controller: _passphraseController,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          style: OwTextStyles.mono.copyWith(color: context.ow.ink),
          decoration: owInputDecoration(
            context,
            hint: l.exchangeAddPassphraseHint,
            error: hasError,
            suffixIcon: TextButton(
              onPressed: () => _pasteTo(_passphraseController),
              child: Text(l.exchangeAddPaste),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              l.exchangeAddPassphraseRequired,
              style: OwTextStyles.caption.copyWith(color: context.ow.down),
            ),
          ),
      ],
    );
  }

  Widget _guideCard(
    BuildContext context,
    AppLocalizations l,
    AddExchangeState s,
  ) {
    final steps = _exchangeGuideSteps(s.selectedExchange);
    final entry = ThirdPartyDirectory.builtin().forExchange(s.selectedExchange);
    final guideUrl = entry?.link(LinkKind.apiKeyGuide);
    final mgmtUrl = entry?.link(LinkKind.apiKeyManagement);

    return Material(
      color: context.ow.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: context.ow.line),
        borderRadius: BorderRadius.circular(OwMetrics.cardRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: const ValueKey('exchange-guide-tile'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          title: Text(
            l.exchangeAddGuideTitle,
            style: OwTextStyles.rowTitle.copyWith(color: context.ow.ink),
          ),
          subtitle: Text(
            l.exchangeAddGuideSubtitle,
            style: OwTextStyles.caption.copyWith(color: context.ow.muted),
          ),
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${i + 1}. ',
                      style: OwTextStyles.caption.copyWith(
                        color: context.ow.brand,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        steps[i],
                        style: OwTextStyles.caption.copyWith(
                          color: context.ow.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (guideUrl != null) ...[
              const SizedBox(height: 6),
              OwExternalLink(
                url: Uri.parse(guideUrl),
                label: l.exchangeAddGuideOfficialLink,
              ),
            ],
            if (mgmtUrl != null) ...[
              const SizedBox(height: 4),
              OwExternalLink(
                url: Uri.parse(mgmtUrl),
                label: l.exchangeAddGuideApiManagementLink,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
