import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/bootstrap/foundation_providers.dart';
import 'package:onewallet/bootstrap/ui_services.dart';
import 'package:onewallet/bootstrap/vault_providers.dart';
import 'package:onewallet/features/vault/presentation/vault_import_page.dart';
import 'package:onewallet/l10n/app_localizations.dart';
import 'package:onewallet/theme/ow_theme.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:ow_platform/ow_platform.dart';
import 'package:ow_vault/ow_vault.dart';

// 测试使用的快速 KDF 参数
final fastKdf = KdfParams(memKib: 8, iterations: 1, parallelism: 1);

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
    // 在 Widget 测试中用同步 keyedHash 代替 runIsolated，避免 FakeAsync 拦截 Isolate ReceivePort 消息导致挂起
    final pwBytes = password.use(Uint8List.fromList);
    return delegate.keyedHash(salt, pwBytes, 32);
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

final class FakeScreenGuard implements ScreenGuard {
  bool enabled = false;

  @override
  Future<void> enable() async => enabled = true;

  @override
  Future<void> disable() async => enabled = false;

  @override
  Stream<bool> get captureActive => const Stream.empty();
}

final class FakePlatformCapabilities implements PlatformCapabilities {
  @override
  bool get biometrics => false;

  @override
  bool get hardwareKeystore => false;

  @override
  ScreenProtection get screenProtection => ScreenProtection.block;

  @override
  bool get camera => false;
}

final class InMemoryVaultStorage implements VaultStorage {
  Uint8List? _bytes;

  @override
  Future<Uint8List?> read() async => _bytes;

  @override
  Future<void> writeAtomic(Uint8List bytes) async => _bytes = bytes;

  @override
  Future<void> delete() async => _bytes = null;
}

final class FakeClock implements Clock {
  @override
  DateTime nowUtc() => DateTime.utc(2026, 11, 15);
}

final class InMemorySecretStore implements ClearableSecretStore {
  final _map = <String, String>{};

  @override
  Future<String?> read(String key) async => _map[key];

  @override
  Future<void> write(String key, String value) async => _map[key] = value;

  @override
  Future<void> delete(String key) async => _map.remove(key);

  @override
  Future<void> clearAll() async => _map.clear();
}

final class InMemorySettingsRepository implements SettingsRepository {
  var _settings = const AppSettings();

  Future<AppSettings> get() async => _settings;

  @override
  Stream<AppSettings> watch() => Stream.value(_settings);

  @override
  Future<void> update(AppSettings Function(AppSettings current) mutate) async {
    _settings = mutate(_settings);
  }
}

final class InMemoryVaultMetaRepository implements VaultMetaRepository {
  final _items = <VaultItemMeta>[];

  @override
  Stream<List<VaultItemMeta>> watchAll() =>
      Stream.value(List.unmodifiable(_items));

  Future<List<VaultItemMeta>> all() async => List.unmodifiable(_items);

  Future<VaultItemMeta?> byId(String id) async {
    for (final it in _items) {
      if (it.id == id) return it;
    }
    return null;
  }

  @override
  Future<VaultItemMeta?> byFingerprint(String fingerprint) async {
    for (final it in _items) {
      if (it.fingerprint == fingerprint) return it;
    }
    return null;
  }

  @override
  Future<void> upsert(VaultItemMeta meta) async {
    _items.removeWhere((i) => i.id == meta.id);
    _items.add(meta);
  }

  @override
  Future<void> delete(String id) async {
    _items.removeWhere((i) => i.id == id);
  }
}

final class InMemoryAccountRepository implements AccountRepository {
  final _accounts = <Account>[];

  @override
  Stream<List<Account>> watchAll() =>
      Stream.value(List.unmodifiable(_accounts));

