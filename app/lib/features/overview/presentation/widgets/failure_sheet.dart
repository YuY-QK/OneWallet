import 'package:flutter/material.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/ow_colors.dart';
import '../../../../theme/ow_text_styles.dart';
import '../../../../widgets/failure_text.dart';
import '../../../../widgets/ow_list_group.dart';
import '../../../shared/sync_failure.dart';

/// 同步失败账户的简单列表弹层（完整的同步状态页 P21 属于后续任务）。
Future<void> showSyncFailureSheet(
  BuildContext context, {
  required List<SyncRecord> failed,
  required List<Account> accounts,
}) {
  final names = {for (final a in accounts) a.id: a.name};
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final l = AppLocalizations.of(context)!;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.overviewFailureListTitle, style: OwTextStyles.emphasis),
              const SizedBox(height: 12),
              OwListGroup(
                children: [
                  for (final r in failed)
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            names[r.accountId] ?? '—',
                            style: OwTextStyles.rowTitle,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            failureText(l, failureFromTypeName(r.failureType)),
                            style: OwTextStyles.caption.copyWith(
                              color: context.ow.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
