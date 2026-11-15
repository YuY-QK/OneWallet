import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/bootstrap/foundation_providers.dart';
import 'package:onewallet/bootstrap/vault_providers.dart';
import 'package:onewallet/features/vault/presentation/vault_item_detail_page.dart';
import 'package:onewallet/l10n/app_localizations.dart';
import 'package:onewallet/theme/ow_theme.dart';
import 'package:onewallet/widgets/ow_mnemonic_grid.dart';
import 'package:onewallet/widgets/ow_veil.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:ow_vault/ow_vault.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
  final _captureController = StreamController<bool>.broadcast();

  @override
  Future<void> enable() async => enabled = true;

  @override
  Future<void> disable() async => enabled = false;

  @override
  Stream<bool> get captureActive => _captureController.stream;

  void emitCapture(bool active) => _captureController.add(active);
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

final class InMemorySecretStore implements SecretStore {
  final _map = <String, String>{};

  @override
  Future<String?> read(String key) async => _map[key];

  @override
  Future<void> write(String key, String value) async => _map[key] = value;

  @override
  Future<void> delete(String key) async => _map.remove(key);
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

  Future<List<Account>> all() async => List.unmodifiable(_accounts);

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

final class InMemoryAddressRepository implements AddressRepository {
  final _addresses = <WatchAddress>[];

  @override
  Stream<List<WatchAddress>> watchAll() =>
      Stream.value(List.unmodifiable(_addresses));

  @override
  Future<List<WatchAddress>> byAccount(String accountId) async =>
      _addresses.where((a) => a.accountId == accountId).toList();

  @override
  Future<WatchAddress?> find(
    ChainFamily family,
    String normalizedAddress,
  ) async {
    for (final a in _addresses) {
      if (a.family == family && a.address == normalizedAddress) return a;
    }
    return null;
  }

  @override
  Future<void> upsert(WatchAddress address) async {
    _addresses.removeWhere((a) => a.id == address.id);
    _addresses.add(address);
  }

