import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

import '../fakes/fake_repositories.dart';

void main() {
  late InMemoryAddressRepository addresses;
  late DeleteAddress delete;

  WatchAddress addr(String id, String account, String address) => WatchAddress(
    id: id,
    accountId: account,
    family: ChainFamily.evm,
    address: address,
    enabledChainIds: {'ethereum'},
  );

  setUp(() async {
    addresses = InMemoryAddressRepository();
    delete = DeleteAddress(addresses: addresses);
    await addresses.upsert(addr('ad1', 'w1', '0xa1'));
    await addresses.upsert(addr('ad2', 'w1', '0xa2'));
    await addresses.upsert(addr('other', 'w2', '0xb1'));
  });

  test('DeleteAddress_账户还有其他地址_删除该地址', () async {
    final r = await delete('ad1');
    expect(r.isOk, isTrue);
    expect((await addresses.byAccount('w1')).map((a) => a.id), ['ad2']);
    expect(await addresses.byAccount('w2'), hasLength(1));
  });

  test('DeleteAddress_账户只剩一个地址_返回校验失败且不删除', () async {
    final r = await delete('other');
    expect(r.when(ok: (_) => null, err: (f) => f), isA<ValidationFailure>());
    expect(await addresses.byAccount('w2'), hasLength(1));
  });

  test('DeleteAddress_连续删到只剩一个_最后一次被拒绝', () async {
    expect((await delete('ad1')).isOk, isTrue);
    final r = await delete('ad2');
    expect(r.isOk, isFalse);
    expect(await addresses.byAccount('w1'), hasLength(1));
  });

  test('DeleteAddress_地址不存在_什么也不做并返回成功', () async {
    final r = await delete('nope');
    expect(r.isOk, isTrue);
    expect(await addresses.watchAll().first, hasLength(3));
  });
}
