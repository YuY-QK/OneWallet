import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/ow_colors.dart';
import '../../../theme/ow_text_styles.dart';
import '../../../widgets/ow_avatar.dart';
import '../../../widgets/ow_card.dart';
import '../../../widgets/ow_list_group.dart';
import '../../../widgets/ow_primary_button.dart';
import '../../../widgets/ow_row.dart';
import '../../../widgets/ow_secondary_button.dart';
import '../../lock/presentation/widgets/pin_dots.dart';
import '../../lock/presentation/widgets/pin_pad.dart';
import '../controllers/onboarding_controller.dart';

/// P01 首次引导页。
class OnboardingPage extends ConsumerWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    final colors = context.ow;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: switch (state.step) {
          OnboardingStep.welcome => _buildWelcomeView(context, controller),
          OnboardingStep.enterPin || OnboardingStep.confirmPin => _buildPinView(
            context,
            state,
            controller,
          ),
          OnboardingStep.biometric => _buildBiometricView(context, controller),
        },
      ),
    );
  }

  Widget _buildWelcomeView(
    BuildContext context,
    OnboardingController controller,
  ) {
    final l = AppLocalizations.of(context)!;
    final colors = context.ow;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          children: [
            const SizedBox(height: 12),
            // 欢迎卡片
            OwCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.onboardingWelcomeTitle,
                    style: TextStyle(
                      fontFamily: OwFonts.sans,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colors.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.onboardingWelcomeSubtitle,
                    style: TextStyle(
                      fontFamily: OwFonts.sans,
                      fontSize: 14,
                      color: colors.muted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // 安全须知分段标题
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text(
                l.onboardingSecurityTitle,
                style: TextStyle(
                  fontFamily: OwFonts.sans,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.muted,
                ),
              ),
            ),
            // 三条安全须知列表
            OwListGroup(
              children: [
                OwRow(
                  avatar: const OwAvatar(
                    label: '1',
                    shape: OwAvatarShape.roundedSquare,
                  ),
                  title: l.onboardingSecurity1Title,
                  subtitle: l.onboardingSecurity1Desc,
                ),
                OwRow(
                  avatar: const OwAvatar(
                    label: '2',
                    shape: OwAvatarShape.roundedSquare,
                  ),
                  title: l.onboardingSecurity2Title,
                  subtitle: l.onboardingSecurity2Desc,
                ),
                OwRow(
                  avatar: const OwAvatar(
                    label: '3',
                    shape: OwAvatarShape.roundedSquare,
                  ),
                  title: l.onboardingSecurity3Title,
                  subtitle: l.onboardingSecurity3Desc,
                ),
              ],
            ),
            const SizedBox(height: 36),
            // 操作按钮
            OwPrimaryButton(
              label: l.onboardingStartButton,
              onPressed: controller.startPinSetup,
            ),
            const SizedBox(height: 12),
            OwSecondaryButton(
              label: l.onboardingRestoreButton,
              onPressed: () => context.go('/settings/backup/restore'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinView(
    BuildContext context,
    OnboardingViewState state,
    OnboardingController controller,
  ) {
    final l = AppLocalizations.of(context)!;
    final colors = context.ow;

    final isConfirm = state.step == OnboardingStep.confirmPin;
    final title = isConfirm
        ? l.onboardingConfirmPinTitle
        : l.onboardingSetPinTitle;

    String subtitle;
    Color subtitleColor = colors.muted;
    if (state.errorMessage == 'pin_mismatch') {
      subtitle = l.onboardingPinMismatch;
      subtitleColor = colors.down;
    } else {
      subtitle = isConfirm
          ? l.onboardingConfirmPinSubtitle
          : l.onboardingSetPinSubtitle;
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 顶部标题与说明
              Column(
                children: [
                  const SizedBox(height: 24),
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: OwFonts.sans,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colors.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: OwFonts.sans,
                      fontSize: 14,
                      color: subtitleColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              // PIN 点位
              PinDots(
                length: state.currentDigits.length,
                shake: state.shake,
                onShakeEnd: controller.resetShake,
              ),
              // 数字键盘
              PinPad(
                onDigit: controller.addDigit,
                onBackspace: controller.backspace,
                enabled: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricView(
    BuildContext context,
    OnboardingController controller,
  ) {
    final l = AppLocalizations.of(context)!;
    final colors = context.ow;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.fingerprint, size: 64, color: colors.brand),
              const SizedBox(height: 24),
              Text(
                l.onboardingBiometricTitle,
                style: TextStyle(
                  fontFamily: OwFonts.sans,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colors.ink,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l.onboardingBiometricSubtitle,
                style: TextStyle(
                  fontFamily: OwFonts.sans,
                  fontSize: 14,
                  color: colors.muted,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              OwPrimaryButton(
                label: l.onboardingEnableBiometric,
                onPressed: controller.enableBiometricAndComplete,
              ),
              const SizedBox(height: 12),
              OwSecondaryButton(
                label: l.onboardingSkipBiometric,
                onPressed: controller.skipBiometricAndComplete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
