import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/ow_colors.dart';
import '../../../theme/ow_text_styles.dart';
import '../controllers/lock_controller.dart';
import 'widgets/pin_dots.dart';
import 'widgets/pin_pad.dart';

/// P00 解锁页。
class LockPage extends ConsumerWidget {
  const LockPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(lockControllerProvider);
    final controller = ref.read(lockControllerProvider.notifier);
    final colors = context.ow;
    final l = AppLocalizations.of(context)!;

    String subtitleText;
    Color subtitleColor = colors.muted;

    if (state.isLockedOut) {
      final mins = state.remainingSeconds ~/ 60;
      final secs = state.remainingSeconds % 60;
      final timeStr =
          '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
      subtitleText = l.lockCountdown(timeStr);
      subtitleColor = colors.down;
    } else if (state.errorMessage == 'wrong_pin') {
      subtitleText = l.lockWrongPin;
      subtitleColor = colors.down;
    } else {
      subtitleText = l.lockSubtitle;
    }

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(height: 16),
                  // App 图标与标题
                  Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: colors.brand,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            'OW',
                            style: TextStyle(
                              fontFamily: OwFonts.sans,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: colors.brandInk,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l.lockTitle,
                        style: TextStyle(
                          fontFamily: OwFonts.sans,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colors.ink,
                        ),
                      ),
                    ],
                  ),
                  // PIN 点位与提示
                  Column(
                    children: [
                      PinDots(
                        length: state.enteredDigits.length,
                        shake: state.shake,
                        onShakeEnd: controller.resetShake,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        subtitleText,
                        style: TextStyle(
                          fontFamily: OwFonts.sans,
                          fontSize: 14,
                          color: subtitleColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  // 数字键盘
                  PinPad(
                    onDigit: controller.addDigit,
                    onBackspace: controller.backspace,
                    onBiometric: controller.authenticateWithBiometric,
                    showBiometric: state.canUseBiometric,
                    enabled: !state.isLockedOut,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
