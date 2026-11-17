import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bootstrap/ui_services.dart';
import '../l10n/app_localizations.dart';
import '../theme/ow_colors.dart';
import '../theme/ow_text_styles.dart';

/// 通用外链跳转组件（M1-15）。
///
/// 显示链接文本与域名；点击时弹出确认对话框，告知即将离开 OneWallet，
/// 显示完整网址由用户确认后再调用系统浏览器打开。
class OwExternalLink extends ConsumerWidget {
  const OwExternalLink({
    super.key,
    required this.url,
    this.label,
    this.showHost = true,
    this.showIcon = true,
    this.style,
    this.color,
  });

  /// 待打开的外部链接（须为 https）。
  final Uri url;

  /// 自定义显示文本。为空时直接显示主机名（域名）。
  final String? label;

  /// 当指定了 [label] 时，是否在后面括号标注完整域名（如 `官网 (alchemy.com)`）。
  final bool showHost;

  /// 是否显示外部链接小图标 `↗`。
  final bool showIcon;

  /// 文本样式。
  final TextStyle? style;

  /// 自定义链接颜色；未指定时使用主题的品牌色 [OwColors.brand]。
  final Color? color;

  /// 弹出确认对话框并打开外部链接的统一方法。
  ///
  /// 用户确认并成功调起系统浏览器返回 true；拉起失败返回 false；用户取消返回 null。
  static Future<bool?> open(
    BuildContext context,
    WidgetRef ref,
    Uri url,
  ) async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.externalLinkConfirmTitle),
        content: Text(l.externalLinkConfirmBody(url.toString())),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.externalLinkCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.externalLinkConfirmOpen),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final opener = ref.read(externalUrlOpenerProvider);
      return await opener(url);
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.ow;
    final linkColor = color ?? c.brand;
    final host = url.host;
    final displayText = label ?? host;
    final effectiveStyle = (style ?? OwTextStyles.caption).copyWith(
      color: linkColor,
      decoration: TextDecoration.underline,
      decorationColor: linkColor,
    );

    return InkWell(
      onTap: () => open(context, ref, url),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                displayText,
                style: effectiveStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (showHost &&
                label != null &&
                label != host &&
                host.isNotEmpty) ...[
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '($host)',
                  style: OwTextStyles.caption.copyWith(color: c.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            if (showIcon) ...[
              const SizedBox(width: 3),
              Icon(
                Icons.open_in_new_rounded,
                size: (effectiveStyle.fontSize ?? 12) + 2,
                color: linkColor,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
