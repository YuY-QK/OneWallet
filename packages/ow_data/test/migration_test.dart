import 'package:drift/native.dart';
import 'package:ow_data/ow_data.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

import 'support.dart';

/// 迁移测试：全新建库，以及从上一版本的库升级后表结构与数据保持完整。
/// 以后每次改表：提升 `currentSchemaVersion`、写迁移，并在这里加对应用例。
void main() {
  test('schemaVersion 为 3', () {
    final db = newDb();
    addTearDown(db.close);
    expect(db.schemaVersion, 3);
    expect(OwDatabase.currentSchemaVersion, 3);
  });

  test('全新建库成功：12 张表齐全、外键已开启、user_version 为 3', () async {
    final db = newDb();
    addTearDown(db.close);
    final tables = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%'",
        )
        .get();
    expect(tables.map((r) => r.read<String>('name')).toSet(), {
      'accounts',
      'addresses',
      'holdings',
      'prices',
      'snapshots',
      'snapshot_items',
      'vault_items_meta',
      'sync_records',
      'settings',
      'token_visibility',
      'assets',
      'asset_contracts',
    });
    final fk = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(fk.read<int>('foreign_keys'), 1);
    final v = await db.customSelect('PRAGMA user_version').getSingle();
    expect(v.read<int>('user_version'), 3);
    final idx = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND name = 'idx_addresses_family_address'",
        )
        .get();
    expect(idx, hasLength(1));
  });

  test('从版本 1 升级：旧账户、地址仍在，新增两张表与 last_synced_at 列', () async {
    // 手写的版本 1 表结构（只含本测试涉及的两张表）与数据。
    final db = OwDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute('''
CREATE TABLE accounts (
  id TEXT NOT NULL PRIMARY KEY, type TEXT NOT NULL, name TEXT NOT NULL,
  color_index INTEGER NOT NULL, note TEXT NOT NULL DEFAULT '',
  wallet_source TEXT NULL, exchange TEXT NULL, vault_item_id TEXT NULL,
  offline_backed_up INTEGER NOT NULL DEFAULT 0 CHECK (offline_backed_up IN (0, 1)),
  offline_verified_at TEXT NULL,
  keyless INTEGER NOT NULL DEFAULT 0 CHECK (keyless IN (0, 1)),
  created_at TEXT NOT NULL)''');
          raw.execute(
            '''
CREATE TABLE addresses (
  id TEXT NOT NULL PRIMARY KEY,
  account_id TEXT NOT NULL REFERENCES accounts (id) ON DELETE CASCADE,
  family TEXT NOT NULL, address TEXT NOT NULL, enabled_chain_ids TEXT NOT NULL,
  scheme TEXT NULL, derivation_index INTEGER NULL, note TEXT NOT NULL DEFAULT '')''',
          );
          raw.execute(
            "INSERT INTO accounts (id, type, name, color_index, created_at) "
            "VALUES ('a1', 'wallet', '旧账户', 3, '2026-11-01T00:00:00.000Z')",
          );
          raw.execute(
            "INSERT INTO addresses (id, account_id, family, address, enabled_chain_ids) "
            "VALUES ('ad1', 'a1', 'evm', '0xabc', '[\"ethereum\"]')",
          );
          raw.execute('PRAGMA user_version = 1');
        },
      ),
    );
    addTearDown(db.close);
    final repos = OwRepositories(db);

    final account = await repos.accounts.byId('a1');
    expect(account?.name, '旧账户');
    expect(account?.colorIndex, 3);
    expect(await repos.addresses.byAccount('a1'), hasLength(1));
    expect(await repos.syncRecords.watchLastSuccessPerAccount().first, isEmpty);
    // 新表可用。
    await repos.assets.upsertAll([
      const Asset(id: 'FOO', symbol: 'FOO', name: 'Foo', priceId: 'foo'),
    ], now: DateTime.utc(2026, 11, 12));
    expect(await repos.assets.all(), hasLength(1));
    final v = await db.customSelect('PRAGMA user_version').getSingle();
    expect(v.read<int>('user_version'), 3);
  });

  test(
    '从版本 2 升级：accounts 新增 wallet_source_id 列，旧 wallet_source 按对应表填充',
    () async {
      final db = OwDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute('''
CREATE TABLE accounts (
  id TEXT NOT NULL PRIMARY KEY, type TEXT NOT NULL, name TEXT NOT NULL,
  color_index INTEGER NOT NULL, note TEXT NOT NULL DEFAULT '',
  wallet_source TEXT NULL, exchange TEXT NULL, vault_item_id TEXT NULL,
  offline_backed_up INTEGER NOT NULL DEFAULT 0 CHECK (offline_backed_up IN (0, 1)),
  offline_verified_at TEXT NULL,
  keyless INTEGER NOT NULL DEFAULT 0 CHECK (keyless IN (0, 1)),
  created_at TEXT NOT NULL,
  last_synced_at TEXT NULL)''');
            raw.execute(
              '''
CREATE TABLE addresses (
  id TEXT NOT NULL PRIMARY KEY,
  account_id TEXT NOT NULL REFERENCES accounts (id) ON DELETE CASCADE,
  family TEXT NOT NULL, address TEXT NOT NULL, enabled_chain_ids TEXT NOT NULL,
  scheme TEXT NULL, derivation_index INTEGER NULL, note TEXT NOT NULL DEFAULT '')''',
            );
            raw.execute('''
CREATE TABLE assets (
  id TEXT NOT NULL PRIMARY KEY, symbol TEXT NOT NULL, name TEXT NOT NULL,
  price_id TEXT NOT NULL, icon_url TEXT NULL)''');
            raw.execute('''
CREATE TABLE asset_contracts (
  chain_id TEXT NOT NULL, address TEXT NOT NULL, asset_id TEXT NOT NULL,
  decimals INTEGER NOT NULL, PRIMARY KEY (chain_id, address))''');

            // 插入五种映射钱包、其他钱包、空钱包、交易所
            raw.execute(
              "INSERT INTO accounts (id, type, name, color_index, wallet_source, created_at) VALUES "
              "('w-uni', 'wallet', 'Uni', 0, 'uniswap', '2026-11-01T00:00:00.000Z'), "
              "('w-meta', 'wallet', 'MetaMask', 1, 'metamask', '2026-11-01T00:00:00.000Z'), "
              "('w-okx', 'wallet', 'OKX', 2, 'okxWeb3', '2026-11-01T00:00:00.000Z'), "
              "('w-bitget', 'wallet', 'Bitget', 3, 'bitgetWallet', '2026-11-01T00:00:00.000Z'), "
              "('w-trust', 'wallet', 'Trust', 4, 'trustWallet', '2026-11-01T00:00:00.000Z'), "
              "('w-other', 'wallet', 'Other', 5, 'other', '2026-11-01T00:00:00.000Z'), "
              "('w-null', 'wallet', 'None', 6, NULL, '2026-11-01T00:00:00.000Z'), "
              "('ex-1', 'exchange', '币安', 7, NULL, '2026-11-01T00:00:00.000Z')",
            );
            raw.execute('PRAGMA user_version = 2');
          },
        ),
      );
      addTearDown(db.close);
      final repos = OwRepositories(db);

      // 检查版本升级为 3
      final v = await db.customSelect('PRAGMA user_version').getSingle();
      expect(v.read<int>('user_version'), 3);

      // 验证仓储读出时两个字段均正确
      final uni = await repos.accounts.byId('w-uni');
      expect(uni?.walletSourceId, 'uniswap-wallet');
      expect(uni?.walletSource, WalletSource.uniswap);

      final meta = await repos.accounts.byId('w-meta');
      expect(meta?.walletSourceId, 'metamask');
      expect(meta?.walletSource, WalletSource.metamask);

      final okx = await repos.accounts.byId('w-okx');
      expect(okx?.walletSourceId, 'okx-web3-wallet');
      expect(okx?.walletSource, WalletSource.okxWeb3);

      final bitget = await repos.accounts.byId('w-bitget');
      expect(bitget?.walletSourceId, 'bitget-wallet');
      expect(bitget?.walletSource, WalletSource.bitgetWallet);

      final trust = await repos.accounts.byId('w-trust');
      expect(trust?.walletSourceId, 'trust-wallet');
      expect(trust?.walletSource, WalletSource.trustWallet);

      final other = await repos.accounts.byId('w-other');
      expect(other?.walletSourceId, isNull);
      expect(other?.walletSource, WalletSource.other);

      final none = await repos.accounts.byId('w-null');
      expect(none?.walletSourceId, isNull);
      expect(none?.walletSource, WalletSource.other);

      final ex = await repos.accounts.byId('ex-1');
      expect(ex?.walletSourceId, isNull);
      expect(ex?.walletSource, isNull);
    },
  );
}
