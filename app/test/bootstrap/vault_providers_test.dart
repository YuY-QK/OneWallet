import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/bootstrap/providers.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_data/ow_data.dart';
import 'package:ow_domain/ow_domain.dart';

import 'support.dart';

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

final class _FakeHardwareKeyStore implements HardwareKeyStore {
  final _data = <String, Uint8List>{};

  @override
  Future<Result<Uint8List>> wrap(String keyAlias, Uint8List plaintext) async {
    _data[keyAlias] = Uint8List.fromList(plaintext);
    return Ok(Uint8List.fromList([1, 2, 3, ...plaintext]));
  }

  @override
  Future<Result<Uint8List>> unwrap(
    String keyAlias,
    Uint8List wrapped, {
    required String reason,
  }) async {
    final pt = _data[keyAlias];
    if (pt == null) return const Err(ValidationFailure('not_found'));
    return Ok(Uint8List.fromList(pt));
  }

  @override
  Future<void> delete(String keyAlias) async {
    _data.remove(keyAlias);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OwDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = OwDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secretStoreProvider.overrideWithValue(FakeSecretStore()),
        vaultStorageProvider.overrideWithValue(_MemoryVaultStorage()),
        hardwareKeyStoreProvider.overrideWithValue(_FakeHardwareKeyStore()),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('T18: 全部新 provider 都能构造出来且不抛异常', () async {
    final syncProviders = <ProviderListenable<Object?>>[
      appVersionProvider,
      vaultStorageProvider,
      hardwareKeyStoreProvider,
      vaultPasswordLimiterProvider,
      credentialRepositoryProvider,
      attachDerivedAddressesProvider,
      confirmBackupSavedProvider,
      watchVaultItemsProvider,
    ];
    for (final p in syncProviders) {
      expect(() => container.read(p), returnsNormally, reason: '$p');
    }

    final asyncProviders = <ProviderListenable<Future<Object?>>>[
      vaultCryptoProvider.future,
      vaultProvider.future,
      vaultAccessProvider.future,
      createVaultProvider.future,
      importVaultItemProvider.future,
      revealVaultItemProvider.future,
      deleteVaultItemProvider.future,
      deriveAddressesProvider.future,
      changeMasterPasswordProvider.future,
      setVaultBiometricsProvider.future,
      exportBackupProvider.future,
      openBackupProvider.future,
      restoreBackupProvider.future,
    ];
    for (final p in asyncProviders) {
      final val = await container.read(p);
      expect(val, isNotNull, reason: '$p');
    }
  });

  test('T18: vaultItemsProvider 能发出条目列表', () async {
    final values = <List<VaultItemSummary>>[];
    final sub = container.listen(vaultItemsProvider, (_, next) {
      next.whenData(values.add);
    });
    addTearDown(sub.close);

    // 等待初始空列表
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(values.isNotEmpty, isTrue);
    expect(values.last, isEmpty);

    // 向元数据仓储插入一条
    final metaRepo = container.read(vaultMetaRepositoryProvider);
    await metaRepo.upsert(
      VaultItemMeta(
        id: 'test-item-1',
        name: 'Test Item',
        kind: VaultItemKind.mnemonic,
        fingerprint: 'fp-1',
        hasPassphrase: false,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );

    // 等待 stream 推送更新
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(values.last.length, 1);
    expect(values.last.first.meta.id, 'test-item-1');
    expect(values.last.first.meta.name, 'Test Item');
  });
}