  @override
  Future<void> delete(String id) async {
    _addresses.removeWhere((a) => a.id == id);
  }
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

const valid12Mnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
const validEvmPrivateKey =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

void main() {
  late VaultCrypto crypto;
  late InMemoryVaultStorage storage;
  late InMemorySecretStore secretStore;
  late InMemorySettingsRepository settingsRepo;
  late InMemoryVaultMetaRepository vaultMetaRepo;
  late InMemoryAccountRepository accountRepo;
  late InMemoryAddressRepository addressRepo;
  late FakeScreenGuard screenGuard;
  late FakePlatformCapabilities capabilities;
  late FakeClock clock;
  late Vault vault;
  late VaultAccess vaultAccess;
  late RevealVaultItem revealVaultItem;
  late DeleteVaultItem deleteVaultItem;

  const masterPassword = 'testMasterPassword123';
  const mnemonicItemId = 'item-mnemonic-1';
  const privateKeyItemId = 'item-pk-1';

  setUpAll(() async {
    crypto = SynchronousTestVaultCrypto(await SodiumVaultCrypto.load());
  });

  void initEnv() {
    storage = InMemoryVaultStorage();
    secretStore = InMemorySecretStore();
    settingsRepo = InMemorySettingsRepository();
    vaultMetaRepo = InMemoryVaultMetaRepository();
    accountRepo = InMemoryAccountRepository();
    addressRepo = InMemoryAddressRepository();
    screenGuard = FakeScreenGuard();
    capabilities = FakePlatformCapabilities();
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

    revealVaultItem = RevealVaultItem(vaultAccess: vaultAccess);
    deleteVaultItem = DeleteVaultItem(
      vaultAccess: vaultAccess,
      vaultMetaRepo: vaultMetaRepo,
      accountRepo: accountRepo,
      settings: settingsRepo,
      clock: clock,
    );
  }

  Future<void> initVaultWithItems() async {
    final sensitivePw = Sensitive(
      Uint8List.fromList(utf8.encode(masterPassword)),
    );
    final createRes = await vault.create(sensitivePw);
    final session = createRes.valueOrNull!;

    // 写入助记词条目
    final mRes = normalizeMnemonic(
      Sensitive(Uint8List.fromList(utf8.encode(valid12Mnemonic))),
    );
    final mSecret = MnemonicSecret(mnemonic: mRes.valueOrNull!);
    final mFp = session.fingerprintOf(mSecret);
    await session.addItem(mnemonicItemId, mSecret);
    mSecret.wipe();

    await vaultMetaRepo.upsert(
      VaultItemMeta(
        id: mnemonicItemId,
        name: '主钱包助记词',
        kind: VaultItemKind.mnemonic,
        hasPassphrase: false,
        wordCount: 12,
        fingerprint: mFp,
        createdAt: DateTime.utc(2026, 11, 10),
      ),
    );

    // 写入私钥条目
    final pkRes = Sensitive(
      Uint8List.fromList(utf8.encode(validEvmPrivateKey)),
    );
    final pkSecret = PrivateKeySecret(family: ChainFamily.evm, key: pkRes);
    final pkFp = session.fingerprintOf(pkSecret);
    await session.addItem(privateKeyItemId, pkSecret);
    pkSecret.wipe();

    await vaultMetaRepo.upsert(
      VaultItemMeta(
        id: privateKeyItemId,
        name: '单独以太坊私钥',
        kind: VaultItemKind.privateKey,
        hasPassphrase: false,
        family: ChainFamily.evm,
        fingerprint: pkFp,
        createdAt: DateTime.utc(2026, 11, 12),
      ),
    );

    session.close();
    sensitivePw.wipe();
  }

  Widget buildPage(String itemId) {
    return ProviderScope(
      overrides: [
        screenGuardProvider.overrideWithValue(screenGuard),
        platformCapabilitiesProvider.overrideWithValue(capabilities),
        settingsRepositoryProvider.overrideWithValue(settingsRepo),
        vaultMetaRepositoryProvider.overrideWithValue(vaultMetaRepo),
        accountRepositoryProvider.overrideWithValue(accountRepo),
        addressRepositoryProvider.overrideWithValue(addressRepo),
        revealVaultItemProvider.overrideWith((ref) => revealVaultItem),
        deleteVaultItemProvider.overrideWith((ref) => deleteVaultItem),
      ],
      child: MaterialApp(
        theme: buildOwTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: VaultItemDetailPage(itemId: itemId),
      ),
    );
  }

  testWidgets('初始状态：信息卡片完整、明文区域遮挡、防截屏启用', (tester) async {
    initEnv();
    await initVaultWithItems();
    await tester.pumpWidget(buildPage(mnemonicItemId));
    await tester.pumpAndSettle();

    expect(find.text('主钱包助记词'), findsOneWidget);
    expect(find.text('类型'), findsOneWidget);
    expect(find.text('助记词 · 12 词'), findsOneWidget);
    expect(find.text('创建于'), findsOneWidget);
    expect(find.text('2026-11-10'), findsOneWidget);
    expect(find.text('未关联'), findsOneWidget);

    // 遮挡块
    expect(find.byType(OwVeil), findsOneWidget);
    expect(find.text('验证后查看'), findsOneWidget);
    expect(find.byType(OwMnemonicGrid), findsNothing);

    // 防截屏启用
    expect(screenGuard.enabled, isTrue);
  });

  testWidgets('验证主密码后查看助记词：展示12词网格、开启60秒倒计时', (tester) async {
    initEnv();
    await initVaultWithItems();
    await tester.pumpWidget(buildPage(mnemonicItemId));
    await tester.pumpAndSettle();

    // 点击验证后查看
    await tester.tap(find.text('验证后查看'));
    await tester.pumpAndSettle();

    expect(find.text('输入主密码'), findsOneWidget);

    // 输入正确密码
    final dialogField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(dialogField, masterPassword);
    await tester.pumpAndSettle();

    await tester.tap(find.text('验证并保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 此时遮挡块消失，展示网格与倒计时
    expect(find.byType(OwVeil), findsNothing);
    expect(find.byType(OwMnemonicGrid), findsOneWidget);
    expect(find.text('60 秒后自动隐藏'), findsOneWidget);
    expect(find.text('隐藏'), findsOneWidget);
    expect(find.text('以二维码显示'), findsOneWidget);
    expect(find.text('about'), findsOneWidget);
  });

  testWidgets('手动点击隐藏：立即遮挡并清空明文', (tester) async {
    initEnv();
    await initVaultWithItems();
    await tester.pumpWidget(buildPage(mnemonicItemId));
    await tester.pumpAndSettle();

    await tester.tap(find.text('验证后查看'));
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

    expect(find.byType(OwMnemonicGrid), findsOneWidget);

    // 点击隐藏
    await tester.tap(find.text('隐藏'));
    await tester.pump();

    // 重新回到遮挡状态
    expect(find.byType(OwVeil), findsOneWidget);
    expect(find.byType(OwMnemonicGrid), findsNothing);
  });

  testWidgets('60秒倒计时结束自动遮挡并清空明文', (tester) async {
    initEnv();
    await initVaultWithItems();
    await tester.pumpWidget(buildPage(mnemonicItemId));
    await tester.pumpAndSettle();

    await tester.tap(find.text('验证后查看'));
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

    expect(find.byType(OwMnemonicGrid), findsOneWidget);

    // 模拟时间流逝 60 秒
    await tester.pump(const Duration(seconds: 60));

    // 倒计时归零，自动遮挡
    expect(find.byType(OwVeil), findsOneWidget);
    expect(find.byType(OwMnemonicGrid), findsNothing);
  });

  testWidgets('二维码切换：在文字与二维码之间自由切换', (tester) async {
    initEnv();
    await initVaultWithItems();
    await tester.pumpWidget(buildPage(mnemonicItemId));
    await tester.pumpAndSettle();

    await tester.tap(find.text('验证后查看'));
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

    // 切换到二维码
    await tester.tap(find.text('以二维码显示'));
    await tester.pump();

    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('以文字显示'), findsOneWidget);

    // 切换回文字
    await tester.tap(find.text('以文字显示'));
    await tester.pump();

    expect(find.byType(QrImageView), findsNothing);
    expect(find.byType(OwMnemonicGrid), findsOneWidget);
  });

  testWidgets('检测到录屏时立即隐藏明文并展示警示条 (R26)', (tester) async {
    initEnv();
    await initVaultWithItems();
    await tester.pumpWidget(buildPage(mnemonicItemId));
    await tester.pumpAndSettle();

    await tester.tap(find.text('验证后查看'));
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

    expect(find.byType(OwMnemonicGrid), findsOneWidget);

    // 发出录屏激活事件
    screenGuard.emitCapture(true);
    await tester.pump();

    // 明文被隐藏并出现警示条
    expect(find.byType(OwMnemonicGrid), findsNothing);
    expect(find.text('检测到录屏，已隐藏敏感内容'), findsOneWidget);
  });

  testWidgets('切入后台时清空明文并遮挡 (R25)', (tester) async {
    initEnv();
    await initVaultWithItems();
    await tester.pumpWidget(buildPage(mnemonicItemId));
    await tester.pumpAndSettle();

    await tester.tap(find.text('验证后查看'));
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

    expect(find.byType(OwMnemonicGrid), findsOneWidget);

    // 模拟应用切入后台
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    // 明文已清空
    expect(find.byType(OwVeil), findsOneWidget);
    expect(find.byType(OwMnemonicGrid), findsNothing);
  });

  testWidgets('删除密钥：需勾选二次确认与输入主密码，删除后条目被移除 (R32)', (tester) async {
    initEnv();
    await initVaultWithItems();
    await tester.pumpWidget(buildPage(mnemonicItemId));
    await tester.pumpAndSettle();

    final deleteBtn = find.text('删除此密钥');
    await tester.ensureVisible(deleteBtn);
    await tester.pumpAndSettle();
    await tester.tap(deleteBtn);
    await tester.pumpAndSettle();

    // 弹出删除确认框
    expect(find.text('我明白此操作无法撤销，且我已另有备份。'), findsOneWidget);

    // 未勾选或未填密码前删除按钮不可用
    final confirmBtn = find.widgetWithText(FilledButton, '删除');
    expect(tester.widget<FilledButton>(confirmBtn).onPressed, isNull);

    // 勾选复选框
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();

    // 输入主密码
    final pwField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(pwField, masterPassword);
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(confirmBtn).onPressed, isNotNull);

    // 点击删除
    await tester.tap(confirmBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 元数据仓储中该条目已被删除
    final items = await vaultMetaRepo.all();
    expect(items.any((it) => it.id == mnemonicItemId), isFalse);
  });
}
