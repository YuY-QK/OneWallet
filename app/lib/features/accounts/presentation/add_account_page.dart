import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../router/route_names.dart';
import '../../../widgets/ow_avatar.dart';
import '../../../widgets/ow_list_group.dart';
import '../../../widgets/ow_row.dart';

/// P04 添加账户：选择类型。
class AddAccountPage extends StatelessWidget {
  const AddAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    const chevron = Icon(Icons.chevron_right_rounded);
    return Scaffold(
      appBar: AppBar(title: Text(l.accountAddTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        children: [
          OwListGroup(
            children: [
              OwRow(
                avatar: const OwAvatar(label: '看'),
                title: l.accountAddWatchTitle,
                subtitle: l.accountAddWatchBody,
                trailing: chevron,
                onTap: () => context.pushNamed(RouteNames.walletAdd),
              ),
              OwRow(
                avatar: const OwAvatar(
                  label: '所',
                  shape: OwAvatarShape.roundedSquare,
                ),
                title: l.accountAddExchangeTitle,
                subtitle: l.accountAddExchangeBody,
                trailing: chevron,
                onTap: () => context.pushNamed(RouteNames.exchangeAdd),
              ),
              OwRow(
                avatar: const OwAvatar(
                  label: '钥',
                  shape: OwAvatarShape.roundedSquare,
                ),
                title: l.accountAddImportTitle,
                subtitle: l.accountAddImportBody,
                trailing: chevron,
                // 保险库在另一个 Tab 分支里，用 go 切换。
                onTap: () => context.goNamed(RouteNames.vaultImport),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
