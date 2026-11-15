import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/bootstrap/vault_providers.dart';
import 'package:onewallet/features/vault/presentation/vault_page.dart';
import 'package:onewallet/l10n/app_localizations.dart';
import 'package:onewallet/theme/ow_theme.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';

void main() {
  Widget buildPage({
    required bool isInitialized,
    List<VaultItemSummary> items = const [],
  }) {
    return ProviderScope(
      overrides: [
        isVaultInitializedProvider.overrideWith((ref) => isInitialized),
        vaultItemsProvider.overrideWith((ref) => Stream.value(items)),
      ],
      child: MaterialApp(
        theme: buildOwTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const VaultPage(),
      ),
    );
  }

  testWidgets('未初始化时显示启用保险库介绍与操作按钮', (tester) async {
    await tester.pumpWidget(buildPage(isInitialized: false));
    await tester.pumpAndSettle();

    expect(find.text('保险库尚未启用'), findsOneWidget);
    expect(find.text('启用保险库'), findsOneWidget);
    expect(find.text('保险库把助记词和私钥加密保存在这台设备上，不会联网。'), findsOneWidget);
  });

  testWidgets('已初始化但无条目时显示空状态与添加按钮', (tester) async {
    await tester.pumpWidget(buildPage(isInitialized: true, items: []));
    await tester.pumpAndSettle();

    expect(find.text('暂无密钥条目'), findsOneWidget);
    expect(find.text('点击右上角「＋」导入第一个助记词或私钥。'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
  });

  testWidgets('已初始化且有条目时显示列表内容与安全底注', (tester) async {
    final items = [
      VaultItemSummary(
        meta: VaultItemMeta(
          id: 'item-1',
          name: '主助记词',
          kind: VaultItemKind.mnemonic,
          fingerprint: 'fp-1',
          hasPassphrase: true,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
        linkedAccountIds: ['acc-1'],
        linkedAccountNames: ['Uni 钱包'],
      ),
      VaultItemSummary(
        meta: VaultItemMeta(
          id: 'item-2',
          name: '单独私钥',
          kind: VaultItemKind.privateKey,
          fingerprint: 'fp-2',
          hasPassphrase: false,
          createdAt: DateTime.utc(2026, 1, 2),
        ),
        linkedAccountIds: [],
        linkedAccountNames: [],
      ),
    ];

    await tester.pumpWidget(buildPage(isInitialized: true, items: items));
    await tester.pumpAndSettle();

    expect(find.text('主助记词'), findsOneWidget);
    expect(find.text('助记词 · 含密码 · Uni 钱包'), findsOneWidget);
    expect(find.text('单独私钥'), findsOneWidget);
    expect(find.text('私钥'), findsOneWidget);
    expect(find.text('保险库内容仅存于本机。请定期导出加密备份。'), findsOneWidget);
  });
}
