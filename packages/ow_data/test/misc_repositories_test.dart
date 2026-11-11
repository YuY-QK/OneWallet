import 'package:ow_data/ow_data.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  late OwDatabase db;
  late OwRepositories repos;

  setUp(() async {
    db = newDb();
    repos = OwRepositories(db);
    await repos.accounts.upsert(makeAccount('a1'));
    await repos.accounts.upsert(makeAccount('a2'));
  });
  tearDown(() => db.close());

  group('SyncRecordRepository', () {
    SyncRecord rec(String acc, int i, SyncStatus s, {String? failure}) =>
        SyncRecord(
          accountId: acc,
          startedAt: t0.add(Duration(minutes: i)),
          finishedAt: s == SyncStatus.running
              ? null
              : t0.add(Duration(minutes: i, seconds: 5)),
          status: s,
          failureType: failure,
        );

    test('每个账户取最近一条', () async {
      await repos.syncRecords.add(rec('a1', 1, SyncStatus.running));
      await repos.syncRecords.add(rec('a2', 2, SyncStatus.success));
      await repos.syncRecords.add(
        rec('a1', 3, SyncStatus.failed, failure: 'NetworkFailure'),
      );
      final latest = await repos.syncRecords.watchLatestPerAccount().first;
      expect(latest, [
        rec('a1', 3, SyncStatus.failed, failure: 'NetworkFailure'),
        rec('a2', 2, SyncStatus.success),
      ]);
    });

    test('超过 50 条时只保留最近 50 条', () async {
      for (var i = 0; i < 60; i++) {
        await repos.syncRecords.add(rec('a1', i, SyncStatus.success));
      }
      final rows = await db.select(db.syncRecords).get();
      expect(rows, hasLength(50));
      expect(
        rows
            .map((r) => r.startedAt.toUtc())
            .reduce((a, b) => a.isBefore(b) ? a : b),
        t0.add(const Duration(minutes: 10)),
      );
      expect(
        (await repos.syncRecords.watchLatestPerAccount().first)
            .single
            .startedAt,
        t0.add(const Duration(minutes: 59)),
      );
    });

    test('watch 随写入发出新值', () async {
      final expectation = expectLater(
        repos.syncRecords.watchLatestPerAccount(),
        emitsInOrder([isEmpty, hasLength(1)]),
      );
      await Future<void>.delayed(Duration.zero);
      await repos.syncRecords.add(rec('a1', 1, SyncStatus.success));
      await expectation;
    });
  });

  group('VaultMetaRepository', () {
    final m = VaultItemMeta(
      id: 'v1',
      name: '主助记词',
      kind: VaultItemKind.mnemonic,
      wordCount: 12,
      hasPassphrase: true,
      fingerprint: 'ab12cd34',
      createdAt: t0,
    );

    test('读写、按指纹查找、删除、watch', () async {
      final expectation = expectLater(
        repos.vaultMeta.watchAll(),
        emitsInOrder([
          isEmpty,
          [m],
          isEmpty,
        ]),
      );
      await Future<void>.delayed(Duration.zero);
      await repos.vaultMeta.upsert(m);
      expect(await repos.vaultMeta.byFingerprint('ab12cd34'), m);
      expect(await repos.vaultMeta.byFingerprint('zz'), isNull);
      await repos.vaultMeta.delete('v1');
      await expectation;
    });

    test('私钥条目带链家族往返；同 id 更新名称', () async {
      final k = VaultItemMeta(
        id: 'v2',
        name: 'SOL 私钥',
        kind: VaultItemKind.privateKey,
        family: ChainFamily.solana,
        hasPassphrase: false,
        fingerprint: 'ff00',
        createdAt: t0,
      );
      await repos.vaultMeta.upsert(k);
      await repos.vaultMeta.upsert(k.copyWith(name: '改名'));
      final all = await repos.vaultMeta.watchAll().first;
      expect(all.single, k.copyWith(name: '改名'));
    });

    test('指纹重复（不同 id）时失败，且不破坏原条目', () async {
      await repos.vaultMeta.upsert(m);
      await expectLater(
        repos.vaultMeta.upsert(
          VaultItemMeta(
            id: 'other',
            name: 'x',
            kind: VaultItemKind.mnemonic,
            hasPassphrase: false,
            fingerprint: 'ab12cd34',
            createdAt: t0,
          ),
        ),
        throwsA(isA<Object>()),
      );
      expect((await repos.vaultMeta.byFingerprint('ab12cd34'))!.id, 'v1');
    });
  });

  group('SettingsRepository', () {
    test('首次读取返回默认值', () async {
      expect(await repos.settings.watch().first, const AppSettings());
    });

    test('update 持久化并发出新值；设回 null 删除该项', () async {
      final expectation = expectLater(
        repos.settings.watch(),
        emitsInOrder([
          const AppSettings(),
          predicate<AppSettings>(
            (s) =>
                s.quote == Quote.cny &&
                !s.hideSmall &&
                s.theme == ThemePreference.dark &&
                s.autoLock == AutoLock.after5Min &&
                s.vaultChangedAt == t0,
          ),
          const AppSettings(quote: Quote.cny),
        ]),
      );
      await Future<void>.delayed(Duration.zero);
      await repos.settings.update(
        (s) => s.copyWith(
          quote: Quote.cny,
          hideSmall: false,
          theme: ThemePreference.dark,
          autoLock: AutoLock.after5Min,
          vaultChangedAt: t0,
        ),
      );
      await repos.settings.update((s) => const AppSettings(quote: Quote.cny));
      await expectation;
    });

    test('无法识别的值回落到默认值，不影响其他项', () async {
      await repos.settings.update(
        (s) => s.copyWith(hideAmounts: true, quote: Quote.cny),
      );
      await db.customStatement(
        "UPDATE settings SET value = 'weird' WHERE key = 'quote'",
      );
      final s = await repos.settings.watch().first;
      expect(s.quote, Quote.usd);
      expect(s.hideAmounts, isTrue);
    });
  });

  group('TokenVisibilityRepository', () {
    test('隐藏、取消隐藏', () async {
      expect(await repos.tokenVisibility.hidden(), isEmpty);
      await repos.tokenVisibility.setHidden('ethereum:0xscam', true);
      await repos.tokenVisibility.setHidden('bsc:0xother', true);
      expect(await repos.tokenVisibility.hidden(), {
        'ethereum:0xscam',
        'bsc:0xother',
      });
      await repos.tokenVisibility.setHidden('ethereum:0xscam', false);
      expect(await repos.tokenVisibility.hidden(), {'bsc:0xother'});
    });
  });
}
