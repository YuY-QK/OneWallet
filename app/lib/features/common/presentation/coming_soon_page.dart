import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../widgets/empty_state.dart';

/// 尚未实现的功能的说明页：显示"此功能将在后续版本提供"。
///
/// 用于预留路由（交易所、导入密钥、币种详情、交易所账户详情）。
class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({super.key, required this.title});

  /// 顶栏标题。
  final String title;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: EmptyState(
        icon: Icons.hourglass_empty_rounded,
        title: l.comingSoonTitle,
        body: l.comingSoonBody,
      ),
    );
  }
}
