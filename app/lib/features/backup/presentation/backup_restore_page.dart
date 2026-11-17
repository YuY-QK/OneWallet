import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../../bootstrap/vault_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../../theme/ow_colors.dart';
import '../../../theme/ow_text_styles.dart';
import '../../../widgets/failure_text.dart';
import '../../../widgets/ow_card.dart';
import '../../../widgets/ow_pill.dart';
import '../../../widgets/ow_primary_button.dart';
import '../../../widgets/ow_secondary_button.dart';
import '../application/backup_providers.dart';

/// P17 / P01 恢复加密备份页面。
class BackupRestorePage extends ConsumerStatefulWidget {
  const BackupRestorePage({super.key, this.mode = RestoreMode.merge});

  final RestoreMode mode;

  @override
  ConsumerState<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends ConsumerState<BackupRestorePage> {
  SelectedBackupFile? _selectedFile;
  final _backupPasswordController = TextEditingController();
  final _localMasterPasswordController = TextEditingController();
  final _newMasterPasswordController = TextEditingController();

  bool _obscureBackup = true;
  bool _obscureLocalMaster = true;
  bool _obscureNewMaster = true;
  bool _sameAsBackupPassword = true;

  bool _isLoading = false;
  String? _errorMessage;

  PendingRestore? _pendingRestore;
  RestoreReport? _restoreReport;

  @override
  void dispose() {
    _backupPasswordController.dispose();
    _localMasterPasswordController.dispose();
    _newMasterPasswordController.dispose();
    _pendingRestore?.dispose();
    _pendingRestore = null;
    super.dispose();
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }

  Future<void> _pickFile() async {
    final fileHandler = ref.read(backupFileHandlerProvider);
    final picked = await fileHandler.pickBackupFile();
    if (picked != null && mounted) {
      setState(() {
        _selectedFile = picked;
        _errorMessage = null;
      });
    }
  }

  Future<void> _parseBackup() async {
    final l = AppLocalizations.of(context)!;
    if (_selectedFile == null) {
      setState(() => _errorMessage = l.backupRestoreSelectFile);
      return;
    }
    final pw = _backupPasswordController.text;
    if (pw.isEmpty) {
      setState(() => _errorMessage = l.backupRestorePasswordHint);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final openBackup = await ref.read(openBackupProvider.future);
    final sensitivePw = Sensitive(Uint8List.fromList(utf8.encode(pw)));

    try {
      final res = await openBackup(
        file: _selectedFile!.bytes,
        backupPassword: sensitivePw,
      );

      if (!mounted) return;

      if (res case Err(:final failure)) {
        setState(() {
          _isLoading = false;
          _errorMessage = switch (failure) {
            WrongPasswordFailure() => l.backupRestoreWrongPassword,
            BackupCorruptedFailure() => l.backupRestoreCorrupted,
            BackupVersionUnsupportedFailure() =>
              l.backupRestoreUnsupportedVersion,
            _ => failureText(l, failure),
          };
        });
        return;
      }

      final pending = (res as Ok<PendingRestore>).value;
      setState(() {
        _isLoading = false;
        _pendingRestore = pending;
      });
    } finally {
      sensitivePw.wipe();
    }
  }

  Future<void> _executeRestore() async {
    final l = AppLocalizations.of(context)!;
    final pending = _pendingRestore;
    if (pending == null) return;

    final isVaultInitialized =
        ref.read(isVaultInitializedProvider).value ?? false;
    Sensitive? newMasterPassword;
    PasswordCredential? existingVault;

    if (widget.mode == RestoreMode.fresh) {
      if (pending.preview.vaultItemsCount > 0) {
        String newPw;
        if (_sameAsBackupPassword) {
          newPw = _backupPasswordController.text;
        } else {
          newPw = _newMasterPasswordController.text;
        }
        if (newPw.length < 10) {
          setState(() => _errorMessage = l.backupExportPasswordTooShort);
          return;
        }
        newMasterPassword = Sensitive(Uint8List.fromList(utf8.encode(newPw)));
      }
    } else {
      // merge mode
      if (isVaultInitialized) {
        final localPw = _localMasterPasswordController.text;
        if (localPw.isEmpty) {
          setState(() => _errorMessage = l.backupRestoreMasterPasswordHint);
          return;
        }
        final sensitiveLocal = Sensitive(
          Uint8List.fromList(utf8.encode(localPw)),
        );
        existingVault = PasswordCredential(sensitiveLocal);
      } else if (pending.preview.vaultItemsCount > 0) {
        String newPw;
        if (_sameAsBackupPassword) {
          newPw = _backupPasswordController.text;
        } else {
          newPw = _newMasterPasswordController.text;
        }
        if (newPw.length < 10) {
          setState(() => _errorMessage = l.backupExportPasswordTooShort);
          return;
        }
        newMasterPassword = Sensitive(Uint8List.fromList(utf8.encode(newPw)));
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final restoreBackup = await ref.read(restoreBackupProvider.future);

    try {
      final res = await restoreBackup(
        pending: pending,
        mode: widget.mode,
        newMasterPassword: newMasterPassword,
        existingVault: existingVault,
      );

      if (!mounted) return;

      if (res case Err(:final failure)) {
        setState(() {
          _isLoading = false;
          _errorMessage = switch (failure) {
            WrongPasswordFailure() =>
              l.securityChangeMasterPasswordWrongCurrent,
            ValidationFailure(:final detail)
                when detail == 'restore_target_not_empty' =>
              l.backupRestoreTargetNotEmpty,
            _ => failureText(l, failure),
          };
        });
        return;
      }

      final report = (res as Ok<RestoreReport>).value;
      setState(() {
        _isLoading = false;
        _restoreReport = report;
      });
    } finally {
      newMasterPassword?.wipe();
      existingVault?.password.wipe();
    }
  }

  void _finish() {
    _pendingRestore?.dispose();
    _pendingRestore = null;

    if (widget.mode == RestoreMode.fresh) {
      context.go(AppRoutes.onboarding);
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.ow;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: Text(l.backupRestoreTitle),
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
      body: _restoreReport != null
          ? _buildReportView(context, l, colors)
          : _pendingRestore != null
          ? _buildPreviewView(context, l, colors)
          : _buildSelectFileView(context, l, colors),
    );
  }

  Widget _buildSelectFileView(
    BuildContext context,
    AppLocalizations l,
    OwColors colors,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        OwCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.backupRestoreTitle,
                style: OwTextStyles.body.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.ink,
                ),
              ),
              const SizedBox(height: 12),
              OwSecondaryButton(
                label: _selectedFile == null
                    ? l.backupRestoreSelectFile
                    : l.backupRestoreSelectedFile(
                        _selectedFile!.name,
                        '${(_selectedFile!.bytes.lengthInBytes / 1024).toStringAsFixed(1)} KB',
                      ),
                onPressed: _pickFile,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _backupPasswordController,
                obscureText: _obscureBackup,
                decoration: InputDecoration(
                  hintText: l.backupRestorePasswordHint,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureBackup
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () {
                      setState(() => _obscureBackup = !_obscureBackup);
                    },
                  ),
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
          OwPrimaryButton(
            label: l.backupRestoreParseButton,
            onPressed: _parseBackup,
          ),
      ],
    );
  }

  Widget _buildPreviewView(
    BuildContext context,
    AppLocalizations l,
    OwColors colors,
  ) {
    final pending = _pendingRestore!;
    final preview = pending.preview;
    final isVaultInitialized =
        ref.watch(isVaultInitializedProvider).value ?? false;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // 预览卡片
        OwCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.backupRestorePreviewTitle,
                style: OwTextStyles.body.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.ink,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l.backupRestoreCreatedAt(_formatDateTime(preview.createdAt)),
                style: OwTextStyles.caption.copyWith(color: colors.muted),
              ),
              const SizedBox(height: 4),
              Text(
                l.backupRestoreAppVersion(preview.appVersion),
                style: OwTextStyles.caption.copyWith(color: colors.muted),
              ),
              const SizedBox(height: 12),
              Divider(color: colors.line, height: 1),
              const SizedBox(height: 12),
              Text(
                l.backupRestoreAccountsCount(preview.accountsCount),
                style: OwTextStyles.body.copyWith(color: colors.ink),
              ),
              const SizedBox(height: 4),
              Text(
                l.backupRestoreAddressesCount(preview.addressesCount),
                style: OwTextStyles.body.copyWith(color: colors.ink),
              ),
              const SizedBox(height: 4),
              Text(
                l.backupRestoreVaultItemsCount(preview.vaultItemsCount),
                style: OwTextStyles.body.copyWith(color: colors.ink),
              ),
              const SizedBox(height: 4),
              Text(
                l.backupRestoreCredentialsCount(preview.hasCredentials ? 1 : 0),
                style: OwTextStyles.body.copyWith(color: colors.ink),
              ),
              if (preview.skippedCount > 0) ...[
                const SizedBox(height: 8),
                Text(
                  l.backupRestoreSkippedUnreadable(preview.skippedCount),
                  style: OwTextStyles.caption.copyWith(color: colors.warn),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 恢复模式与密码确认卡片
        OwCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.mode == RestoreMode.fresh
                    ? l.backupRestoreModeFreshTitle
                    : l.backupRestoreModeMergeTitle,
                style: OwTextStyles.body.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.mode == RestoreMode.fresh
                    ? l.backupRestoreModeFreshDesc
                    : l.backupRestoreModeMergeDesc,
                style: OwTextStyles.caption.copyWith(color: colors.muted),
              ),
              const SizedBox(height: 16),

              if (widget.mode == RestoreMode.fresh &&
                  preview.vaultItemsCount > 0) ...[
                CheckboxListTile(
                  title: Text(
                    l.backupRestoreSameAsBackupPassword,
                    style: OwTextStyles.body.copyWith(color: colors.ink),
                  ),
                  value: _sameAsBackupPassword,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _sameAsBackupPassword = val);
                    }
                  },
                ),
                if (!_sameAsBackupPassword) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _newMasterPasswordController,
                    obscureText: _obscureNewMaster,
                    decoration: InputDecoration(
                      hintText: l.backupRestoreNewMasterPasswordHint,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNewMaster
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () {
                          setState(
                            () => _obscureNewMaster = !_obscureNewMaster,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ],

              if (widget.mode == RestoreMode.merge) ...[
                if (isVaultInitialized) ...[
                  Text(
                    l.backupRestoreMasterPasswordHint,
                    style: OwTextStyles.body.copyWith(
                      fontWeight: FontWeight.w500,
                      color: colors.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _localMasterPasswordController,
                    obscureText: _obscureLocalMaster,
                    decoration: InputDecoration(
                      hintText: l.backupExportMasterPasswordHint,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureLocalMaster
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () {
                          setState(
                            () => _obscureLocalMaster = !_obscureLocalMaster,
                          );
                        },
                      ),
                    ),
                  ),
                ] else if (preview.vaultItemsCount > 0) ...[
                  CheckboxListTile(
                    title: Text(
                      l.backupRestoreSameAsBackupPassword,
                      style: OwTextStyles.body.copyWith(color: colors.ink),
                    ),
                    value: _sameAsBackupPassword,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _sameAsBackupPassword = val);
                      }
                    },
                  ),
                  if (!_sameAsBackupPassword) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _newMasterPasswordController,
                      obscureText: _obscureNewMaster,
                      decoration: InputDecoration(
                        hintText: l.backupRestoreNewMasterPasswordHint,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureNewMaster
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () {
                            setState(
                              () => _obscureNewMaster = !_obscureNewMaster,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              ],
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
          OwPrimaryButton(
            label: l.backupRestoreExecuteButton,
            onPressed: _executeRestore,
          ),
      ],
    );
  }

  Widget _buildReportView(
    BuildContext context,
    AppLocalizations l,
    OwColors colors,
  ) {
    final report = _restoreReport!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      children: [
        Center(
          child: Column(
            children: [
              Icon(Icons.check_circle_rounded, color: colors.up, size: 56),
              const SizedBox(height: 12),
              Text(
                l.backupRestoreResultTitle,
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
                l.backupRestoreResultAdded(
                  report.accountsAdded,
                  report.addressesAdded,
                  report.itemsAdded,
                ),
                style: OwTextStyles.body.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l.backupRestoreResultSkipped(
                  report.accountsSkipped,
                  report.addressesSkipped,
                  report.itemsSkipped,
                ),
                style: OwTextStyles.body.copyWith(color: colors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        OwPrimaryButton(label: l.backupRestoreFinishButton, onPressed: _finish),
      ],
    );
  }
}
