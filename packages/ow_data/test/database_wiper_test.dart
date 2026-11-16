import 'package:ow_data/ow_data.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('OwDatabase.wipe', () {
    late OwDatabase db;
    late OwRepositories repos;

    setUp(() {
      db = newDb();
      repos = OwRepositories(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('wipe清空全部数据表', () async {
      final acc = makeAccount('a1');
      await repos.accounts.upsert(acc);
      await repos.addresses.upsert(makeAddress('addr1', 'a1'));
      await repos.holdings.replaceForAccount('a1', [makeHolding('a1')]);
      await repos.settings.update((s) => s.copyWith(quote: Quote.cny));
      await repos.tokenVisibility.setHidden('ethereum:native', true);

      expect(await repos.accounts.watchAll().first, isNotEmpty);
      expect(await repos.addresses.watchAll().first, isNotEmpty);
      expect(await repos.holdings.watchAll().first, isNotEmpty);
      expect(await repos.tokenVisibility.hidden(), isNotEmpty);

      await db.wipe();

      expect(await repos.accounts.watchAll().first, isEmpty);
      expect(await repos.addresses.watchAll().first, isEmpty);
      expect(await repos.holdings.watchAll().first, isEmpty);
      expect(await repos.tokenVisibility.hidden(), isEmpty);
      expect(await repos.settings.watch().first, const AppSettings());
    });
  });
}
