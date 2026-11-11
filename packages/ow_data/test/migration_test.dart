import 'package:ow_data/ow_data.dart';
import 'package:test/test.dart';

import 'support.dart';

/// 迁移测试骨架：目前只有 schemaVersion 1，验证全新建库成功。
/// 以后每次改表：提升 `currentSchemaVersion`、写迁移，并在这里加
/// "从上一版本的库升级后表结构与数据保持完整"的用例。
void main() {
  test('schemaVersion 为 1', () {
    final db = newDb();
    addTearDown(db.close);
    expect(db.schemaVersion, 1);
    expect(OwDatabase.currentSchemaVersion, 1);
  });

  test('全新建库成功：10 张表齐全、外键已开启、user_version 为 1', () async {
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
    });
    final fk = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(fk.read<int>('foreign_keys'), 1);
    final v = await db.customSelect('PRAGMA user_version').getSingle();
    expect(v.read<int>('user_version'), 1);
    final idx = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND name = 'idx_addresses_family_address'",
        )
        .get();
    expect(idx, hasLength(1));
  });
}
