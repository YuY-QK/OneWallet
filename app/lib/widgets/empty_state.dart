import 'package:flutter/material.dart';

import '../theme/ow_colors.dart';
import '../theme/ow_text_styles.dart';
import 'ow_primary_button.dart';

/// 空状态：图标、一句说明、至多一个主按钮。
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.ow;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: c.muted),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: OwTextStyles.emphasis.copyWith(color: c.ink),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                textAlign: TextAlign.center,
                style: OwTextStyles.body.copyWith(color: c.muted),
              ),
              if (actionLabel != null) ...[
                const SizedBox(height: 20),
                OwPrimaryButton(label: actionLabel!, onPressed: onAction),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
