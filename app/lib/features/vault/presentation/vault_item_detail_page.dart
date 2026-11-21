import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:ow_vault/ow_vault.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../bootstrap/foundation_providers.dart';
import '../../../bootstrap/vault_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../router/route_names.dart';
import '../../../theme/ow_colors.dart';
import '../../../theme/ow_text_styles.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/failure_text.dart';
import '../../../widgets/ow_card.dart';
import '../../../widgets/ow_danger_button.dart';
import '../../../widgets/ow_input_decoration.dart';
import '../../../widgets/ow_mnemonic_grid.dart';
import '../../../widgets/ow_notice.dart';
import '../../../widgets/ow_row.dart';
import '../../../widgets/ow_veil.dart';

/// P15 密钥详情页面。
class VaultItemDetailPage extends ConsumerStatefulWidget {
  const VaultItemDetailPage({super.key, required this.itemId});

  final String itemId;

  @override
  ConsumerState<VaultItemDetailPage> createState() =>
      _VaultItemDetailPageState();
}

class _VaultItemDetailPageState extends ConsumerState<VaultItemDetailPage>
    with WidgetsBindingObserver {
  late final ScreenGuard _screenGuard;
  StreamSubscription<bool>? _captureSub;
  bool _isCaptured = false;

  // 敏感明文仅存放在局部状态中，离开/倒计时结束/退后台即 wipe 并清空
  VaultItemSecret? _secret;
  List<String>? _mnemonicWords;
  String? _passphrase;
  String? _privateKeyText;
  bool _isRevealed = false;
  bool _showQr = false;

  int _countdown = 60;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _screenGuard = ref.read(screenGuardProvider);
    _screenGuard.enable();
    _captureSub = _screenGuard.captureActive.listen((captured) {
      if (!mounted) return;
      setState(() {
        _isCaptured = captured;
        if (captured) {
          _hideSecret();
        }
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // 退后台立即遮挡并抹除敏感数据 (PRD R25/R28)
      _hideSecret();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideSecret();
    _captureSub?.cancel();
    _screenGuard.disable();
    super.dispose();
  }

  void _hideSecret() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _countdown = 60;
    _isRevealed = false;
    _showQr = false;
    _mnemonicWords = null;
    _passphrase = null;
    _privateKeyText = null;
    _secret?.wipe();
    _secret = null;
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdown = 60;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _countdown--;
        if (_countdown <= 0) {
          _hideSecret();
        }
      });
    });
  }

  Future<VaultCredential?> _authenticate() async {
    final l = AppLocalizations.of(context)!;
    final caps = ref.read(platformCapabilitiesProvider);
    final settings = await ref.read(settingsRepositoryProvider).watch().first;

    // 若启用了生物识别且设备支持，先尝试生物识别
    if (caps.hardwareKeystore && settings.vaultBiometrics) {
      return BiometricCredential(reason: l.lockBiometricReason);
    }

    // 否则弹出主密码输入对话框
    return _promptMasterPasswordDialog(
      title: l.vaultImportVerifyPasswordTitle,
      message: l.vaultItemVeilMessage,
    );
  }

  Future<PasswordCredential?> _promptMasterPasswordDialog({
    required String title,
    required String message,
  }) async {
    if (!mounted) return null;
    final l = AppLocalizations.of(context)!;
    final passwordController = TextEditingController();
    var obscure = true;

    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
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
      ),
    );

    passwordController.clear();
    if (password == null || password.isEmpty) return null;

    return PasswordCredential(
      Sensitive(Uint8List.fromList(utf8.encode(password))),
    );
  }

  Future<void> _reveal() async {
    if (_isCaptured) {
      final l = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.vaultItemRecordingWarning)));
      return;
    }

    final l = AppLocalizations.of(context)!;
    var credential = await _authenticate();
    if (credential == null) return;

    try {
      final usecase = await ref.read(revealVaultItemProvider.future);
      var res = await usecase(itemId: widget.itemId, credential: credential);

      // 若生物识别解包失败（如 R30 指纹变更或不可用），回退到主密码弹窗
      if (res case Err(:final failure)) {
        if (failure is BiometricUnavailableFailure ||
            failure is ValidationFailure) {
          if (!mounted) return;
          final pwCred = await _promptMasterPasswordDialog(
            title: l.vaultImportVerifyPasswordTitle,
            message: l.vaultItemVeilMessage,
          );
          if (pwCred == null) return;
          credential = pwCred;
          res = await usecase(itemId: widget.itemId, credential: pwCred);
        }
      }

      if (!mounted) return;

      if (res case Ok(:final value)) {
        setState(() {
          _hideSecret();
          _secret = value;
          if (value is MnemonicSecret) {
            _mnemonicWords = value.mnemonic.use(
              (b) => utf8.decode(b).split(' '),
            );
            _passphrase = value.passphrase?.use(utf8.decode);
          } else if (value is PrivateKeySecret) {
            _privateKeyText = value.key.use(utf8.decode);
          }
          _isRevealed = true;
          _startCountdown();
        });
      } else if (res case Err(:final failure)) {
        if (failure is LockedOutFailure) {
          final remaining = failure.until.difference(DateTime.now().toUtc());
          final mins = remaining.inMinutes;
          final secs = remaining.inSeconds % 60;
          final timeStr = mins > 0 ? '$mins 分 $secs 秒' : '$secs 秒';
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l.lockCountdown(timeStr))));
        } else if (failure is WrongPasswordFailure) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l.lockWrongPin)));
        } else {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(failureText(l, failure))));
        }
      }
    } finally {
      if (credential is PasswordCredential) {
        credential.password.wipe();
      }
    }
  }

  Future<void> _deleteItem() async {
    final l = AppLocalizations.of(context)!;
    final passwordController = TextEditingController();
    var agreeRisk = false;
    var obscure = true;

    final confirmedPassword = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l.vaultItemDeleteDialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.vaultItemDeleteDialogMessage,
                style: OwTextStyles.body.copyWith(color: ctx.ow.muted),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: agreeRisk,
                onChanged: (val) =>
                    setDialogState(() => agreeRisk = val ?? false),
                title: Text(
                  l.vaultItemDeleteAgreeRisk,
                  style: OwTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: obscure,
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
              style: FilledButton.styleFrom(backgroundColor: ctx.ow.down),
              onPressed: agreeRisk && passwordController.text.isNotEmpty
                  ? () => Navigator.of(ctx).pop(passwordController.text)
                  : null,
              child: Text(l.vaultItemDeleteConfirm),
            ),
          ],
        ),
      ),
    );

    passwordController.clear();
    if (confirmedPassword == null || confirmedPassword.isEmpty) return;

    final sensitivePw = Sensitive(
      Uint8List.fromList(utf8.encode(confirmedPassword)),
    );
    try {
      final deleteUsecase = await ref.read(deleteVaultItemProvider.future);
      final res = await deleteUsecase(
        itemId: widget.itemId,
        credential: PasswordCredential(sensitivePw),
      );

      if (!mounted) return;

      if (res case Ok()) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.vaultItemDeleteSuccess)));
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      } else if (res case Err(:final failure)) {
        if (failure is WrongPasswordFailure) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l.lockWrongPin)));
        } else if (failure is LockedOutFailure) {
          final remaining = failure.until.difference(DateTime.now().toUtc());
          final mins = remaining.inMinutes;
          final secs = remaining.inSeconds % 60;
          final timeStr = mins > 0 ? '$mins 分 $secs 秒' : '$secs 秒';
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l.lockCountdown(timeStr))));
        } else {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(failureText(l, failure))));
        }
      }
    } finally {
      sensitivePw.wipe();
    }
  }

  Future<void> _editName(VaultItemMeta meta) async {
    final l = AppLocalizations.of(context)!;
    final nameController = TextEditingController(text: meta.name);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.vaultItemEditNameTitle),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: owInputDecoration(ctx, hint: l.vaultItemEditNameLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text(l.vaultImportVerifyPasswordCancel),
          ),
          FilledButton(
            onPressed: () {
              final text = nameController.text.trim();
              if (text.isNotEmpty && text.length <= 30) {
                Navigator.of(ctx).pop(text);
              }
            },
            child: Text(l.vaultImportVerifyPasswordConfirm),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty) return;

    final updatedMeta = VaultItemMeta(
      id: meta.id,
      name: newName,
      kind: meta.kind,
      hasPassphrase: meta.hasPassphrase,
      wordCount: meta.wordCount,
      family: meta.family,
      fingerprint: meta.fingerprint,
      createdAt: meta.createdAt,
    );

    await ref.read(vaultMetaRepositoryProvider).upsert(updatedMeta);
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
    final addressesStream = ref.watch(addressRepositoryProvider).watchAll();

    return StreamBuilder<VaultItemMeta?>(
      stream: metaStream,
      builder: (context, metaSnapshot) {
        final meta = metaSnapshot.data;
        if (meta == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l.vaultItemDetailTitle)),
            body: const Center(
              child: EmptyState(
                icon: Icons.vpn_key_off_outlined,
                title: '条目不存在',
                body: '',
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(meta.name),
                const SizedBox(width: 6),
                Icon(Icons.lock_rounded, size: 16, color: c.muted),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _editName(meta),
              ),
            ],
          ),
          body: StreamBuilder<List<Account>>(
            stream: accountsStream,
            builder: (context, accSnapshot) {
              final accounts = accSnapshot.data ?? [];
              final linkedAccount = accounts
                  .where((a) => a.vaultItemId == widget.itemId)
                  .firstOrNull;

              return StreamBuilder<List<WatchAddress>>(
                stream: addressesStream,
                builder: (context, addrSnapshot) {
                  final allAddresses = addrSnapshot.data ?? [];
                  final derivedCount = linkedAccount != null
                      ? allAddresses
                            .where((a) => a.accountId == linkedAccount.id)
                            .length
                      : 0;

                  return ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    children: [
                      if (_isCaptured) ...[
                        OwNotice(
                          message: l.vaultItemRecordingWarning,
                          tone: OwNoticeTone.warn,
                        ),
                        const SizedBox(height: 12),
                      ],

                      // 1. 基本信息卡片
                      OwCard(
                        child: Column(
                          children: [
                            _buildKvRow(
                              l.vaultItemType,
                              meta.kind == VaultItemKind.mnemonic
                                  ? '${l.vaultItemKindMnemonic} · ${meta.wordCount ?? 12} 词'
                                  : '${l.vaultItemKindPrivateKey} · ${meta.family?.name.toUpperCase() ?? 'EVM'}',
                              c,
                            ),
                            const Divider(height: 14),
                            _buildKvRow(
                              l.vaultItemCreatedAt,
                              '${meta.createdAt.year}-${meta.createdAt.month.toString().padLeft(2, '0')}-${meta.createdAt.day.toString().padLeft(2, '0')}',
                              c,
                              isNum: true,
                            ),
                            const Divider(height: 14),
                            _buildKvRow(
                              l.vaultItemLinkedAccount,
                              linkedAccount?.name ??
                                  l.vaultItemLinkedAccountNone,
                              c,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 2. 明文展示区（遮挡或展开）
                      if (!_isRevealed)
                        OwVeil(
                          onReveal: _reveal,
                          message: l.vaultItemVeilMessage,
                          buttonText: l.vaultItemVeilAction,
                        )
                      else ...[
                        if (meta.kind == VaultItemKind.mnemonic &&
                            _mnemonicWords != null) ...[
                          if (!_showQr)
                            OwMnemonicGrid(words: _mnemonicWords!)
                          else
                            _buildQrCard(_mnemonicWords!.join(' ')),
                          if (_passphrase != null &&
                              _passphrase!.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            OwCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l.vaultItemPassphraseLabel,
                                    style: OwTextStyles.caption.copyWith(
                                      color: c.muted,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _passphrase!,
                                    style: OwTextStyles.mono.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ] else if (meta.kind == VaultItemKind.privateKey &&
                            _privateKeyText != null) ...[
                          if (!_showQr)
                            OwCard(
                              child: Text(
                                _privateKeyText!,
                                style: OwTextStyles.mono.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            )
                          else
                            _buildQrCard(_privateKeyText!),
                        ],

                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text(
                              l.vaultItemCountdown(_countdown),
                              style: OwTextStyles.caption.copyWith(
                                color: c.muted,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () =>
                                  setState(() => _showQr = !_showQr),
                              child: Text(
                                _showQr
                                    ? l.vaultItemHideQrCode
                                    : l.vaultItemShowQrCode,
                              ),
                            ),
                            OutlinedButton(
                              onPressed: () => setState(_hideSecret),
                              child: Text(l.vaultItemHideAction),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),

                      // 3. 已派生地址入口
                      OwRow(
                        title: l.vaultItemDerivedAddresses,
                        subtitle: l.vaultItemDerivedAddressesCount(
                          derivedCount,
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: c.muted,
                        ),
                        onTap: () {
                          context.pushNamed(
                            RouteNames.vaultDerive,
                            pathParameters: {'id': widget.itemId},
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // 4. 危险区：删除此密钥
                      OwDangerButton(
                        label: l.vaultItemDeleteButton,
                        onPressed: _deleteItem,
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          l.vaultItemFooterNote,
                          style: OwTextStyles.caption.copyWith(color: c.muted),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildKvRow(
    String label,
    String value,
    OwColors c, {
    bool isNum = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: OwTextStyles.body.copyWith(color: c.muted)),
        Text(
          value,
          style: isNum
              ? OwTextStyles.mono.copyWith(fontWeight: FontWeight.w500)
              : OwTextStyles.body.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildQrCard(String text) {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        padding: const EdgeInsets.all(12),
        child: QrImageView(
          data: text,
          size: 200,
          backgroundColor: Colors.white,
        ),
      ),
    );
  }
}
