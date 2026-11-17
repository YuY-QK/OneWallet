import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../../bootstrap/vault_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/ow_colors.dart';
import '../../../theme/ow_text_styles.dart';
import '../../../widgets/failure_text.dart';
import '../../../widgets/ow_card.dart';
import '../../../widgets/ow_pill.dart';
import '../../../widgets/ow_primary_button.dart';
import '../application/backup_providers.dart';

/// P17 导出加密备份页面。
class BackupExportPage extends ConsumerStatefulWidget {
  const BackupExportPage({super.key, this.includeExchangeCredentials = false});

  final bool includeExchangeCredentials;

  @override
  ConsumerState<BackupExportPage> createState() => _BackupExportPageState();
}

class _BackupExportPageState extends ConsumerState<BackupExportPage> {
  final _masterPasswordController = TextEditingController();
  final _customPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _useMasterPassword = true;
  bool _obscureMaster = true;
  bool _obscureCustom = true;
  bool _obscureConfirm = true;

  bool _isLoading = false;
  String? _errorMessage;

  ExportedBackup? _exportedResult;
  bool _confirmedSaved = false;

  @override
  void dispose() {
    _masterPasswordController.dispose();
    _customPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    final l = AppLocalizations.of(context)!;
    final masterPw = _masterPasswordController.text;

    if (masterPw.isEmpty) {
      setState(() => _errorMessage = l.backupExportMasterPasswordHint);
      return;
    }

    String backupPw;
    if (_useMasterPassword) {
      backupPw = masterPw;
    } else {
      final custom = _customPasswordController.text;
      final confirm = _confirmPasswordController.text;
      if (custom.length < 10) {
        setState(() => _errorMessage = l.backupExportPasswordTooShort);
        return;
      }
      if (custom != confirm) {
        setState(() => _errorMessage = l.backupExportPasswordMismatch);
        return;
      }
      backupPw = custom;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final exportBackup = await ref.read(exportBackupProvider.future);
    final fileHandler = ref.read(backupFileHandlerProvider);

    final masterSensitive = Sensitive(
      Uint8List.fromList(utf8.encode(masterPw)),
    );
    final backupSensitive = Sensitive(
      Uint8List.fromList(utf8.encode(backupPw)),
    );

    try {
      final res = await exportBackup(
        masterCredential: PasswordCredential(masterSensitive),
        backupPassword: backupSensitive,
        includeExchangeCredentials: widget.includeExchangeCredentials,
      );

      if (!mounted) return;

      if (res case Err(:final failure)) {
        setState(() {
          _isLoading = false;
          _errorMessage = switch (failure) {
            WrongPasswordFailure() =>
              l.securityChangeMasterPasswordWrongCurrent,
            _ => failureText(l, failure),
          };
        });
        return;
      }

      final exported = (res as Ok<ExportedBackup>).value;

      // 调起系统分享面板或保存
      final shareSuccess = await fileHandler.shareFile(
        bytes: exported.bytes,
        filename: exported.suggestedFileName,
      );

      if (!mounted) return;
      if (!shareSuccess) {
        setState(() {
          _isLoading = false;
          _errorMessage = l.backupExportShareFailed;
        });
        return;
      }

      setState(() {
        _isLoading = false;
        _exportedResult = exported;
      });
    } finally {
      masterSensitive.wipe();
      backupSensitive.wipe();
    }
  }

  Future<void> _confirmSaved() async {
    final confirmSaved = ref.read(confirmBackupSavedProvider);
    await confirmSaved();
    if (!mounted) return;
    setState(() => _confirmedSaved = true);
    final l = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l.backupExportDoneNotice)));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.ow;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: Text(l.backupExportTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: OwPill(
                label: l.backupSensitiveBadge,
                tone: OwPillTone.orange,
              ),
            ),
          ),
        ],
      ),
      body: _exportedResult != null
          ? _buildSuccessView(context, l, colors)
          : _buildExportForm(context, l, colors),
    );
  }

  Widget _buildExportForm(
    BuildContext context,
    AppLocalizations l,
    OwColors colors,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // 1. 输入主密码
        OwCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.backupExportMasterPasswordTitle,
                style: OwTextStyles.body.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l.backupExportMasterPasswordDesc,
                style: OwTextStyles.caption.copyWith(color: colors.muted),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _masterPasswordController,
                obscureText: _obscureMaster,
                decoration: InputDecoration(
                  hintText: l.backupExportMasterPasswordHint,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureMaster
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () {
                      setState(() => _obscureMaster = !_obscureMaster);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. 设置备份密码
        OwCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.backupExportPasswordTypeTitle,
                style: OwTextStyles.body.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.ink,
                ),
              ),
              const SizedBox(height: 12),
              RadioGroup<bool>(
                groupValue: _useMasterPassword,
                onChanged: (val) {
                  if (val != null) setState(() => _useMasterPassword = val);
                },
                child: Column(
                  children: [
                    RadioListTile<bool>(
                      title: Text(
                        l.backupExportUseMasterPassword,
                        style: OwTextStyles.body.copyWith(color: colors.ink),
                      ),
                      value: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<bool>(
                      title: Text(
                        l.backupExportUseCustomPassword,
                        style: OwTextStyles.body.copyWith(color: colors.ink),
                      ),
                      value: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              if (!_useMasterPassword) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _customPasswordController,
                  obscureText: _obscureCustom,
                  decoration: InputDecoration(
                    hintText: l.backupExportCustomPasswordHint,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureCustom
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () {
                        setState(() => _obscureCustom = !_obscureCustom);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    hintText: l.backupExportCustomPasswordConfirmHint,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () {
                        setState(() => _obscureConfirm = !_obscureConfirm);
                      },
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                l.backupExportAsciiNotice,
                style: OwTextStyles.caption.copyWith(
                  color: colors.muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (_errorMessage != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Text(
              _errorMessage!,
              style: OwTextStyles.caption.copyWith(color: colors.warn),
            ),
          ),
          const SizedBox(height: 8),
        ],

        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          )
        else
          OwPrimaryButton(label: l.backupExportStartButton, onPressed: _export),
      ],
    );
  }

  Widget _buildSuccessView(
    BuildContext context,
    AppLocalizations l,
    OwColors colors,
  ) {
    final exported = _exportedResult!;
    final summary = exported.summary;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      children: [
        Center(
          child: Column(
            children: [
              Icon(Icons.check_circle_rounded, color: colors.up, size: 56),
              const SizedBox(height: 12),
              Text(
                l.backupExportSuccessTitle,
                style: OwTextStyles.title.copyWith(color: colors.ink),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        OwCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                exported.suggestedFileName,
                style: OwTextStyles.mono.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Divider(color: colors.line, height: 1),
              const SizedBox(height: 12),
              Text(
                '${summary.accountsCount} 个账户 · ${summary.addressesCount} 个地址 · ${summary.vaultItemsCount} 个密钥',
                style: OwTextStyles.body.copyWith(color: colors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OwCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, color: colors.brand, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l.backupExportSaveAdvice,
                  style: OwTextStyles.body.copyWith(
                    color: colors.muted,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        OwPrimaryButton(
          label: l.backupExportSavedButton,
          onPressed: _confirmedSaved ? null : _confirmSaved,
        ),
      ],
    );
  }
}
