import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../widgets/empty_state.dart';

/// P02 总览。M0 只有空状态。
class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.tabOverview)),
      body: EmptyState(
        icon: Icons.pie_chart_outline,
        title: l.overviewEmptyTitle,
        body: l.overviewEmptyBody,
        actionLabel: l.overviewEmptyAction,
        onAction: () =>
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(l.notAvailableYet))),
      ),
    );
  }
}
