import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

import '../fakes/fake_repositories.dart';

void main() {
  late InMemoryAccountRepository accounts;
  late RenameAccount renameAccount;

  final now = DateTime.utc(2026, 11, 15);
  final initialAccount = Account.wallet(
    id: 'acc1',
    name: '旧名称',
    colorIndex: 0,
    createdAt: now,
  );

  setUp(() async {
    accounts = InMemoryAccountRepository();
    await accounts.upsert(initialAccount);
    renameAccount = RenameAccount(accounts: accounts);
  });

  group('RenameAccount', () {
    test('正常重命名_成功更新并返回新账户', () async {
      final res = await renameAccount(accountId: 'acc1', newName: '新名称');

      expect(res.isOk, isTrue);
      final updated = res.when(ok: (a) => a, err: (_) => null)!;
      expect(updated.id, 'acc1');
      expect(updated.name, '新名称');

      final fromRepo = await accounts.byId('acc1');
      expect(fromRepo?.name, '新名称');
    });

    test('名称首尾空白_自动截断后保存', () async {
      final res = await renameAccount(accountId: 'acc1', newName: '   新名称   ');

      expect(res.isOk, isTrue);
      final updated = res.when(ok: (a) => a, err: (_) => null)!;
      expect(updated.name, '新名称');

      final fromRepo = await accounts.byId('acc1');
      expect(fromRepo?.name, '新名称');
    });

    test('30个字符边界_成功保存', () async {
      final name30 = '一' * 30;
      final res = await renameAccount(accountId: 'acc1', newName: name30);

      expect(res.isOk, isTrue);
      final updated = res.when(ok: (a) => a, err: (_) => null)!;
      expect(updated.name, name30);
    });

    test('账户不存在_返回校验失败', () async {
      final res = await renameAccount(
        accountId: 'non_existent',
        newName: '新名称',
      );

      expect(res.isOk, isFalse);
      final failure = res.when(ok: (_) => null, err: (f) => f);
      expect(failure, isA<ValidationFailure>());
      expect((failure as ValidationFailure).detail, '账户不存在');
    });

    test('名称为空_返回校验失败且不改动原账户', () async {
      final res = await renameAccount(accountId: 'acc1', newName: '   ');

      expect(res.isOk, isFalse);
      final failure = res.when(ok: (_) => null, err: (f) => f);
      expect(failure, isA<ValidationFailure>());
      expect((failure as ValidationFailure).detail, '名称须为 1–30 字');

      final fromRepo = await accounts.byId('acc1');
      expect(fromRepo?.name, '旧名称');
    });

    test('名称超过30字_返回校验失败且不改动原账户', () async {
      final res = await renameAccount(accountId: 'acc1', newName: '一' * 31);

      expect(res.isOk, isFalse);
      final failure = res.when(ok: (_) => null, err: (f) => f);
      expect(failure, isA<ValidationFailure>());
      expect((failure as ValidationFailure).detail, '名称须为 1–30 字');

      final fromRepo = await accounts.byId('acc1');
      expect(fromRepo?.name, '旧名称');
    });
  });
}
