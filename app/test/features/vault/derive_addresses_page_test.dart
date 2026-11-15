import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/bootstrap/adapter_providers.dart';
import 'package:onewallet/bootstrap/foundation_providers.dart';
import 'package:onewallet/bootstrap/vault_providers.dart';
import 'package:onewallet/features/vault/presentation/derive_addresses_page.dart';
import 'package:onewallet/l10n/app_localizations.dart';
import 'package:onewallet/theme/ow_theme.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:ow_vault/ow_vault.dart';

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

final class SequentialIds implements IdGenerator {
  int _counter = 0;
  @override
  String newId() => 'id_${++_counter}';
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
  Future<void> upsert(VaultItemMeta item) async {
    _items.removeWhere((it) => it.id == item.id);
    _items.add(item);
  }

  @override
  Future<void> delete(String id) async {
    _items.removeWhere((it) => it.id == id);
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
    _accounts.removeWhere((a) => a.id == account.id);
    _accounts.add(account);
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
  Future<WatchAddress?> find(ChainFamily family, String address) async {
    for (final a in _addresses) {
      if (a.family == family &&
          a.address.toLowerCase() == address.toLowerCase()) {
        return a;
      }
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

final class RecordingChainAdapter implements ChainAdapter {
  @override
  ChainFamily get family => ChainFamily.evm;

  final List<(String, ChainInfo)> recordedCalls = [];
  bool activityToReturn = true;

  @override
  Future<Result<bool>> hasActivity(String address, ChainInfo chain) async {
    recordedCalls.add((address, chain));
    return Ok(activityToReturn);
  }

  @override
  Future<Result<List<RawHolding>>> fetchHoldings(
    String address,
    ChainInfo chain,
  ) async {
    return const Ok([]);
  }
}

final class FakeAdapterRegistry implements AdapterRegistry {
  FakeAdapterRegistry(this.recordingAdapter);

  final RecordingChainAdapter recordingAdapter;

  @override
  ChainAdapter chain(ChainFamily family) => recordingAdapter;

  @override
  ExchangeAdapter exchange(ExchangeId id) => throw UnimplementedError();
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VaultCrypto crypto;
  late InMemoryVaultStorage storage;
  late InMemorySecretStore secretStore;
  late InMemorySettingsRepository settingsRepo;
  late InMemoryVaultMetaRepository vaultMetaRepo;
  late InMemoryAccountRepository accountRepo;
  late InMemoryAddressRepository addressRepo;
  late FakePlatformCapabilities capabilities;
  late FakeClock clock;
  late SequentialIds ids;
  late RecordingChainAdapter recordingAdapter;
  late FakeAdapterRegistry adapterRegistry;
  late Vault vault;
  late VaultAccess vaultAccess;
  late DeriveAddresses deriveAddresses;
  late AttachDerivedAddresses attachDerivedAddresses;

  const masterPassword = 'testMasterPassword123';
  const mnemonicItemId = 'item-mnemonic-1';
  const valid12Mnemonic =
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

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
    capabilities = FakePlatformCapabilities();
    clock = FakeClock();
    ids = SequentialIds();
    recordingAdapter = RecordingChainAdapter();
    adapterRegistry = FakeAdapterRegistry(recordingAdapter);

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

    deriveAddresses = DeriveAddresses(
      vaultAccess: vaultAccess,
      addressRepo: addressRepo,
      mnemonicRunner: DeriveAddresses.runMnemonicSync,
      privateKeyRunner: DeriveAddresses.runPrivateKeySync,
    );

    attachDerivedAddresses = AttachDerivedAddresses(
      vaultMetaRepo: vaultMetaRepo,
      accountRepo: accountRepo,
      addressRepo: addressRepo,
      ids: ids,
      clock: clock,
    );
  }

  Future<void> initVaultWithItems() async {
    final sensitivePw = Sensitive(
      Uint8List.fromList(utf8.encode(masterPassword)),
    );
    final createRes = await vault.create(sensitivePw);
    final session = createRes.valueOrNull!;

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

    // 预置已观察地址（#0 地址）
    await addressRepo.upsert(
      WatchAddress(
        id: 'addr-0',
        accountId: 'acc-existing',
        family: ChainFamily.evm,
        address: '0x9858EfFD232B4033E47d90003D41EC34EcaEda94',
        enabledChainIds: const {'ethereum'},
      ),
    );
  }

  Widget buildPage(String itemId) {
    return ProviderScope(
      overrides: [
        vaultMetaRepositoryProvider.overrideWithValue(vaultMetaRepo),
        accountRepositoryProvider.overrideWithValue(accountRepo),
        addressRepositoryProvider.overrideWithValue(addressRepo),
        adapterRegistryProvider.overrideWithValue(adapterRegistry),
        deriveAddressesProvider.overrideWith(
          (ref) => Future.value(deriveAddresses),
        ),
        attachDerivedAddressesProvider.overrideWithValue(
          attachDerivedAddresses,
        ),
      ],
      child: MaterialApp(
        theme: buildOwTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DeriveAddressesPage(itemId: itemId),
      ),
    );
  }

  testWidgets('初始状态：显示说明条、链分段、路径下拉、验证派生提示', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    initEnv();
    await initVaultWithItems();
    await tester.pumpWidget(buildPage(mnemonicItemId));
    await tester.pumpAndSettle();

    // 1. 说明条
    expect(find.text('以下地址由你的密钥计算得出，仅地址会被用于查询余额，密钥不会离开保险库。'), findsOneWidget);

    // 2. 链分段（EVM, BITCOIN, SOLANA, TRON）
    expect(find.text('EVM'), findsOneWidget);
    expect(find.text('BITCOIN'), findsOneWidget);
    expect(find.text('SOLANA'), findsOneWidget);
    expect(find.text('TRON'), findsOneWidget);

    // 3. 路径选择下拉
    expect(find.text('派生路径'), findsOneWidget);

    // 4. 派生启动提示与按钮
    expect(find.text('请输入主密码以计算派生地址'), findsOneWidget);
    expect(find.text('开始派生'), findsOneWidget);

    // 5. 目标账户
    expect(find.text('新建钱包账户'), findsOneWidget);

    // 6. 加入观察初始禁用
    final attachBtn = find.widgetWithText(FilledButton, '加入观察');
    expect(tester.widget<FilledButton>(attachBtn).onPressed, isNull);
  });

  testWidgets('输入密码派生地址：展示前5个地址，已在观察项标记', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    initEnv();
    await initVaultWithItems();
    await tester.pumpWidget(buildPage(mnemonicItemId));
    await tester.pumpAndSettle();

    // 点击开始派生
    await tester.tap(find.text('开始派生'));
    await tester.pumpAndSettle();

    // 弹出密码输入框
    expect(find.text('验证主密码'), findsOneWidget);
    final pwField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(pwField, masterPassword);
    await tester.pumpAndSettle();

    final confirmBtn = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, '开始派生'),
    );
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    // 派生成功：展示5个地址（#0 到 #4）
    expect(find.text('#0'), findsOneWidget);
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('#4'), findsOneWidget);

