import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../router/route_names.dart';
import '../../../theme/ow_colors.dart';
import '../../../theme/ow_text_styles.dart';
import '../../../widgets/ow_list_group.dart';
import '../../../widgets/ow_row.dart';

/// P18 设置首页。目前只有"数据源"一项，其余项在后续任务加入。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.tabSettings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, 6),
            child: Text(
              l.settingsSectionData,
              style: OwTextStyles.caption.copyWith(color: context.ow.muted),
            ),
          ),
          OwListGroup(
            children: [
              OwRow(
                title: l.settingsSources,
                subtitle: l.settingsSourcesBody,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.pushNamed(RouteNames.settingsSources),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
