import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../../bootstrap/vault_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../router/route_names.dart';
import '../../../theme/ow_colors.dart';
import '../../../theme/ow_text_styles.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/ow_avatar.dart';
import '../../../widgets/ow_card.dart';
import '../../../widgets/ow_row.dart';

/// P12 保险库首页。
class VaultPage extends ConsumerWidget {
  const VaultPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final c = context.ow;
    final isInitializedAsync = ref.watch(isVaultInitializedProvider);

    return isInitializedAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l.tabVault)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(l.tabVault)),
        body: Center(child: Text(e.toString())),
      ),
      data: (isInitialized) {
        if (!isInitialized) {
          return Scaffold(
            appBar: AppBar(title: Text(l.tabVault)),
            body: EmptyState(
              icon: Icons.lock_outline,
              title: l.vaultIntroTitle,
              body: l.vaultIntroBody,
              actionLabel: l.vaultIntroAction,
              onAction: () => context.goNamed(RouteNames.vaultSetup),
            ),
          );
        }

        final itemsAsync = ref.watch(vaultItemsProvider);

        return Scaffold(
          appBar: AppBar(
            title: Text(l.tabVault),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_rounded),
                tooltip: l.vaultImportAction,
                onPressed: () => context.goNamed(RouteNames.vaultImport),
              ),
            ],
          ),
          body: itemsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(e.toString())),
            data: (items) {
              if (items.isEmpty) {
                return EmptyState(
                  icon: Icons.key_outlined,
                  title: l.vaultEmptyItemsTitle,
                  body: l.vaultEmptyItemsBody,
                );
              }

              return ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                children: [
                  OwCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < items.length; i++) ...[
                          if (i > 0)
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: c.line,
                              indent: 54,
                            ),
                          _buildItemRow(context, items[i]),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      l.vaultFooterNote,
                      style: OwTextStyles.caption.copyWith(color: c.muted),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildItemRow(BuildContext context, VaultItemSummary item) {
    final l = AppLocalizations.of(context)!;
    final c = context.ow;

    final kindStr = item.meta.kind == VaultItemKind.mnemonic
        ? l.vaultItemKindMnemonic
        : l.vaultItemKindPrivateKey;
    final extraParts = <String>[kindStr];
    if (item.meta.hasPassphrase) {
      extraParts.add(l.vaultItemPassphrase);
    }
    if (item.linkedAccountNames.isNotEmpty) {
      extraParts.add(item.linkedAccountNames.join('、'));
    }

    return OwRow(
      avatar: const OwAvatar(label: '钥', shape: OwAvatarShape.roundedSquare),
      title: item.meta.name,
      subtitle: extraParts.join(' · '),
      trailing: Icon(Icons.chevron_right_rounded, size: 20, color: c.muted),
      onTap: () {
        context.goNamed(
          RouteNames.vaultItem,
          pathParameters: {'id': item.meta.id},
        );
      },
    );
  }
}
