import 'package:flutter/material.dart';

import '../../../../theme/ow_colors.dart';
import '../../../../theme/ow_text_styles.dart';

/// 3x4 数字键盘，用于输入 6 位数字 PIN。
class PinPad extends StatelessWidget {
  const PinPad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.onBiometric,
    this.showBiometric = false,
    this.enabled = true,
  });

  final ValueChanged<int> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onBiometric;
  final bool showBiometric;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildRow(context, [1, 2, 3]),
        const SizedBox(height: 16),
        _buildRow(context, [4, 5, 6]),
        const SizedBox(height: 16),
        _buildRow(context, [7, 8, 9]),
        const SizedBox(height: 16),
        _buildBottomRow(context),
      ],
    );
  }

  Widget _buildRow(BuildContext context, List<int> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildDigitButton(context, digits[0]),
        const SizedBox(width: 24),
        _buildDigitButton(context, digits[1]),
        const SizedBox(width: 24),
        _buildDigitButton(context, digits[2]),
      ],
    );
  }

  Widget _buildBottomRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: showBiometric && enabled
              ? _buildActionButton(
                  context,
                  icon: Icons.fingerprint,
                  onTap: onBiometric,
                  semanticsLabel: '生物识别',
                )
              : null,
        ),
        const SizedBox(width: 24),
        _buildDigitButton(context, 0),
        const SizedBox(width: 24),
        SizedBox(
          width: 72,
          height: 72,
          child: _buildActionButton(
            context,
            icon: Icons.backspace_outlined,
            onTap: enabled ? onBackspace : null,
            semanticsLabel: '回退',
          ),
        ),
      ],
    );
  }

  Widget _buildDigitButton(BuildContext context, int digit) {
    final colors = context.ow;

    return SizedBox(
      width: 72,
      height: 72,
      child: Material(
        color: colors.surface,
        shape: CircleBorder(side: BorderSide(color: colors.line, width: 1)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? () => onDigit(digit) : null,
          child: Center(
            child: Text(
              '$digit',
              style: TextStyle(
                fontFamily: OwFonts.sans,
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: enabled
                    ? colors.ink
                    : colors.muted.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback? onTap,
    required String semanticsLabel,
  }) {
    final colors = context.ow;

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Icon(
            icon,
            size: 28,
            color: onTap != null
                ? colors.ink
                : colors.muted.withValues(alpha: 0.4),
            semanticLabel: semanticsLabel,
          ),
        ),
      ),
    );
  }
}
