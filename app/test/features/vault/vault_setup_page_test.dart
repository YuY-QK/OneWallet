import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/bootstrap/base_services.dart';
import 'package:onewallet/bootstrap/foundation_providers.dart';
import 'package:onewallet/bootstrap/vault_providers.dart';
import 'package:onewallet/features/vault/presentation/vault_setup_page.dart';
import 'package:onewallet/l10n/app_localizations.dart';
import 'package:onewallet/theme/ow_theme.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:ow_platform/ow_platform.dart';
import 'package:ow_vault/ow_vault.dart';

import '../../bootstrap/support.dart';
import '../../support/fakes.dart';

final class _MemoryVaultStorage implements VaultStorage {
  Uint8List? _bytes;

  @override
  Future<Uint8List?> read() async =>
      _bytes == null ? null : Uint8List.fromList(_bytes!);

  @override
  Future<void> writeAtomic(Uint8List data) async {
    _bytes = Uint8List.fromList(data);
  }

  @override
  Future<void> delete() async {
    _bytes = null;
  }
}

void main() {
  late SodiumVaultCrypto crypto;
  late FakeSettingsRepository settings;
  late _MemoryVaultStorage storage;
  late Vault vault;
  late FakeSecretStore secretStore;
  late AttemptLimiter limiter;
  late VaultAccess access;
  late CreateVault createVault;
  const clock = SystemClock();
  final fastKdf = KdfParams(memKib: 8, iterations: 1, parallelism: 1);

  setUpAll(() async {
    crypto = await SodiumVaultCrypto.load();
  });

  setUp(() {
    settings = FakeSettingsRepository();
    storage = _MemoryVaultStorage();
    vault = Vault(crypto: crypto, storage: storage, defaultParams: fastKdf);
    secretStore = FakeSecretStore();
    limiter = AttemptLimiter(
      store: secretStore,
      clock: clock,
      keyPrefix: 'ow.vault.unlock',
    );
    access = VaultAccess(
      vault: vault,
      hardwareKeyStore: DeviceHardwareKeyStore(),
      secretStore: secretStore,
      capabilities: FakePlatformCapabilities(),
      settings: settings,
      passwordLimiter: limiter,
    );
    createVault = CreateVault(
      vault: vault,
      vaultAccess: access,
      capabilities: FakePlatformCapabilities(),
      settings: settings,
      clock: clock,
    );
  });

  Widget buildPage() {
    return ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settings),
        vaultStorageProvider.overrideWithValue(storage),
        vaultAccessProvider.overrideWith((ref) async => access),
        createVaultProvider.overrideWith((ref) async => createVault),
        platformCapabilitiesProvider.overrideWithValue(
          FakePlatformCapabilities(),
        ),
      ],
      child: MaterialApp(
        theme: buildOwTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const VaultSetupPage(),
      ),
    );
  }

  testWidgets('主密码少于10字符或不一致或未勾选确认时按钮禁用', (tester) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    final buttonFinder = find.widgetWithText(FilledButton, '创建保险库');
    expect(tester.widget<FilledButton>(buttonFinder).onPressed, isNull);

    final pwField = find.byKey(const Key('vault_setup_password_field'));
    final confirmField = find.byKey(const Key('vault_setup_confirm_field'));

    // 输入 8 个字符（太短）
    await tester.enterText(pwField, 'short123');
    await tester.enterText(confirmField, 'short123');
    await tester.pumpAndSettle();

    expect(find.text('主密码长度至少为 10 个字符'), findsOneWidget);
    expect(tester.widget<FilledButton>(buttonFinder).onPressed, isNull);

    // 输入密码不一致
    await tester.enterText(pwField, 'validpassword123');
    await tester.enterText(confirmField, 'differentpassword123');
    await tester.pumpAndSettle();

    expect(find.text('两次输入的密码不一致'), findsOneWidget);
    expect(tester.widget<FilledButton>(buttonFinder).onPressed, isNull);

    // 输入一致但未勾选
    await tester.enterText(confirmField, 'validpassword123');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(buttonFinder).onPressed, isNull);

    // 勾选确认
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(buttonFinder).onPressed, isNotNull);
  });

  testWidgets('输入合规密码并勾选后成功创建保险库', (tester) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    final pwField = find.byKey(const Key('vault_setup_password_field'));
    final confirmField = find.byKey(const Key('vault_setup_confirm_field'));
    await tester.enterText(pwField, 'correct-horse-battery-staple');
    await tester.enterText(confirmField, 'correct-horse-battery-staple');
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();

    final buttonFinder = find.widgetWithText(FilledButton, '创建保险库');
    await tester.ensureVisible(buttonFinder);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(buttonFinder).onPressed, isNotNull);

    await tester.runAsync(() async {
      await tester.tap(buttonFinder);
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        if (await storage.read() != null) break;
      }
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(await storage.read(), isNotNull);
    expect(find.text('保险库已成功创建'), findsOneWidget);
  });
}