    // #0 标记为已在观察
    expect(find.text('已在观察'), findsOneWidget);

    // 加入观察按钮变为可用
    final attachBtn = find.widgetWithText(FilledButton, '加入观察');
    expect(tester.widget<FilledButton>(attachBtn).onPressed, isNotNull);
  });

  testWidgets('显示更多：展示5到9号地址', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    initEnv();
    await initVaultWithItems();
    await tester.pumpWidget(buildPage(mnemonicItemId));
    await tester.pumpAndSettle();

    await tester.tap(find.text('开始派生'));
    await tester.pumpAndSettle();
    final pwField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(pwField, masterPassword);
    await tester.pumpAndSettle();

    final confirmBtn = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, '开始派生'),
    );
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    // 点击显示更多
    final showMoreBtn = find.text('显示更多');
    await tester.ensureVisible(showMoreBtn);
    await tester.tap(showMoreBtn);
    await tester.pumpAndSettle();

    // 出现 #5, #9
    expect(find.text('#5'), findsOneWidget);
    expect(find.text('#9'), findsOneWidget);
  });

  testWidgets('检测余额：抓包断言只向链适配器发送地址，不包含密钥或助记词', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    initEnv();
    await initVaultWithItems();
    await tester.pumpWidget(buildPage(mnemonicItemId));
    await tester.pumpAndSettle();

    await tester.tap(find.text('开始派生'));
    await tester.pumpAndSettle();
    final pwField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(pwField, masterPassword);
    await tester.pumpAndSettle();

    final confirmBtn = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, '开始派生'),
    );
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    // 点击检测余额
    final checkBalanceBtn = find.text('检测余额');
    await tester.ensureVisible(checkBalanceBtn);
    await tester.tap(checkBalanceBtn);
    await tester.pumpAndSettle();

    // 核心安全红线断言：
    // 1. 确实调用了适配器 hasActivity
    expect(recordingAdapter.recordedCalls.length, 5);
    // 2. 发出的全部都是规范化地址，只包含十六进制地址字符串
    for (final (addr, chain) in recordingAdapter.recordedCalls) {
      expect(addr.startsWith('0x'), isTrue);
      expect(chain.id, 'ethereum');
      // 绝不含有任何密码、助记词、私钥字符串
      expect(addr.contains(masterPassword), isFalse);
      expect(addr.contains('abandon'), isFalse);
      expect(addr.contains('secret'), isFalse);
    }

    // UI 上展示已在观察与有活动标签
    expect(find.text('已在观察'), findsOneWidget);
    expect(find.text('有活动'), findsNWidgets(4));
  });

  testWidgets('加入观察：成功将选中地址加入新账户并更新状态', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    initEnv();
    await initVaultWithItems();
    await tester.pumpWidget(buildPage(mnemonicItemId));
    await tester.pumpAndSettle();

    await tester.tap(find.text('开始派生'));
    await tester.pumpAndSettle();
    final pwField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(pwField, masterPassword);
    await tester.pumpAndSettle();

    final confirmBtn = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, '开始派生'),
    );
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    // 点击加入观察
    final attachBtn = find.widgetWithText(FilledButton, '加入观察');
    await tester.ensureVisible(attachBtn);
    await tester.tap(attachBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 账户仓储中成功添加了该账户
    final accounts = await accountRepo.watchAll().first;
    expect(accounts.any((a) => a.name == '主钱包助记词'), isTrue);
  });
}
