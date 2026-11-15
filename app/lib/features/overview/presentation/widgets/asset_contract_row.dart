import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../bootstrap/providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../widgets/ow_address_text.dart';
import '../../../../widgets/ow_row.dart';
import '../../../../widgets/ow_secondary_button.dart';
import '../../controllers/asset_detail_view.dart';

/// P09 合约地址列表中的一行。
class AssetContractRowTile extends ConsumerWidget {
  const AssetContractRowTile({super.key, required this.item});

  final AssetContractItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    return OwRow(
      title: item.chainName,
      subtitleWidget: OwAddressText(item.contract),
      trailing: OwSecondaryButton(
        label: l.assetDetailCopyContract,
        compact: true,
        onPressed: () {
          ref.read(clipboardWriterProvider)(item.contract);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l.assetDetailCopied),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }
}
