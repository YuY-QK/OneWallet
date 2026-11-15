import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../router/route_names.dart';
import '../../../../theme/ow_colors.dart';
import '../../../../theme/ow_text_styles.dart';
import '../../../../widgets/formatters.dart';
import '../../../../widgets/ow_amount_text.dart';
import '../../../../widgets/ow_avatar.dart';
import '../../../../widgets/ow_row.dart';
import '../../../shared/labels.dart';
import '../../controllers/asset_detail_view.dart';

/// P09 币种分布列表中的一行。
class AssetDistributionRowTile extends StatelessWidget {
  const AssetDistributionRowTile({
    super.key,
    required this.item,
    required this.quote,
    required this.hidden,
  });

  final AssetDistributionItem item;
  final Quote quote;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final c = context.ow;
    final l = AppLocalizations.of(context)!;
    final account = item.account;
    final isWallet = account.type == AccountType.wallet;

    final locationText = switch (item.location) {
      OnChainLocation(:final chainId) =>
        Chains.tryById(chainId)?.name ?? chainId,
      ExchangeLocation(:final sub) => subAccountLabel(l, sub),
    };

    final sharePercent = '${item.share.toStringAsFixed(1)}%';

    return OwRow(
      avatar: OwAvatar(
        label: avatarMark(account.name),
        shape: isWallet ? OwAvatarShape.circle : OwAvatarShape.roundedSquare,
      ),
      title: account.name,
      subtitle: locationText,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          OwAmountText(
            formatQuantity(item.amount),
            hidden: hidden,
            style: OwTextStyles.mono,
          ),
          const SizedBox(height: 2),
          Text(
            item.value != null
                ? '${formatFiat(item.value!, symbol: fiatSymbol(quote), hidden: hidden)} · $sharePercent'
                : sharePercent,
            style: OwTextStyles.caption.copyWith(color: c.muted),
          ),
        ],
      ),
      onTap: () {
        if (isWallet) {
          context.goNamed(
            RouteNames.walletDetail,
            pathParameters: {'id': account.id},
          );
        } else {
          context.goNamed(
            RouteNames.exchangeDetail,
            pathParameters: {'id': account.id},
          );
        }
      },
    );
  }
}
