import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

import '../fakes/fake_repositories.dart';

void main() {
  late InMemoryAddressRepository addresses;
  late UpdateAddressNote updateAddressNote;

  final evmAddress = WatchAddress(
    id: 'ad1',
    accountId: 'w1',
    family: ChainFamily.evm,
    address: '0x12ab34cd56ef7890ab12cd34ef567890ab129f3c',
    enabledChainIds: {'ethereum'},
    note: '旧备注',
  );

  setUp(() async {
    addresses = InMemoryAddressRepository();
    updateAddressNote = UpdateAddressNote(addresses: addresses);
    await addresses.upsert(evmAddress);
  });

  group('UpdateAddressNote', () {
    test('正常更新备注_首尾去除空白并保存成功', () async {
      final res = await updateAddressNote(addressId: 'ad1', note: '  新的重要地址  ');
      expect(res.isOk, isTrue);
      final updated = (res as Ok<WatchAddress>).value;
      expect(updated.note, '新的重要地址');

      final saved = await addresses.byId('ad1');
      expect(saved?.note, '新的重要地址');
    });

    test('允许清空备注', () async {
      final res = await updateAddressNote(addressId: 'ad1', note: '   ');
      expect(res.isOk, isTrue);
      final updated = (res as Ok<WatchAddress>).value;
      expect(updated.note, '');
    });

    test('地址不存在_返回 ValidationFailure', () async {
      final res = await updateAddressNote(
        addressId: 'non_existent',
        note: '备注',
      );
      expect(res.isOk, isFalse);
      final failure = (res as Err<WatchAddress>).failure;
      expect(failure, isA<ValidationFailure>());
      expect(failure.detail, contains('不存在'));
    });

    test('备注超过 100 字符_返回 ValidationFailure', () async {
      final longNote = 'A' * 101;
      final res = await updateAddressNote(addressId: 'ad1', note: longNote);
      expect(res.isOk, isFalse);
      final failure = (res as Err<WatchAddress>).failure;
      expect(failure, isA<ValidationFailure>());
      expect(failure.detail, contains('100'));
    });
  });
}
