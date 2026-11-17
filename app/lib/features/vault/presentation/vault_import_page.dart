import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:ow_vault/ow_vault.dart';
import 'package:ow_vault/private_key_format.dart';

import '../../../bootstrap/foundation_providers.dart';
import '../../../bootstrap/ui_services.dart';
import '../../../bootstrap/vault_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/ow_colors.dart';
import '../../../theme/ow_text_styles.dart';
import '../../../widgets/failure_text.dart';
import '../../../widgets/ow_card.dart';
import '../../../widgets/ow_input_decoration.dart';
import '../../../widgets/ow_notice.dart';
import '../../../widgets/ow_primary_button.dart';
import '../utils/bip39_words.dart';

/// P14 导入密钥页面（助记词或私钥）。
class VaultImportPage extends ConsumerStatefulWidget {
  const VaultImportPage({super.key, this.linkToAccountId});

  /// 预选要关联的钱包账户 ID（从 P11 或 P07 跳转来时携带）。
  final String? linkToAccountId;

  @override
  ConsumerState<VaultImportPage> createState() => _VaultImportPageState();
}

class _VaultImportPageState extends ConsumerState<VaultImportPage>
    with WidgetsBindingObserver {
  VaultItemKind _kind = VaultItemKind.mnemonic;

  late final TextEditingController _nameController;
  late final TextEditingController _passphraseController;
  late final TextEditingController _privateKeyController;

  // 助记词单元格控制器与焦点
  static const _maxWords = 24;
  late final List<TextEditingController> _wordControllers;
  late final List<FocusNode> _wordFocusNodes;

  int _wordCount = 12;
  int? _focusedWordIndex;
  List<String> _currentSuggestions = const [];

  bool _showPassphrase = false;
  bool _obscurePassphrase = true;
  bool _obscurePrivateKey = true;

  ChainFamily _family = ChainFamily.evm;
  String? _selectedAccountId;
  bool _isSubmitting = false;
  late final ScreenGuard _screenGuard;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _screenGuard = ref.read(screenGuardProvider);
    _screenGuard.enable();

    _selectedAccountId = widget.linkToAccountId;
    _nameController = TextEditingController()..addListener(_onFieldChanged);
    _passphraseController = TextEditingController()
      ..addListener(_onFieldChanged);
    _privateKeyController = TextEditingController()
      ..addListener(_onFieldChanged);

    _wordControllers = List.generate(
      _maxWords,
      (i) => TextEditingController()..addListener(() => _onWordChanged(i)),
    );
    _wordFocusNodes = List.generate(
      _maxWords,
      (i) => FocusNode()..addListener(() => _onFocusChanged(i)),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // 离开页面时恢复截屏设置
    _screenGuard.disable();

    _nameController.dispose();
    _passphraseController.dispose();
    _privateKeyController.dispose();

    for (final c in _wordControllers) {
      c.dispose();
    }
    for (final f in _wordFocusNodes) {
      f.dispose();
    }

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // R26 & PRD 第 10 节：导入助记词时 app 被切到后台，清空输入
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      _wipeInputs();
    }
  }

  void _wipeInputs() {
    for (final c in _wordControllers) {
      c.clear();
    }
    _passphraseController.clear();
    _privateKeyController.clear();
    setState(() {
      _currentSuggestions = const [];
    });
  }

  void _onFieldChanged() {
    setState(() {});
  }

  void _onWordChanged(int index) {
    if (_focusedWordIndex == index) {
      final text = _wordControllers[index].text.trim().toLowerCase();
      setState(() {
        _currentSuggestions = Bip39Words.suggestions(text);
      });
    } else {
      setState(() {});
    }
  }

  void _onFocusChanged(int index) {
    if (_wordFocusNodes[index].hasFocus) {
      setState(() {
        _focusedWordIndex = index;
        final text = _wordControllers[index].text.trim().toLowerCase();
        _currentSuggestions = Bip39Words.suggestions(text);
      });
    } else if (_focusedWordIndex == index) {
      setState(() {
        _focusedWordIndex = null;
        _currentSuggestions = const [];
      });
    }
  }

  void _selectSuggestion(String word) {
    final idx = _focusedWordIndex;
    if (idx == null) return;

    _wordControllers[idx].text = word;
    if (idx + 1 < _wordCount) {
      _wordFocusNodes[idx + 1].requestFocus();
    } else {
      _wordFocusNodes[idx].unfocus();
    }
  }

  Future<void> _pasteFullPhrase() async {
    final l = AppLocalizations.of(context)!;
    final text = await ref.read(clipboardReaderProvider)();
    if (text == null || text.trim().isEmpty) return;

    final tokens = text
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    const allowedCounts = {12, 15, 18, 21, 24};
    if (!allowedCounts.contains(tokens.length)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.vaultImportPasteInvalid)));
      return;
    }

    setState(() {
      _wordCount = tokens.length;
      for (var i = 0; i < tokens.length; i++) {
        _wordControllers[i].text = tokens[i];
      }
      for (var i = tokens.length; i < _maxWords; i++) {
        _wordControllers[i].clear();
      }
    });
  }

  String _currentMnemonicString() {
    return [
      for (var i = 0; i < _wordCount; i++)
        _wordControllers[i].text.trim().toLowerCase(),
    ].join(' ');
  }

  bool _isMnemonicValid() {
    for (var i = 0; i < _wordCount; i++) {
      final w = _wordControllers[i].text.trim().toLowerCase();
      if (w.isEmpty || !Bip39Words.isValid(w)) return false;
    }
    return AddressDeriver.isValidMnemonic(_currentMnemonicString());
  }

  bool _isPrivateKeyValid() {
    final keyText = _privateKeyController.text.trim();
    if (keyText.isEmpty) return false;
    final sensitive = Sensitive(Uint8List.fromList(utf8.encode(keyText)));
    try {
      final res = PrivateKeyFormat.normalize(_family, sensitive);
      if (res case Ok(:final value)) {
        value.wipe();
        return true;
      }
      return false;
    } finally {
      sensitive.wipe();
    }
  }

  Future<VaultCredential?> _authenticateForImport() async {
    final l = AppLocalizations.of(context)!;
    final caps = ref.read(platformCapabilitiesProvider);
    final settings = await ref.read(settingsRepositoryProvider).watch().first;

    // 如果启用了生物识别且设备支持，先尝试生物识别
    if (caps.hardwareKeystore && settings.vaultBiometrics) {
      final cred = BiometricCredential(reason: l.lockBiometricReason);
      return cred;
    }

    // 否则弹出主密码输入对话框
    if (!mounted) return null;
    final passwordController = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (ctx) {
        var obscure = true;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(l.vaultImportVerifyPasswordTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.vaultImportVerifyPasswordMessage,
                  style: OwTextStyles.caption.copyWith(color: ctx.ow.muted),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: obscure,
                  autofocus: true,
                  decoration: owInputDecoration(
                    ctx,
                    hint: l.vaultSetupPasswordHint,
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
                onPressed: () {
                  final text = passwordController.text;
                  if (text.isNotEmpty) {
                    Navigator.of(ctx).pop(text);
                  }
                },
                child: Text(l.vaultImportVerifyPasswordConfirm),
              ),
            ],
          ),
        );
      },
    );

    passwordController.clear();
    if (password == null || password.isEmpty) return null;

    return PasswordCredential(
      Sensitive(Uint8List.fromList(utf8.encode(password))),
    );
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final credential = await _authenticateForImport();
    if (credential == null) return;

    setState(() => _isSubmitting = true);

    VaultItemInput input;
    Sensitive? rawSensitive;
    Sensitive? rawPassphrase;

    if (_kind == VaultItemKind.mnemonic) {
      final mText = _currentMnemonicString();
      rawSensitive = Sensitive(Uint8List.fromList(utf8.encode(mText)));
      final ppText = _passphraseController.text;
      if (_showPassphrase && ppText.isNotEmpty) {
        rawPassphrase = Sensitive(Uint8List.fromList(utf8.encode(ppText)));
      }
      input = MnemonicInput(mnemonic: rawSensitive, passphrase: rawPassphrase);
    } else {
      final pkText = _privateKeyController.text.trim();
      rawSensitive = Sensitive(Uint8List.fromList(utf8.encode(pkText)));
      input = PrivateKeyInput(family: _family, key: rawSensitive);
    }

    try {
      final usecase = await ref.read(importVaultItemProvider.future);
      final res = await usecase(
        credential: credential,
        name: name,
        input: input,
        linkToAccountId: _selectedAccountId,
      );

      if (!mounted) return;

      if (res case Ok()) {
        _wipeInputs();
        _nameController.clear();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.vaultImportSuccess)));
        // 跳转到 P16 派生地址页（如果存在）或直接返回
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      } else if (res case Err(:final failure)) {
        if (failure is ValidationFailure &&
            failure.detail != 'name_invalid' &&
            failure.detail != 'invalid_account') {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l.vaultImportDuplicateError)));
        } else {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(failureText(l, failure))));
        }
      }
    } finally {
      rawSensitive.wipe();
      rawPassphrase?.wipe();
      if (credential is PasswordCredential) {
        credential.password.wipe();
      }
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.ow;

    final nameValid =
        _nameController.text.trim().isNotEmpty &&
        _nameController.text.trim().length <= 30;
    final contentValid = _kind == VaultItemKind.mnemonic
        ? _isMnemonicValid()
        : _isPrivateKeyValid();
    final canSubmit = nameValid && contentValid && !_isSubmitting;

    final accountsAsync = ref.watch(accountRepositoryProvider).watchAll();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.vaultImportTitle),
            const SizedBox(width: 6),
            Icon(Icons.lock_rounded, size: 16, color: c.muted),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 类型分段切换
              SegmentedButton<VaultItemKind>(
                segments: [
                  ButtonSegment(
                    value: VaultItemKind.mnemonic,
                    label: Text(l.vaultImportTypeMnemonic),
                    icon: const Icon(Icons.grid_view_rounded, size: 18),
                  ),
                  ButtonSegment(
                    value: VaultItemKind.privateKey,
                    label: Text(l.vaultImportTypePrivateKey),
                    icon: const Icon(Icons.key_rounded, size: 18),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: (set) {
                  setState(() {
                    _kind = set.first;
                    _wipeInputs();
                  });
                },
              ),
              const SizedBox(height: 20),

              // 条目名称
              OwFieldLabel(l.vaultImportNameLabel),
              TextField(
                key: const Key('vault_import_name_field'),
                controller: _nameController,
                maxLength: 30,
                decoration: owInputDecoration(
                  context,
                  hint: l.vaultImportNameHint,
                ),
              ),
              const SizedBox(height: 16),

              if (_kind == VaultItemKind.mnemonic) ...[
                // 词数选择与整段粘贴
                Row(
                  children: [
                    OwFieldLabel(l.vaultImportWordCountLabel),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _pasteFullPhrase,
                      icon: const Icon(Icons.content_paste_rounded, size: 16),
                      label: Text(l.vaultImportPasteFullPhrase),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  children: [12, 15, 18, 21, 24].map((count) {
                    final isSel = _wordCount == count;
                    return ChoiceChip(
                      label: Text('$count 词'),
                      selected: isSel,
                      onSelected: (sel) {
                        if (sel) {
                          setState(() {
                            _wordCount = count;
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // 词表联想候选栏
                if (_currentSuggestions.isNotEmpty) ...[
                  OwCard(
                    child: SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _currentSuggestions.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (ctx, idx) {
                          final word = _currentSuggestions[idx];
                          return ActionChip(
                            label: Text(word),
                            onPressed: () => _selectSuggestion(word),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // 助记词词格网格 (3列)
                _buildMnemonicGrid(c),
                const SizedBox(height: 12),

                // 助记词校验和提示
                if (_allWordsFilled() && !_isMnemonicValid()) ...[
                  OwNotice(
                    tone: OwNoticeTone.error,
                    message: l.vaultImportMnemonicChecksumFailed,
                  ),
                  const SizedBox(height: 12),
                ],

                // 高级：Passphrase 折叠区
                Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: Text(
                      l.vaultImportAdvancedPassphrase,
                      style: OwTextStyles.caption.copyWith(color: c.muted),
                    ),
                    tilePadding: EdgeInsets.zero,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TextField(
                          key: const Key('vault_import_passphrase_field'),
                          controller: _passphraseController,
                          obscureText: _obscurePassphrase,
                          enableSuggestions: false,
                          autocorrect: false,
                          decoration: owInputDecoration(
                            context,
                            hint: l.vaultImportPassphraseHint,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassphrase
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassphrase = !_obscurePassphrase,
                              ),
                            ),
                          ),
                          onChanged: (_) => _showPassphrase = true,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // 私钥输入部分
                OwFieldLabel(l.vaultImportChainFamilyLabel),
                Wrap(
                  spacing: 8,
                  children:
                      [
                        (ChainFamily.evm, 'EVM'),
                        (ChainFamily.bitcoin, 'Bitcoin (WIF)'),
                        (ChainFamily.solana, 'Solana'),
                        (ChainFamily.tron, 'Tron'),
                      ].map((pair) {
                        final (fam, label) = pair;
                        final isSel = _family == fam;
                        return ChoiceChip(
                          label: Text(label),
                          selected: isSel,
                          onSelected: (sel) {
                            if (sel) setState(() => _family = fam);
                          },
                        );
                      }).toList(),
                ),
                const SizedBox(height: 16),

                OwFieldLabel(l.vaultImportPrivateKeyLabel),
                TextField(
                  key: const Key('vault_import_private_key_field'),
                  controller: _privateKeyController,
                  obscureText: _obscurePrivateKey,
                  enableSuggestions: false,
                  autocorrect: false,
                  keyboardType: TextInputType.visiblePassword,
                  decoration: owInputDecoration(
                    context,
                    hint: _privateKeyHint(l),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePrivateKey
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () => setState(
                        () => _obscurePrivateKey = !_obscurePrivateKey,
                      ),
                    ),
                  ),
                ),
                if (_privateKeyController.text.isNotEmpty &&
                    !_isPrivateKeyValid()) ...[
                  const SizedBox(height: 6),
                  Text(
                    l.vaultImportPrivateKeyFormatError,
                    style: OwTextStyles.caption.copyWith(color: c.down),
                  ),
                ],
              ],
              const SizedBox(height: 20),

              // 关联账户（可选）
              OwFieldLabel(l.vaultImportLinkAccountLabel),
              StreamBuilder<List<Account>>(
                stream: accountsAsync,
                builder: (ctx, snapshot) {
                  final wallets = (snapshot.data ?? [])
                      .where((a) => a.type == AccountType.wallet)
                      .toList();
                  return DropdownButtonFormField<String?>(
                    initialValue: _selectedAccountId,
                    isExpanded: true,
                    decoration: owInputDecoration(context),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(l.vaultImportLinkAccountNone),
                      ),
                      ...wallets.map(
                        (w) => DropdownMenuItem<String?>(
                          value: w.id,
                          child: Text(w.name),
                        ),
                      ),
                    ],
                    onChanged: (val) =>
                        setState(() => _selectedAccountId = val),
                  );
                },
              ),
              const SizedBox(height: 32),

              // 提交按钮
              if (_isSubmitting) ...[
                const Center(child: CircularProgressIndicator()),
              ] else ...[
                OwPrimaryButton(
                  label: l.vaultImportSubmitButton,
                  onPressed: canSubmit ? _submit : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool _allWordsFilled() {
    for (var i = 0; i < _wordCount; i++) {
      if (_wordControllers[i].text.trim().isEmpty) return false;
    }
    return true;
  }

  String _privateKeyHint(AppLocalizations l) {
    return switch (_family) {
      ChainFamily.evm => l.vaultImportPrivateKeyHintEvm,
      ChainFamily.bitcoin => l.vaultImportPrivateKeyHintBtc,
      ChainFamily.solana => l.vaultImportPrivateKeyHintSol,
      ChainFamily.tron => l.vaultImportPrivateKeyHintTrx,
    };
  }

  Widget _buildMnemonicGrid(OwColors c) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _wordCount,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 2.2,
      ),
      itemBuilder: (ctx, index) {
        final controller = _wordControllers[index];
        final focusNode = _wordFocusNodes[index];
        final word = controller.text.trim().toLowerCase();
        final isKnown = word.isEmpty || Bip39Words.isValid(word);

        return Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isKnown ? c.line : c.down, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Row(
            children: [
              Text(
                '${index + 1}',
                style: OwTextStyles.mono.copyWith(color: c.muted, fontSize: 10),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  key: Key('mnemonic_word_$index'),
                  controller: controller,
                  focusNode: focusNode,
                  style: OwTextStyles.body.copyWith(
                    color: isKnown ? c.ink : c.down,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  enableSuggestions: false,
                  autocorrect: false,
                  textInputAction: index + 1 < _wordCount
                      ? TextInputAction.next
                      : TextInputAction.done,
                  onSubmitted: (_) {
                    if (index + 1 < _wordCount) {
                      _wordFocusNodes[index + 1].requestFocus();
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
