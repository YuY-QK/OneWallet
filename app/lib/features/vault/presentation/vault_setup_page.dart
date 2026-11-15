import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../../bootstrap/foundation_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/ow_colors.dart';
import '../../../theme/ow_text_styles.dart';
import '../../../widgets/ow_card.dart';
import '../../../widgets/ow_input_decoration.dart';
import '../../../widgets/ow_notice.dart';
import '../../../widgets/ow_primary_button.dart';
import '../controllers/vault_setup_controller.dart';

/// P13 设置主密码（创建保险库）。
class VaultSetupPage extends ConsumerStatefulWidget {
  const VaultSetupPage({super.key});

  @override
  ConsumerState<VaultSetupPage> createState() => _VaultSetupPageState();
}

class _VaultSetupPageState extends ConsumerState<VaultSetupPage> {
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmController;

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _passwordController = TextEditingController()..addListener(_onTextChanged);
    _confirmController = TextEditingController()..addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  int _calculateStrength(String text) {
    if (text.length < 10) return 0;
    var score = 1;
    if (text.length >= 14) score++;
    final hasLetters = RegExp(r'[a-zA-Z]').hasMatch(text);
    final hasDigits = RegExp(r'[0-9]').hasMatch(text);
    final hasSpecial = RegExp(r'[^a-zA-Z0-9]').hasMatch(text);
    if ((hasLetters && hasDigits) ||
        (hasLetters && hasSpecial) ||
        (hasDigits && hasSpecial)) {
      score++;
    }
    if (text.length >= 12 && hasLetters && hasDigits && hasSpecial) {
      score = 3;
    }
    return score.clamp(1, 3);
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context)!;
    final pw = _passwordController.text;
    final strength = _calculateStrength(pw);

    if (strength == 1) {
      // 强度为弱时额外确认
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.vaultSetupWeakConfirmTitle),
          content: Text(l.vaultSetupWeakConfirmBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l.vaultSetupWeakConfirmCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l.vaultSetupWeakConfirmContinue),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final sensitive = Sensitive(Uint8List.fromList(utf8.encode(pw)));
    final controller = ref.read(vaultSetupControllerProvider.notifier);

    try {
      final res = await controller.createVault(password: sensitive);
      if (!mounted) return;
      if (res case Err(:final failure)) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure.toString())));
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.vaultSetupSuccess)));
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    } finally {
      _passwordController.clear();
      _confirmController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.ow;
    final state = ref.watch(vaultSetupControllerProvider);
    final caps = ref.watch(platformCapabilitiesProvider);
    final controller = ref.read(vaultSetupControllerProvider.notifier);

    final pw = _passwordController.text;
    final confirm = _confirmController.text;
    final strength = _calculateStrength(pw);
    final isMismatch = confirm.isNotEmpty && pw != confirm;
    final isTooShort = pw.isNotEmpty && pw.length < 10;
    final isValid =
        pw.length >= 10 &&
        pw == confirm &&
        state.isAgreed &&
        !state.isSubmitting;

    final (strengthText, strengthColor, strengthProgress) = switch (strength) {
      1 => (l.vaultSetupStrengthWeak, c.down, 0.33),
      2 => (l.vaultSetupStrengthMedium, c.brand, 0.66),
      3 => (l.vaultSetupStrengthStrong, c.up, 1.0),
      _ => ('', Colors.transparent, 0.0),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(l.vaultSetupTitle),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.lock_rounded, size: 20),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.vaultSetupIntro, style: OwTextStyles.body),
              const SizedBox(height: 16),
              OwNotice(
                tone: OwNoticeTone.error,
                message:
                    '${l.vaultSetupWarningTitle}：${l.vaultSetupWarningBody}',
              ),
              const SizedBox(height: 20),
              OwFieldLabel(l.vaultSetupPasswordLabel),
              TextField(
                key: const Key('vault_setup_password_field'),
                controller: _passwordController,
                obscureText: _obscurePassword,
                enableSuggestions: false,
                autocorrect: false,
                keyboardType: TextInputType.visiblePassword,
                decoration: owInputDecoration(
                  context,
                  hint: l.vaultSetupPasswordHint,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              if (isTooShort) ...[
                const SizedBox(height: 4),
                Text(
                  l.vaultSetupTooShort,
                  style: OwTextStyles.caption.copyWith(color: c.down),
                ),
              ],
              if (strength > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: strengthProgress,
                          color: strengthColor,
                          backgroundColor: c.line,
                          minHeight: 4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l.vaultSetupStrengthLabel(strengthText),
                      style: OwTextStyles.caption.copyWith(
                        color: strengthColor,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              OwFieldLabel(l.vaultSetupPasswordConfirmLabel),
              TextField(
                key: const Key('vault_setup_confirm_field'),
                controller: _confirmController,
                obscureText: _obscureConfirm,
                enableSuggestions: false,
                autocorrect: false,
                keyboardType: TextInputType.visiblePassword,
                decoration: owInputDecoration(
                  context,
                  hint: l.vaultSetupPasswordConfirmHint,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
              ),
              if (isMismatch) ...[
                const SizedBox(height: 4),
                Text(
                  l.vaultSetupMismatch,
                  style: OwTextStyles.caption.copyWith(color: c.down),
                ),
              ],
              const SizedBox(height: 16),
              CheckboxListTile(
                value: state.isAgreed,
                onChanged: state.isSubmitting ? null : controller.toggleAgreed,
                title: Text(
                  l.vaultSetupAgreeRisk,
                  style: OwTextStyles.body.copyWith(color: c.ink),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              if (caps.hardwareKeystore) ...[
                const SizedBox(height: 16),
                OwCard(
                  child: SwitchListTile(
                    value: state.isBiometricsEnabled,
                    onChanged: state.isSubmitting
                        ? null
                        : controller.toggleBiometrics,
                    title: Text(
                      l.vaultSetupBiometricsTitle,
                      style: OwTextStyles.body,
                    ),
                    subtitle: Text(
                      l.vaultSetupBiometricsSubtitle,
                      style: OwTextStyles.caption.copyWith(color: c.muted),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              if (state.isSubmitting) ...[
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    l.vaultSetupCreating,
                    style: OwTextStyles.caption.copyWith(color: c.muted),
                  ),
                ),
              ] else ...[
                OwPrimaryButton(
                  label: l.vaultSetupCreateButton,
                  onPressed: isValid ? _submit : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
