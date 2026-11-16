import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../../bootstrap/app_lock_providers.dart';
import '../../../bootstrap/foundation_providers.dart';
import '../../../bootstrap/usecase_providers.dart';
import '../../../bootstrap/vault_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/ow_colors.dart';
import '../../../theme/ow_text_styles.dart';
import '../../../widgets/ow_list_group.dart';
import '../../../widgets/ow_pill.dart';
import '../../../widgets/ow_row.dart';
import '../../lock/presentation/widgets/pin_dots.dart';
import '../../lock/presentation/widgets/pin_pad.dart';

String _failureToMessage(Failure failure, AppLocalizations l) {
  if (failure is WrongPasswordFailure) {
    return l.securityChangePinWrongOld;
  }
  if (failure is LockedOutFailure) {
    return l.lockCountdown(failure.until.toLocal().toString());
  }
  if (failure is ValidationFailure) {
    return failure.detail ?? 'validation_error';
  }
  return failure.toString();
}

/// P19 安全设置页（应用锁与保险库设置）。
class SecuritySettingsPage extends ConsumerStatefulWidget {
  const SecuritySettingsPage({super.key});

  @override
  ConsumerState<SecuritySettingsPage> createState() =>
      _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends ConsumerState<SecuritySettingsPage> {
  bool? _isCompromised;

  @override
  void initState() {
    super.initState();
    _checkDeviceIntegrity();
  }

  Future<void> _checkDeviceIntegrity() async {
    final integrity = ref.read(deviceIntegrityProvider);
    final compromised = await integrity.looksCompromised();
    if (mounted) {
      setState(() => _isCompromised = compromised);
    }
  }

  String _autoLockLabel(AutoLock lock, AppLocalizations l) {
    return switch (lock) {
      AutoLock.immediately => l.securityAutoLockImmediately,
      AutoLock.after1Min => l.securityAutoLock1Min,
      AutoLock.after5Min => l.securityAutoLock5Min,
    };
  }

  Future<void> _showAutoLockSheet(
    BuildContext context,
    AutoLock current,
  ) async {
    final l = AppLocalizations.of(context)!;
    final selected = await showModalBottomSheet<AutoLock>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final option in AutoLock.values)
                ListTile(
                  title: Text(_autoLockLabel(option, l)),
                  trailing: option == current
                      ? Icon(Icons.check_rounded, color: ctx.ow.brand)
                      : null,
                  onTap: () => Navigator.of(ctx).pop(option),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (selected != null && selected != current) {
      await ref
          .read(settingsRepositoryProvider)
          .update((s) => s.copyWith(autoLock: selected));
    }
  }

  Future<void> _toggleAppBiometrics(bool enable) async {
    final l = AppLocalizations.of(context)!;
    if (enable) {
      final capabilities = ref.read(platformCapabilitiesProvider);
      if (!capabilities.biometrics) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.securityVaultBiometricsUnsupported)),
        );
        return;
      }
      final bioAuth = ref.read(biometricAuthProvider);
      final authRes = await bioAuth.authenticate(reason: l.lockBiometricReason);
      if (authRes case Err()) {
        return;
      }
    }

    await ref
        .read(settingsRepositoryProvider)
        .update((s) => s.copyWith(appBiometrics: enable));
  }

  Future<void> _toggleVaultBiometrics(bool enable) async {
    final l = AppLocalizations.of(context)!;
    final setVaultBiometrics = await ref.read(
      setVaultBiometricsProvider.future,
    );

    if (!enable) {
      await setVaultBiometrics(enable: false);
      return;
    }

    final capabilities = ref.read(platformCapabilitiesProvider);
    if (!capabilities.hardwareKeystore) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.securityVaultBiometricsUnsupported)),
      );
      return;
    }

    if (!mounted) return;
    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => const _MasterPasswordPromptDialog(),
    );

    if (password == null || password.isEmpty) return;

    final sensitive = Sensitive(utf8.encode(password));
    try {
      final res = await setVaultBiometrics(
        enable: true,
        credential: PasswordCredential(sensitive),
      );
      if (!mounted) return;
      if (res case Err(:final failure)) {
        final errText = _failureToMessage(failure, l);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errText)));
      }
    } finally {
      sensitive.wipe();
    }
  }

  Future<void> _showChangePinDialog() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => const _ChangePinSheet(),
    );

    if (changed == true && mounted) {
      final l = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.securityChangePinSuccess)));
    }
  }

  Future<void> _showChangeMasterPasswordDialog() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (ctx) => const _ChangeMasterPasswordDialog(),
    );

    if (changed == true && mounted) {
      final l = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.securityChangeMasterPasswordSuccess)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.ow;
    final settings =
        ref.watch(settingsProvider).asData?.value ?? const AppSettings();
    final isVaultInitialized =
        ref.watch(isVaultInitializedProvider).asData?.value ?? false;

    final isCompromised = _isCompromised ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(l.securityTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        children: [
          // 1. 应用锁
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, 6),
            child: Text(
              l.securitySectionAppLock,
              style: OwTextStyles.caption.copyWith(color: colors.muted),
            ),
          ),
          OwListGroup(
            children: [
              OwRow(
                title: l.securityChangePin,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _showChangePinDialog,
              ),
              OwRow(
                title: l.securityAppBiometrics,
                subtitle: l.securityAppBiometricsDesc,
                trailing: Switch(
                  value: settings.appBiometrics,
                  onChanged: _toggleAppBiometrics,
                ),
              ),
              OwRow(
                title: l.securityAutoLock,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _autoLockLabel(settings.autoLock, l),
                      style: OwTextStyles.body.copyWith(color: colors.muted),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
                onTap: () => _showAutoLockSheet(context, settings.autoLock),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2. 保险库
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, 6),
            child: Text(
              l.securitySectionVault,
              style: OwTextStyles.caption.copyWith(color: colors.muted),
            ),
          ),
          OwListGroup(
            children: [
              OwRow(
                title: l.securityVaultBiometrics,
                subtitle: !isVaultInitialized
                    ? l.securityVaultBiometricsUninitialized
                    : l.securityVaultBiometricsDesc,
                trailing: Switch(
                  value: isVaultInitialized && settings.vaultBiometrics,
                  onChanged: isVaultInitialized ? _toggleVaultBiometrics : null,
                ),
              ),
              OwRow(
                title: l.securityChangeMasterPassword,
                subtitle: !isVaultInitialized
                    ? l.securityVaultBiometricsUninitialized
                    : null,
                trailing: isVaultInitialized
                    ? const Icon(Icons.chevron_right_rounded)
                    : null,
                onTap: isVaultInitialized
                    ? _showChangeMasterPasswordDialog
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3. 设备
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, 6),
            child: Text(
              l.securitySectionDevice,
              style: OwTextStyles.caption.copyWith(color: colors.muted),
            ),
          ),
          OwListGroup(
            children: [
              OwRow(
                title: l.securityDeviceStatus,
                subtitle: isCompromised
                    ? l.securityDeviceCompromisedDesc
                    : l.securityDeviceNormalDesc,
                trailing: isCompromised
                    ? OwPill(
                        label: l.securityDeviceCompromised,
                        tone: OwPillTone.red,
                      )
                    : OwPill(
                        label: l.securityDeviceNormal,
                        tone: OwPillTone.green,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 修改 PIN 码底部抽屉。
class _ChangePinSheet extends ConsumerStatefulWidget {
  const _ChangePinSheet();

  @override
  ConsumerState<_ChangePinSheet> createState() => _ChangePinSheetState();
}

class _ChangePinSheetState extends ConsumerState<_ChangePinSheet> {
  int _step = 0; // 0: 旧 PIN, 1: 新 PIN, 2: 确认新 PIN
  String _digits = '';
  String _oldPin = '';
  String _newPin = '';
  String? _errorMessage;
  bool _isLoading = false;

  void _onDigit(String d) {
    if (_digits.length >= 6 || _isLoading) return;
    setState(() {
      _digits += d;
      _errorMessage = null;
    });

    if (_digits.length == 6) {
      _handleCompletedInput();
    }
  }

  void _onDelete() {
    if (_digits.isEmpty || _isLoading) return;
    setState(() {
      _digits = _digits.substring(0, _digits.length - 1);
      _errorMessage = null;
    });
  }

  Future<void> _handleCompletedInput() async {
    final l = AppLocalizations.of(context)!;
    final currentInput = _digits;

    if (_step == 0) {
      // 验证旧 PIN
      setState(() => _isLoading = true);
      final verifyPin = await ref.read(verifyPinProvider.future);
      final sensitive = Sensitive(utf8.encode(currentInput));
      try {
        final res = await verifyPin(sensitive);
        if (!mounted) return;
        if (res case Err(:final failure)) {
          final text = _failureToMessage(failure, l);
          setState(() {
            _digits = '';
            _errorMessage = text;
            _isLoading = false;
          });
          return;
        }
        // 旧 PIN 正确，进入新 PIN
        setState(() {
          _oldPin = currentInput;
          _digits = '';
          _step = 1;
          _isLoading = false;
        });
      } finally {
        sensitive.wipe();
      }
    } else if (_step == 1) {
      // 记录新 PIN，进入确认阶段
      setState(() {
        _newPin = currentInput;
        _digits = '';
        _step = 2;
      });
    } else if (_step == 2) {
      // 确认新 PIN
      if (currentInput != _newPin) {
        setState(() {
          _digits = '';
          _errorMessage = l.securityChangePinMismatch;
          _step = 1; // 重新输入新 PIN
        });
        return;
      }

      // 执行修改
      setState(() => _isLoading = true);
      final changePin = await ref.read(changePinProvider.future);
      final oldSensitive = Sensitive(utf8.encode(_oldPin));
      final newSensitive = Sensitive(utf8.encode(_newPin));
      try {
        final res = await changePin(oldPin: oldSensitive, newPin: newSensitive);
        if (!mounted) return;
        if (res case Err(:final failure)) {
          setState(() {
            _digits = '';
            _errorMessage = _failureToMessage(failure, l);
            _isLoading = false;
          });
        } else {
          Navigator.of(context).pop(true);
        }
      } finally {
        oldSensitive.wipe();
        newSensitive.wipe();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.ow;

    String title;
    String subtitle;
    switch (_step) {
      case 0:
        title = l.securityChangePinOldTitle;
        subtitle = l.securityChangePinOldSubtitle;
      case 1:
        title = l.securityChangePinNewTitle;
        subtitle = l.securityChangePinNewSubtitle;
      default:
        title = l.securityChangePinConfirmTitle;
        subtitle = l.securityChangePinConfirmSubtitle;
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: OwTextStyles.title),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: OwTextStyles.caption.copyWith(color: colors.muted),
            ),
            const SizedBox(height: 20),
            PinDots(
              length: _digits.length,
              total: 6,
              shake: _errorMessage != null,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: OwTextStyles.caption.copyWith(color: colors.down),
              ),
            ],
            const SizedBox(height: 24),
            PinPad(
              onDigit: (d) => _onDigit(d.toString()),
              onBackspace: _onDelete,
              showBiometric: false,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// 主密码验证弹窗（用于开启生物识别）。
class _MasterPasswordPromptDialog extends StatefulWidget {
  const _MasterPasswordPromptDialog();

  @override
  State<_MasterPasswordPromptDialog> createState() =>
      _MasterPasswordPromptDialogState();
}

class _MasterPasswordPromptDialogState
    extends State<_MasterPasswordPromptDialog> {
  final _controller = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l.securityVerifyMasterPasswordTitle),
      content: TextField(
        controller: _controller,
        obscureText: _obscure,
        decoration: InputDecoration(
          hintText: l.securityVerifyMasterPasswordHint,
          suffixIcon: IconButton(
            icon: Icon(
              _obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.securityCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l.securityVerifyMasterPasswordConfirm),
        ),
      ],
    );
  }
}

/// 修改主密码对话框。
class _ChangeMasterPasswordDialog extends ConsumerStatefulWidget {
  const _ChangeMasterPasswordDialog();

  @override
  ConsumerState<_ChangeMasterPasswordDialog> createState() =>
      _ChangeMasterPasswordDialogState();
}

class _ChangeMasterPasswordDialogState
    extends ConsumerState<_ChangeMasterPasswordDialog> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  int _calculateStrength(String text) {
    if (text.length < 10) return 0;
    var score = 0;
    if (text.length >= 14) score++;
    if (RegExp(r'[0-9]').hasMatch(text) && RegExp(r'[a-zA-Z]').hasMatch(text)) {
      score++;
    }
    if (RegExp(r'[^a-zA-Z0-9]').hasMatch(text)) score++;
    if (score == 0) return 1;
    if (score == 1) return 2;
    return 3;
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context)!;
    final current = _currentController.text;
    final newPw = _newController.text;
    final confirm = _confirmController.text;

    if (current.isEmpty) {
      setState(() => _error = l.securityChangeMasterPasswordCurrentHint);
      return;
    }
    if (newPw.length < 10) {
      setState(() => _error = l.securityChangeMasterPasswordTooShort);
      return;
    }
    if (newPw != confirm) {
      setState(() => _error = l.securityChangeMasterPasswordMismatch);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final changeMasterPassword = await ref.read(
      changeMasterPasswordProvider.future,
    );
    final curSensitive = Sensitive(utf8.encode(current));
    final newSensitive = Sensitive(utf8.encode(newPw));
    try {
      final res = await changeMasterPassword(
        currentPassword: curSensitive,
        newPassword: newSensitive,
      );
      if (!mounted) return;
      if (res case Err(:final failure)) {
        final text = failure is WrongPasswordFailure
            ? l.securityChangeMasterPasswordWrongCurrent
            : _failureToMessage(failure, l);
        setState(() {
          _error = text;
          _isLoading = false;
        });
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    } finally {
      curSensitive.wipe();
      newSensitive.wipe();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.ow;
    final newPw = _newController.text;
    final strength = _calculateStrength(newPw);

    final (strengthText, strengthColor, strengthRatio) = switch (strength) {
      1 => (l.vaultSetupStrengthWeak, colors.down, 0.33),
      2 => (l.vaultSetupStrengthMedium, colors.brand, 0.66),
      3 => (l.vaultSetupStrengthStrong, colors.up, 1.0),
      _ => ('', Colors.transparent, 0.0),
    };

    return AlertDialog(
      title: Text(l.securityChangeMasterPasswordTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _currentController,
              obscureText: _obscureCurrent,
              decoration: InputDecoration(
                labelText: l.securityChangeMasterPasswordCurrent,
                hintText: l.securityChangeMasterPasswordCurrentHint,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureCurrent
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscureCurrent = !_obscureCurrent),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newController,
              obscureText: _obscureNew,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l.securityChangeMasterPasswordNew,
                hintText: l.securityChangeMasterPasswordNewHint,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNew
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
            ),
            if (newPw.isNotEmpty) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: strengthRatio,
                  color: strengthColor,
                  backgroundColor: colors.line,
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l.vaultSetupStrengthLabel(strengthText),
                style: OwTextStyles.caption.copyWith(color: strengthColor),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _confirmController,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: l.securityChangeMasterPasswordConfirm,
                hintText: l.securityChangeMasterPasswordConfirmHint,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: OwTextStyles.caption.copyWith(color: colors.down),
              ),
            ],
            if (_isLoading) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l.securityChangeMasterPasswordChanging,
                    style: OwTextStyles.caption.copyWith(color: colors.muted),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(l.securityCancel),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: Text(l.securityChangeMasterPasswordConfirmAction),
        ),
      ],
    );
  }
}
