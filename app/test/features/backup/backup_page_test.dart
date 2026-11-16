import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onewallet/bootstrap/foundation_providers.dart';
import 'package:onewallet/bootstrap/vault_providers.dart';
import 'package:onewallet/features/backup/application/backup_providers.dart';
import 'package:onewallet/features/backup/presentation/backup_export_page.dart';
import 'package:onewallet/features/backup/presentation/backup_page.dart';
import 'package:onewallet/features/backup/presentation/backup_restore_page.dart';
import 'package:onewallet/features/settings/presentation/settings_page.dart';
import 'package:onewallet/features/vault/presentation/vault_page.dart';
import 'package:onewallet/l10n/app_localizations.dart';
import 'package:onewallet/router/app_router.dart';
import 'package:onewallet/router/route_names.dart';
import 'package:onewallet/theme/ow_theme.dart';
import 'package:onewallet/widgets/ow_pill.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:ow_vault/ow_vault.dart';

import '../../support/fakes.dart';

final class SynchronousTestVaultCrypto implements VaultCrypto {
  SynchronousTestVaultCrypto(this.delegate);
  final VaultCrypto delegate;

  @override
  Uint8List randomBytes(int length) => delegate.randomBytes(length);

  @override
  Future<Uint8List> argon2id(
    Sensitive password,
    Uint8List salt,
    KdfParams params,
  ) async {
    final pwBytes = password.use(Uint8List.fromList);
    final res = delegate.keyedHash(salt, pwBytes, 32);
    return res;
  }

  @override
  Uint8List aeadEncrypt(
    Uint8List key,
    Uint8List nonce,
    Uint8List plaintext,
    Uint8List aad,
  ) => delegate.aeadEncrypt(key, nonce, plaintext, aad);

  @override
  Result<Uint8List> aeadDecrypt(
    Uint8List key,
    Uint8List nonce,
    Uint8List ciphertext,
    Uint8List aad,
  ) => delegate.aeadDecrypt(key, nonce, ciphertext, aad);

  @override
  Uint8List deriveSubkey(Uint8List masterKey, String context8, int subkeyId) =>
      delegate.deriveSubkey(masterKey, context8, subkeyId);

  @override
  Uint8List keyedHash(Uint8List key, Uint8List message, int outputLength) =>
      delegate.keyedHash(key, message, outputLength);

  @override
  bool constantTimeEquals(Uint8List a, Uint8List b) =>
      delegate.constantTimeEquals(a, b);
}

final class MemoryVaultStorage implements VaultStorage {
  Uint8List? _data;
  @override
  Future<Uint8List?> read() async => _data;
  @override
  Future<void> writeAtomic(Uint8List data) async =>
      _data = Uint8List.fromList(data);
  @override
  Future<void> delete() async => _data = null;
}

final class FakeHardwareKeyStore implements HardwareKeyStore {
  final _wrapped = <String, Uint8List>{};

  @override
  Future<Result<Uint8List>> wrap(String keyAlias, Uint8List plaintext) async {
    _wrapped[keyAlias] = Uint8List.fromList(plaintext);
    return Ok(Uint8List.fromList(plaintext));
  }

  @override
  Future<Result<Uint8List>> unwrap(
    String keyAlias,
    Uint8List wrapped, {
    required String reason,
  }) async {
    final data = _wrapped[keyAlias];
    if (data == null) return const Err(UnknownFailure('key not found'));
    return Ok(Uint8List.fromList(data));
  }

  @override
  Future<void> delete(String keyAlias) async => _wrapped.remove(keyAlias);
}

final class FakeBackupFileHandler implements BackupFileHandler {
  SelectedBackupFile? fileToPick;
  final sharedFiles = <({Uint8List bytes, String filename})>[];

  @override
  Future<SelectedBackupFile?> pickBackupFile() async => fileToPick;

  @override
  Future<bool> shareFile({
    required Uint8List bytes,
    required String filename,
  }) async {
    sharedFiles.add((bytes: bytes, filename: filename));
    return true;
  }
}

final class _TestVaultMetaRepo implements VaultMetaRepository {
  final Map<String, VaultItemMeta> _items = {};

  @override
  Future<VaultItemMeta?> byFingerprint(String fingerprint) async {
    for (final m in _items.values) {
      if (m.fingerprint == fingerprint) return m;
    }
    return null;
  }

  @override
  Future<void> upsert(VaultItemMeta meta) async {
    _items[meta.id] = meta;
  }

  @override
  Future<void> delete(String id) async {
    _items.remove(id);
  }

