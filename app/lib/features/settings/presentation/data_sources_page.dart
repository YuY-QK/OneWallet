import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/ow_colors.dart';
import '../../../theme/ow_text_styles.dart';
import '../../../widgets/failure_text.dart';
import '../../../widgets/ow_avatar.dart';
import '../../../widgets/ow_list_group.dart';
import '../../../widgets/ow_notice.dart';
import '../../../widgets/ow_pill.dart';
import '../../../widgets/ow_row.dart';
import '../../shared/labels.dart';
import '../controllers/data_sources_controller.dart';
import 'widgets/data_source_editor.dart';

/// P20 数据源设置：服务商列表、配置状态、隐私说明。
class DataSourcesPage extends ConsumerWidget {
  const DataSourcesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final state = ref.watch(dataSourcesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.sourcesTitle)),
      body: switch (state) {
        AsyncData(:final value) => _list(context, l, value),
        AsyncError() => Padding(
          padding: const EdgeInsets.all(16),
          child: OwNotice(
            tone: OwNoticeTone.error,
            message: failureText(l, const UnknownFailure()),
          ),
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }

  Widget _list(BuildContext context, AppLocalizations l, DataSourcesState s) {
    Widget configurable(String id, String mark, String name, String body) {
      final status = s.statusOf(id);
      return OwRow(
        key: ValueKey(id),
        avatar: OwAvatar(label: mark),
        title: name,
        subtitle: body,
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            OwPill(
              label: status.configured
                  ? l.sourcesConfigured
                  : l.sourcesNotConfigured,
              tone: status.configured ? OwPillTone.green : OwPillTone.orange,
            ),
            if (status.preview != null)
              Text(
                status.preview!,
                style: OwTextStyles.mono.copyWith(
                  fontSize: 12,
                  color: context.ow.muted,
                ),
              ),
          ],
        ),
        onTap: () => showDataSourceEditor(context, providerId: id),
      );
    }

    Widget soon(ChainFamily family) => OwRow(
      key: ValueKey('soon-${family.name}'),
      avatar: OwAvatar(label: chainFamilyLabel(l, family).substring(0, 3)),
      title: chainFamilyLabel(l, family),
      trailing: Text(
        l.sourcesComingSoon,
        style: OwTextStyles.caption.copyWith(color: context.ow.muted),
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      children: [
        OwListGroup(
          children: [
            configurable(
              DataSourceIds.alchemy,
              'EVM',
              l.sourcesAlchemyName,
              l.sourcesAlchemyBody,
            ),
            configurable(
              DataSourceIds.coingecko,
              '价',
              l.sourcesCoingeckoName,
              l.sourcesCoingeckoBody,
            ),
            soon(ChainFamily.bitcoin),
            soon(ChainFamily.solana),
            soon(ChainFamily.tron),
          ],
        ),
        const SizedBox(height: 12),
        OwNotice(message: l.sourcesPrivacy, tone: OwNoticeTone.info),
      ],
    );
  }
}
