import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ow_platform/ow_platform.dart';

/// 平台通道换成内存实现，只验证前缀与清除逻辑；
/// 钥匙串、Keystore 的真实行为只能在设备上验证。
void main() {
  late Map<String, String> data;
  late SecureSecretStore store;

  setUp(() {
    data = {};
    FlutterSecureStorage.setMockInitialValues(data);
    store = SecureSecretStore();
  });

  test('读写删_往返', () async {
    expect(await store.read('ow.a'), isNull);
    await store.write('ow.a', '值');
    expect(await store.read('ow.a'), '值');
    await store.delete('ow.a');
    expect(await store.read('ow.a'), isNull);
  });

  test('键名缺少前缀_抛参数错误且不写入', () async {
    await expectLater(store.write('a', 'v'), throwsArgumentError);
    await expectLater(store.read('a'), throwsArgumentError);
    await expectLater(store.delete('a'), throwsArgumentError);
    expect(data, isEmpty);
  });

  test('clearAll_只清除ow前缀的条目', () async {
    data['other.x'] = '1';
    await store.write('ow.a', '1');
    await store.write('ow.datasource.alchemy.key', '2');
    await store.clearAll();
    expect(data.keys, ['other.x']);
  });
}