  @override
  Stream<List<VaultItemMeta>> watchAll() {
    return Stream.value(_items.values.toList());
  }
}

final class _TestCredentialRepo implements CredentialRepository {
  final Map<String, ExchangeCredentials> _creds = {};

  @override
  Future<void> save(String accountId, ExchangeCredentials c) async {
    _creds[accountId] = c;
  }

  @override
  Future<ExchangeCredentials?> load(String accountId) async {
    return _creds[accountId];
  }

  @override
  Future<void> delete(String accountId) async {
    _creds.remove(accountId);
  }
}

void main() {
  late SodiumVaultCrypto sodiumCrypto;
  late SynchronousTestVaultCrypto crypto;
  late TestRig rig;
  late FakeHardwareKeyStore hardwareStore;
  late MemoryVaultStorage vaultStorage;
  late Vault vault;
  late VaultAccess vaultAccess;
  late FakeBackupFileHandler fileHandler;
  late _TestVaultMetaRepo vaultMetaRepo;
  late _TestCredentialRepo credentialRepo;

  late ExportBackup exportBackup;
  late ConfirmBackupSaved confirmBackupSaved;
  late OpenBackup openBackup;
  late RestoreBackup restoreBackup;

  const masterPassword = 'testMasterPassword123';
  const backupPassword = 'testBackupPassword123';

  setUpAll(() async {
    sodiumCrypto = await SodiumVaultCrypto.load();
  });

  setUp(() async {
    crypto = SynchronousTestVaultCrypto(sodiumCrypto);
    rig = TestRig();
    fileHandler = FakeBackupFileHandler();
    hardwareStore = FakeHardwareKeyStore();
    vaultStorage = MemoryVaultStorage();
    vaultMetaRepo = _TestVaultMetaRepo();
    credentialRepo = _TestCredentialRepo();

    vault = Vault(
      storage: vaultStorage,
      crypto: crypto,
      defaultParams: KdfParams(memKib: 8, iterations: 1),
    );

    vaultAccess = VaultAccess(
      vault: vault,
      hardwareKeyStore: hardwareStore,
      secretStore: rig.secrets,
      capabilities: rig.capabilities,
      settings: rig.settings,
      passwordLimiter: AttemptLimiter(
        store: rig.secrets,
        clock: rig.clock,
        keyPrefix: 'ow.vault.master',
      ),
    );

    exportBackup = ExportBackup(
      vaultAccess: vaultAccess,
      vaultMetaRepo: vaultMetaRepo,
      accountRepo: rig.accounts,
      addressRepo: rig.addresses,
      credentialRepo: credentialRepo,
      settings: rig.settings,
      crypto: crypto,
      clock: rig.clock,
      appVersion: '1.0.0',
    );

    confirmBackupSaved = ConfirmBackupSaved(
      settings: rig.settings,
      clock: rig.clock,
    );

    openBackup = OpenBackup(crypto: crypto);

    restoreBackup = RestoreBackup(
      vault: vault,
      vaultAccess: vaultAccess,
      vaultMetaRepo: vaultMetaRepo,
      accountRepo: rig.accounts,
      addressRepo: rig.addresses,
      credentialRepo: credentialRepo,
      settings: rig.settings,
      ids: rig.ids,
      clock: rig.clock,
    );
  });

  Widget buildAppWithRouter({required String initialLocation}) {
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: AppRoutes.settings,
          name: RouteNames.settings,
          builder: (_, _) => const SettingsPage(),
          routes: [
            GoRoute(
              path: 'backup',
              name: RouteNames.backup,
              builder: (_, _) => const BackupPage(),
              routes: [
                GoRoute(
                  path: 'export',
                  name: RouteNames.backupExport,
                  builder: (_, state) => BackupExportPage(
                    includeExchangeCredentials:
                        state.uri.queryParameters['includeExchange'] == 'true',
                  ),
                ),
                GoRoute(
                  path: 'restore',
                  name: RouteNames.backupRestore,
                  builder: (_, state) => BackupRestorePage(
                    mode: state.uri.queryParameters['mode'] == 'fresh'
                        ? RestoreMode.fresh
                        : RestoreMode.merge,
                  ),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.vault,
          name: RouteNames.vault,
          builder: (_, _) => const VaultPage(),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        ...rig.overrides,
        vaultCryptoProvider.overrideWith((ref) => crypto),
        vaultProvider.overrideWith((ref) => vault),
        vaultAccessProvider.overrideWith((ref) => vaultAccess),
        vaultMetaRepositoryProvider.overrideWith((ref) => vaultMetaRepo),
        credentialRepositoryProvider.overrideWith((ref) => credentialRepo),
        backupFileHandlerProvider.overrideWith((ref) => fileHandler),
        exportBackupProvider.overrideWith((ref) => exportBackup),
        confirmBackupSavedProvider.overrideWith((ref) => confirmBackupSaved),
        openBackupProvider.overrideWith((ref) => openBackup),
        restoreBackupProvider.overrideWith((ref) => restoreBackup),
      ],
      child: MaterialApp.router(
        theme: buildOwTheme(Brightness.light),
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  group('P18 设置页入口与未备份状态', () {
    testWidgets('未导出备份时展示尚未备份', (tester) async {
      await tester.pumpWidget(
        buildAppWithRouter(initialLocation: AppRoutes.settings),
      );
      await tester.pumpAndSettle();

      expect(find.text('加密备份'), findsOneWidget);
      expect(find.text('尚未备份'), findsOneWidget);
    });

    testWidgets('有未备份更改时展示橙色徽标并可跳转P17', (tester) async {
      await rig.settings.update(
        (s) => s.copyWith(
          vaultChangedAt: DateTime.utc(2026, 11, 15, 10),
          lastBackupExportedAt: DateTime.utc(2026, 11, 10, 10),
        ),
      );

      await tester.pumpWidget(
        buildAppWithRouter(initialLocation: AppRoutes.settings),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(OwPill, '有未备份的更改'), findsOneWidget);

      await tester.tap(find.text('加密备份'));
      await tester.pumpAndSettle();

      expect(find.text('确认内容'), findsOneWidget);
      expect(find.text('开始导出'), findsOneWidget);
    });
  });

  group('P12 保险库未备份提醒条 (M5-05, R38)', () {
    testWidgets('保险库存在条目且有未备份更改时展示提醒条，点击跳转到P17', (tester) async {
      rig.isVaultInitialized = true;
      rig.vaultItems = [
        VaultItemSummary(
          meta: VaultItemMeta(
            id: 'item1',
            name: '我的主助记词',
            kind: VaultItemKind.mnemonic,
            fingerprint: 'fp1',
            hasPassphrase: false,
            createdAt: DateTime.utc(2026, 11, 1),
          ),
          linkedAccountIds: const ['acc1'],
          linkedAccountNames: const ['我的主钱包'],
        ),
      ];
      await rig.settings.update(
        (s) => s.copyWith(
          vaultChangedAt: DateTime.utc(2026, 11, 15, 10),
          lastBackupExportedAt: null,
        ),
      );

      await tester.pumpWidget(
        buildAppWithRouter(initialLocation: AppRoutes.vault),
      );
      await tester.pumpAndSettle();

      expect(find.text('保险库有未备份的更改，建议及时导出备份'), findsOneWidget);
      expect(find.text('去备份'), findsOneWidget);

      await tester.tap(find.text('去备份'));
      await tester.pumpAndSettle();

      expect(find.text('确认内容'), findsOneWidget);
    });
  });

  group('P17 导出流程 (M5-03)', () {
    setUp(() async {
      rig.isVaultInitialized = true;
      final sensitive = Sensitive(
        Uint8List.fromList(utf8.encode(masterPassword)),
      );
      final res = await vault.create(sensitive);
      sensitive.wipe();
      if (res case Ok(:final value)) {
        value.close();
      }
    });

    testWidgets('密码错误提示当前主密码不正确', (tester) async {
      await tester.pumpWidget(
        buildAppWithRouter(initialLocation: '/settings/backup/export'),
      );
      await tester.pumpAndSettle();

      expect(find.text('导出备份'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'wrongPassword123');

      await tester.tap(find.text('开始导出'));
      await tester.pump();
      await tester.runAsync(() async {
        for (var i = 0; i < 50; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          if (find.text('当前主密码不正确').evaluate().isNotEmpty) break;
        }
      });
      await tester.pump();

      expect(find.text('当前主密码不正确'), findsOneWidget);
    });

    testWidgets('自定义备份密码不一致与过短校验', (tester) async {
      await tester.pumpWidget(
        buildAppWithRouter(initialLocation: '/settings/backup/export'),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, masterPassword);
      await tester.tap(find.text('另设备份密码'));
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(3));

      // 过短
      await tester.enterText(fields.at(1), 'short');
      await tester.enterText(fields.at(2), 'short');
      await tester.ensureVisible(find.text('开始导出'));
      await tester.tap(find.text('开始导出'));
      await tester.pumpAndSettle();

      expect(find.text('备份密码长度至少为 10 个字符'), findsOneWidget);

      // 不一致
      await tester.enterText(fields.at(1), 'newPassword123');
      await tester.enterText(fields.at(2), 'mismatchPassword');
      await tester.ensureVisible(find.text('开始导出'));
      await tester.tap(find.text('开始导出'));
      await tester.pumpAndSettle();

      expect(find.text('两次输入的备份密码不一致'), findsOneWidget);
    });

    testWidgets('成功导出备份、调起分享并确认已保存', (tester) async {
      await tester.pumpWidget(
        buildAppWithRouter(initialLocation: '/settings/backup/export'),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, masterPassword);

      await tester.tap(find.text('开始导出'));
      await tester.pump();
      await tester.runAsync(() async {
        for (var i = 0; i < 50; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          if (find.text('备份已生成').evaluate().isNotEmpty) break;
        }
      });
      await tester.pumpAndSettle();

      expect(find.text('备份已生成'), findsOneWidget);
      expect(fileHandler.sharedFiles, hasLength(1));
      expect(
        fileHandler.sharedFiles.first.filename,
        startsWith('OneWallet-备份-'),
      );

      // 验证未点击确认保存前，lastBackupExportedAt 为 null
      expect(rig.settings.feed.value.lastBackupExportedAt, isNull);

      // 点击确认保存
      await tester.tap(find.text('我已保存到安全位置'));
      await tester.pumpAndSettle();

      expect(
        rig.settings.feed.value.lastBackupExportedAt,
        equals(rig.clock.nowUtc()),
      );
    });
  });

  group('P17 恢复流程 (M5-04)', () {
    late Uint8List validBackupBytes;

    setUp(() async {
      // 准备一份合法备份
      rig.isVaultInitialized = true;
      final sensitive = Sensitive(
        Uint8List.fromList(utf8.encode(masterPassword)),
      );
      final res = await vault.create(sensitive);
      sensitive.wipe();
      if (res case Ok(:final value)) {
        value.close();
      }

      final backupSensitive = Sensitive(
        Uint8List.fromList(utf8.encode(backupPassword)),
      );
      final masterSensitive = Sensitive(
        Uint8List.fromList(utf8.encode(masterPassword)),
      );
      final exportedRes = await exportBackup(
        masterCredential: PasswordCredential(masterSensitive),
        backupPassword: backupSensitive,
        includeExchangeCredentials: false,
      );
      masterSensitive.wipe();
      backupSensitive.wipe();

      validBackupBytes = (exportedRes as Ok<ExportedBackup>).value.bytes;
    });

    testWidgets('合并模式：文件选取、错误密码与成功解析预览与合并导入', (tester) async {
      fileHandler.fileToPick = SelectedBackupFile(
        bytes: validBackupBytes,
        name: 'test.owbak',
      );

      await tester.pumpWidget(
        buildAppWithRouter(
          initialLocation: '/settings/backup/restore?mode=merge',
        ),
      );
      await tester.pumpAndSettle();

      // 点击选取文件
      await tester.tap(find.text('选择 .owbak 备份文件'));
      await tester.pumpAndSettle();

      expect(find.textContaining('test.owbak'), findsOneWidget);

      // 输入错误密码
      await tester.enterText(find.byType(TextField), 'wrongBackupPassword');
      await tester.tap(find.text('解析备份文件'));
      await tester.pumpAndSettle();

      expect(find.text('密码不正确或文件已损坏'), findsOneWidget);

      // 输入正确密码
      await tester.enterText(find.byType(TextField), backupPassword);
      await tester.tap(find.text('解析备份文件'));
      await tester.pumpAndSettle();

      expect(find.text('备份内容预览'), findsOneWidget);
      expect(find.text('合并导入'), findsOneWidget);

      // 输入本地主密码并开始恢复
      await tester.enterText(find.byType(TextField).last, masterPassword);
      await tester.tap(find.text('开始恢复'));
      await tester.pumpAndSettle();

      expect(find.text('恢复完成'), findsOneWidget);
      expect(find.textContaining('成功导入'), findsOneWidget);

      // 完成
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
    });

    testWidgets('全新模式：首次引导模式恢复', (tester) async {
      fileHandler.fileToPick = SelectedBackupFile(
        bytes: validBackupBytes,
        name: 'test_fresh.owbak',
      );

      await tester.pumpWidget(
        buildAppWithRouter(
          initialLocation: '/settings/backup/restore?mode=fresh',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('选择 .owbak 备份文件'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), backupPassword);
      await tester.tap(find.text('解析备份文件'));
      await tester.pumpAndSettle();

      expect(find.text('备份内容预览'), findsOneWidget);
      expect(find.text('全新设备恢复'), findsOneWidget);
    });
  });
}