  @override
  Future<Account?> byId(String id) async {
    for (final a in _accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  @override
  Future<void> upsert(Account account) async {
    _accounts.removeWhere((a) => a.id == account.id);
    _accounts.add(account);
  }

  @override
  Future<void> insertWithAddresses(
    Account account,
    List<WatchAddress> addresses,
  ) async {
    await upsert(account);
  }

  @override
  Future<void> delete(String id) async {
    _accounts.removeWhere((a) => a.id == id);
  }
}

final class SequentialIds implements IdGenerator {
  var _counter = 0;

  @override
  String newId() => 'id-${++_counter}';
}

final class UnsupportedHardwareKeyStore implements HardwareKeyStore {
  @override
  Future<Result<Uint8List>> wrap(String keyAlias, Uint8List plaintext) async =>
      const Err(UnsupportedFailure('unsupported'));

  @override
  Future<Result<Uint8List>> unwrap(
    String keyAlias,
    Uint8List wrapped, {
    required String reason,
  }) async => const Err(UnsupportedFailure('unsupported'));

  @override
  Future<void> delete(String keyAlias) async {}
}

// 12 词公开合法测试向量（abandon * 11 + about）
const valid12Mnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

// 64 字符十六进制合法测试私钥
const validEvmPrivateKey =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

void main() {
  late VaultCrypto crypto;
  late InMemoryVaultStorage storage;
  late InMemorySecretStore secretStore;
  late InMemorySettingsRepository settingsRepo;
  late InMemoryVaultMetaRepository vaultMetaRepo;
  late InMemoryAccountRepository accountRepo;
  late FakeScreenGuard screenGuard;
  late FakePlatformCapabilities capabilities;
  late SequentialIds ids;
  late FakeClock clock;
  late Vault vault;
  late VaultAccess vaultAccess;
  late ImportVaultItem importVaultItem;

  const masterPassword = 'testMasterPassword123';

  setUpAll(() async {
    crypto = SynchronousTestVaultCrypto(await SodiumVaultCrypto.load());
  });

  void initEnv() {
    storage = InMemoryVaultStorage();
    secretStore = InMemorySecretStore();
    settingsRepo = InMemorySettingsRepository();
    vaultMetaRepo = InMemoryVaultMetaRepository();
    accountRepo = InMemoryAccountRepository();
    screenGuard = FakeScreenGuard();
    capabilities = FakePlatformCapabilities();
    ids = SequentialIds();
    clock = FakeClock();

    vault = Vault(crypto: crypto, storage: storage, defaultParams: fastKdf);

    vaultAccess = VaultAccess(
      vault: vault,
      hardwareKeyStore: UnsupportedHardwareKeyStore(),
      secretStore: secretStore,
      capabilities: capabilities,
      settings: settingsRepo,
      passwordLimiter: AttemptLimiter(
        store: secretStore,
        clock: clock,
        keyPrefix: 'ow.vault.unlock',
      ),
    );

    importVaultItem = ImportVaultItem(
      vaultAccess: vaultAccess,
      vaultMetaRepo: vaultMetaRepo,
      accountRepo: accountRepo,
      settings: settingsRepo,
      ids: ids,
      clock: clock,
    );
  }

  setUp(() {
    // 保持轻量，对象在每个 testWidgets 内部通过 initEnv 构造，确保 AsyncMutex 等微任务处于同一个 FakeAsyncZone
  });

  Future<void> initVault() async {
    final sensitivePw = Sensitive(
      Uint8List.fromList(utf8.encode(masterPassword)),
    );
    final createRes = await vault.create(sensitivePw);
    createRes.valueOrNull!.close();
    sensitivePw.wipe();
  }

  Widget buildPage({String? linkToAccountId, String? clipboardText}) {
    return ProviderScope(
      overrides: [
        screenGuardProvider.overrideWithValue(screenGuard),
        platformCapabilitiesProvider.overrideWithValue(capabilities),
        settingsRepositoryProvider.overrideWithValue(settingsRepo),
        accountRepositoryProvider.overrideWithValue(accountRepo),
        clipboardReaderProvider.overrideWithValue(() async => clipboardText),
        importVaultItemProvider.overrideWith((ref) => importVaultItem),
      ],
      child: MaterialApp(
        theme: buildOwTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: VaultImportPage(linkToAccountId: linkToAccountId),
      ),
    );
  }

  testWidgets('初始渲染：默认助记词类型、12 词网格、名称输入框、保存按钮初始禁用', (tester) async {
    initEnv();
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    expect(find.text('导入到保险库'), findsOneWidget);
    expect(find.text('助记词'), findsWidgets);
    expect(find.text('私钥'), findsOneWidget);
    expect(find.text('12 词'), findsOneWidget);

    // 默认 12 个词格
    for (var i = 0; i < 12; i++) {
      expect(find.byKey(Key('mnemonic_word_$i')), findsOneWidget);
    }
    expect(find.byKey(const Key('mnemonic_word_12')), findsNothing);

    final buttonFinder = find.widgetWithText(FilledButton, '保存到保险库');
    expect(tester.widget<FilledButton>(buttonFinder).onPressed, isNull);

    // 验证防截屏已启用
    expect(screenGuard.enabled, isTrue);
  });

  testWidgets('助记词词表联想与自动跳格：输入 aba 显示 abandon 候选，点击候选自动填入第一格并跳格', (
    tester,
  ) async {
    initEnv();
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    final word0 = find.byKey(const Key('mnemonic_word_0'));
    await tester.enterText(word0, 'aba');
    await tester.pumpAndSettle();

    // 应该显示 abandon 候选词 chip
    final chipFinder = find.widgetWithText(ActionChip, 'abandon');
    expect(chipFinder, findsOneWidget);

    // 点击候选词
    await tester.tap(chipFinder);
    await tester.pumpAndSettle();

    // 第一格填入 abandon
    final field0 = tester.widget<TextField>(word0);
    expect(field0.controller?.text, 'abandon');

    // 焦点应该跳到第二格
    final word1 = find.byKey(const Key('mnemonic_word_1'));
    final field1 = tester.widget<TextField>(word1);
    expect(field1.focusNode?.hasFocus, isTrue);
  });

  testWidgets('整段粘贴：粘贴 12 词自动分词并填满全部 12 格', (tester) async {
    initEnv();
    await tester.pumpWidget(buildPage(clipboardText: valid12Mnemonic));
    await tester.pumpAndSettle();

    final pasteBtn = find.text('粘贴整段');
    expect(pasteBtn, findsOneWidget);
    await tester.tap(pasteBtn);
    await tester.pumpAndSettle();

    final words = valid12Mnemonic.split(' ');
    for (var i = 0; i < 12; i++) {
      final field = tester.widget<TextField>(
        find.byKey(Key('mnemonic_word_$i')),
      );
      expect(field.controller?.text, words[i]);
    }
  });

  testWidgets('助记词校验和失败提示：输入 12 个合法词但校验和不匹配，显示提示且按钮禁用', (tester) async {
    initEnv();
    // 12 个 'abandon' 校验和是错的（最后应该为 about）
    const badMnemonic =
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon';

    await tester.pumpWidget(buildPage(clipboardText: badMnemonic));
    await tester.pumpAndSettle();

    await tester.tap(find.text('粘贴整段'));
    await tester.pumpAndSettle();

    // 输入条目名称
    await tester.enterText(
      find.byKey(const Key('vault_import_name_field')),
      '我的钱包',
    );
    await tester.pumpAndSettle();

    expect(find.text('助记词校验失败，请检查拼写和顺序'), findsOneWidget);
    final buttonFinder = find.widgetWithText(FilledButton, '保存到保险库');
    expect(tester.widget<FilledButton>(buttonFinder).onPressed, isNull);
  });

  testWidgets('助记词合规输入并输入主密码后成功保存', (tester) async {
    initEnv();
    await initVault();
    await tester.pumpWidget(buildPage(clipboardText: valid12Mnemonic));
    await tester.pumpAndSettle();

    await tester.tap(find.text('粘贴整段'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('vault_import_name_field')),
      '主钱包助记词',
    );
    await tester.pumpAndSettle();

    final buttonFinder = find.widgetWithText(FilledButton, '保存到保险库');
    await tester.ensureVisible(buttonFinder);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(buttonFinder).onPressed, isNotNull);

    // 点击保存，弹出主密码验证对话框
    await tester.tap(buttonFinder);
    await tester.pumpAndSettle();

    expect(find.text('输入主密码'), findsOneWidget);

    // 在对话框中输入主密码
    final dialogField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(dialogField, masterPassword);
    await tester.pumpAndSettle();

    // 点击验证并保存
    await tester.tap(find.text('验证并保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 检查条目是否已写入元数据仓储
    final items = await vaultMetaRepo.all();
    expect(items.length, 1);
    expect(items.first.name, '主钱包助记词');
    expect(items.first.kind, VaultItemKind.mnemonic);
    expect(items.first.wordCount, 12);
  });

  testWidgets('私钥切换与格式校验：输入不合规私钥报错，合规私钥成功保存', (tester) async {
    initEnv();
    await initVault();
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    // 切换到私钥 tab
    await tester.tap(find.text('私钥'));
    await tester.pumpAndSettle();

    expect(find.text('链类型'), findsOneWidget);
    expect(find.text('EVM'), findsOneWidget);

    final keyField = find.byKey(const Key('vault_import_private_key_field'));

    // 输入不合规私钥
    await tester.enterText(keyField, 'invalid-hex');
    await tester.pumpAndSettle();

    expect(find.text('私钥格式不正确'), findsOneWidget);
    final buttonFinder = find.widgetWithText(FilledButton, '保存到保险库');
    expect(tester.widget<FilledButton>(buttonFinder).onPressed, isNull);

    // 输入合规 64 位十六进制私钥与名称
    await tester.enterText(keyField, validEvmPrivateKey);
    await tester.enterText(
      find.byKey(const Key('vault_import_name_field')),
      '单独以太坊私钥',
    );
    await tester.pumpAndSettle();

    expect(find.text('私钥格式不正确'), findsNothing);
    await tester.ensureVisible(buttonFinder);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(buttonFinder).onPressed, isNotNull);

    // 点击保存并输入主密码
    await tester.tap(buttonFinder);
    await tester.pumpAndSettle();

    final dialogField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(dialogField, masterPassword);
    await tester.pumpAndSettle();

    await tester.tap(find.text('验证并保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final items = await vaultMetaRepo.all();
    expect(items.length, 1);
    expect(items.first.name, '单独以太坊私钥');
    expect(items.first.kind, VaultItemKind.privateKey);
    expect(items.first.family, ChainFamily.evm);
  });

  testWidgets('重复导入被拒绝：导入相同助记词时提示重复错误', (tester) async {
    initEnv();
    await initVault();
    // 先写入一个相同助记词条目
    final mRes = normalizeMnemonic(
      Sensitive(Uint8List.fromList(utf8.encode(valid12Mnemonic))),
    );
    final normM = mRes.valueOrNull!;
    final sessionRes = await vault.unlockWithPassword(
      Sensitive(Uint8List.fromList(utf8.encode(masterPassword))),
    );
    final session = sessionRes.valueOrNull!;
    final secret = MnemonicSecret(mnemonic: normM);
    final fp = session.fingerprintOf(secret);
    await session.addItem('item-exist', secret);
    session.close();
    normM.wipe();

    await vaultMetaRepo.upsert(
      VaultItemMeta(
        id: 'item-exist',
        name: '已有助记词',
        kind: VaultItemKind.mnemonic,
        hasPassphrase: false,
        fingerprint: fp,
        createdAt: DateTime.now().toUtc(),
      ),
    );

    // 页面尝试导入相同助记词
    await tester.pumpWidget(buildPage(clipboardText: valid12Mnemonic));
    await tester.pumpAndSettle();

    await tester.tap(find.text('粘贴整段'));
    await tester.enterText(
      find.byKey(const Key('vault_import_name_field')),
      '新名字',
    );
    await tester.pumpAndSettle();

    final buttonFinder = find.widgetWithText(FilledButton, '保存到保险库');
    await tester.ensureVisible(buttonFinder);
    await tester.pumpAndSettle();
    await tester.tap(buttonFinder);
    await tester.pumpAndSettle();

    final dialogField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(dialogField, masterPassword);
    await tester.pumpAndSettle();

    await tester.tap(find.text('验证并保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 应该显示重复错误提示
    expect(find.text('该密钥已存在于保险库中'), findsOneWidget);
  });

  testWidgets('AppLifecycleState.paused 时清空敏感输入', (tester) async {
    initEnv();
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    final word0 = find.byKey(const Key('mnemonic_word_0'));
    await tester.enterText(word0, 'abandon');
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(word0).controller?.text, 'abandon');

    // 模拟应用切入后台
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();

    // 输入应已被清空
    expect(tester.widget<TextField>(word0).controller?.text, isEmpty);
  });
}
