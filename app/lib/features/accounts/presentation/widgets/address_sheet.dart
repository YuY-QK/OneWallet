import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../bootstrap/providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/ow_colors.dart';
import '../../../../theme/ow_text_styles.dart';
import '../../../../widgets/ow_address_text.dart';
import '../../../../widgets/ow_danger_button.dart';
import '../../../../widgets/ow_list_group.dart';
import '../../../../widgets/ow_row.dart';
import '../../../../widgets/ow_secondary_button.dart';
import '../../../shared/labels.dart';
import '../../controllers/wallet_detail_controller.dart';

/// 地址操作面板（底部弹层）：完整地址、二维码、复制、在区块浏览器中打开、删除。
Future<void> showAddressSheet(
  BuildContext context, {
  required WatchAddress address,
  required bool canDelete,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => AddressSheet(address: address, canDelete: canDelete),
);

/// 区块浏览器入口：某条链上该地址的页面。
class ExplorerLink {
  const ExplorerLink({required this.chain, required this.url});

  final ChainInfo chain;
  final Uri url;

  /// 打开前显示给用户的完整域名。
  String get host => url.host;
}

/// 由链定义的 `explorerAddressUrl` 模板生成各启用链的浏览器链接。
/// 模板是内置常量（https）；生成结果不是 https 时丢弃。
List<ExplorerLink> explorerLinks(WatchAddress address, String displayAddress) {
  final links = <ExplorerLink>[];
  for (final chain in Chains.all) {
    if (!address.enabledChainIds.contains(chain.id)) continue;
    final url = Uri.tryParse(
      chain.explorerAddressUrl.replaceAll('{address}', displayAddress),
    );
    if (url == null || url.scheme != 'https' || url.host.isEmpty) continue;
    links.add(ExplorerLink(chain: chain, url: url));
  }
  return links;
}

/// 面板内容。
class AddressSheet extends ConsumerStatefulWidget {
  const AddressSheet({
    super.key,
    required this.address,
    required this.canDelete,
  });

  final WatchAddress address;

  /// 账户还有其他地址时才允许删除。
  final bool canDelete;

  @override
  ConsumerState<AddressSheet> createState() => _AddressSheetState();
}

class _AddressSheetState extends ConsumerState<AddressSheet> {
  bool _copied = false;
  bool _openFailed = false;

  String get _display => ref
      .read(addressCodecProvider)
      .display(widget.address.address, widget.address.family);

  Future<void> _copy() async {
    await ref.read(clipboardWriterProvider)(_display);
    if (mounted) setState(() => _copied = true);
  }

  Future<void> _open(ExplorerLink link) async {
    final ok = await ref.read(externalUrlOpenerProvider)(link.url);
    if (mounted) setState(() => _openFailed = !ok);
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.addressSheetDeleteTitle),
        content: Text(l.addressSheetDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.addressSheetCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: context.ow.down),
            child: Text(l.addressSheetDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final actions = ref.read(
      walletDetailActionsProvider(widget.address.accountId),
    );
    final done = await actions.deleteAddress(widget.address.id);
    if (done && mounted) Navigator.pop(context);
  }

  String? _exclusionNotice(AppLocalizations l) =>
      switch (widget.address.family) {
        ChainFamily.bitcoin => l.addressSheetExcludedBtc,
        ChainFamily.solana => l.addressSheetExcludedSol,
        ChainFamily.tron => l.addressSheetExcludedTron,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.ow;
    final display = _display;
    final links = explorerLinks(widget.address, display);
    final notice = _exclusionNotice(l);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.addressSheetTitle(chainFamilyLabel(l, widget.address.family)),
              style: OwTextStyles.emphasis,
            ),
            const SizedBox(height: 12),
            Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: QrImageView(
                    data: display,
                    size: 168,
                    backgroundColor: Colors.white,
                    semanticsLabel: display,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            OwAddressText(display, full: true, textAlign: TextAlign.center),
            if (notice != null) ...[
              const SizedBox(height: 6),
              Text(
                notice,
                style: OwTextStyles.caption.copyWith(color: c.muted),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 12),
            OwSecondaryButton(
              label: _copied ? l.addressSheetCopied : l.addressSheetCopy,
              onPressed: _copy,
            ),
            const SizedBox(height: 16),
            Text(
              l.addressSheetExplorerHeader,
              style: OwTextStyles.caption.copyWith(color: c.muted),
            ),
            const SizedBox(height: 6),
            OwListGroup(
              children: [
                for (final link in links)
                  OwRow(
                    title: l.addressSheetExplorerRow(
                      link.chain.name,
                      link.host,
                    ),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                    onTap: () => _open(link),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _openFailed
                    ? l.addressSheetOpenFailed
                    : l.addressSheetExplorerNote,
                style: OwTextStyles.caption.copyWith(
                  color: _openFailed ? c.down : c.muted,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!widget.canDelete)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l.addressSheetDeleteLast,
                  style: OwTextStyles.caption.copyWith(color: c.muted),
                ),
              ),
            OwDangerButton(
              label: l.addressSheetDelete,
              onPressed: widget.canDelete ? _delete : null,
            ),
          ],
        ),
      ),
    );
  }
}
