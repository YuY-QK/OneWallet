import 'package:flutter/material.dart';
import 'package:ow_directory/ow_directory.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/ow_colors.dart';
import '../../../theme/ow_text_styles.dart';
import '../../../widgets/ow_avatar.dart';
import '../../../widgets/ow_external_link.dart';
import '../../../widgets/ow_list_group.dart';
import '../../../widgets/ow_row.dart';

/// P22 关于与帮助。
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  void _showInfoDialog(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(
            content,
            style: OwTextStyles.body.copyWith(color: context.ow.ink),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.ow;
    final coingeckoEntry = ThirdPartyDirectory.builtin().byId('coingecko');

    return Scaffold(
      appBar: AppBar(title: Text(l.aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          const SizedBox(height: 12),
          Center(
            child: Column(
              children: [
                const OwAvatar(label: 'OW', size: 64),
                const SizedBox(height: 12),
                Text(
                  'OneWallet',
                  style: OwTextStyles.title.copyWith(
                    fontSize: 20,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${l.aboutVersion} 1.0.0',
                  style: OwTextStyles.caption.copyWith(color: c.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, 6),
            child: Text(
              l.settingsSectionData,
              style: OwTextStyles.caption.copyWith(color: c.muted),
            ),
          ),
          OwListGroup(
            children: [
              if (coingeckoEntry != null)
                OwRow(
                  avatar: const OwAvatar(label: '价'),
                  title: coingeckoEntry.name,
                  subtitleWidget: OwExternalLink(
                    url: Uri.parse(
                      coingeckoEntry.link(LinkKind.website) ??
                          'https://www.coingecko.com',
                    ),
                    label: l.sourcesCoingeckoAttribution,
                    showHost: false,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, 6),
            child: Text(
              l.settingsSectionSecurity,
              style: OwTextStyles.caption.copyWith(color: c.muted),
            ),
          ),
          OwListGroup(
            children: [
              OwRow(
                title: l.aboutSecurityDesign,
                subtitle: l.aboutSecurityDesignBody,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showInfoDialog(
                  context,
                  title: l.aboutSecurityDesignDialogTitle,
                  content: l.aboutSecurityDesignDetail,
                ),
              ),
              OwRow(
                title: l.aboutBackupFormat,
                subtitle: l.aboutBackupFormatBody,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showInfoDialog(
                  context,
                  title: l.aboutBackupFormatDialogTitle,
                  content: l.aboutBackupFormatDetail,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, 6),
            child: Text(
              l.aboutFaq,
              style: OwTextStyles.caption.copyWith(color: c.muted),
            ),
          ),
          OwListGroup(
            children: [
              OwRow(
                title: l.aboutFaqDerivationTitle,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showInfoDialog(
                  context,
                  title: l.aboutFaqDerivationTitle,
                  content: l.aboutFaqDerivationAnswer,
                ),
              ),
              OwRow(
                title: l.aboutFaqMismatchTitle,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showInfoDialog(
                  context,
                  title: l.aboutFaqMismatchTitle,
                  content: l.aboutFaqMismatchAnswer,
                ),
              ),
              OwRow(
                title: l.aboutFaqApiKeyTitle,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showInfoDialog(
                  context,
                  title: l.aboutFaqApiKeyTitle,
                  content: l.aboutFaqApiKeyAnswer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, 6),
            child: Text(
              l.settingsSectionOther,
              style: OwTextStyles.caption.copyWith(color: c.muted),
            ),
          ),
          OwListGroup(
            children: [
              OwRow(
                title: l.aboutLicenses,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'OneWallet',
                  applicationVersion: '1.0.0',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
