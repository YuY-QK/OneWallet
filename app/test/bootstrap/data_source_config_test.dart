import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/bootstrap/data_source_config.dart';
import 'package:ow_domain/ow_domain.dart';

import 'support.dart';

void main() {
  late FakeSecretStore store;
  late SecretStoreDataSourceConfig config;

  setUp(() {
    store = FakeSecretStore();
    config = SecretStoreDataSourceConfig(store);
  });

  group('API Key', () {
    test('未配置_返回null', () async {
      expect(await config.apiKey('alchemy'), isNull);
    });

    test('写入后读取_键名符合约定_并去掉首尾空白', () async {
      final r = await config.setApiKey('alchemy', '  假的key  ');
      expect(r, isA<Ok<void>>());
      expect(store.data, {'ow.datasource.alchemy.key': '假的key'});
      expect(await config.apiKey('alchemy'), '假的key');
    });

    test('空白内容_拒绝且不写入', () async {
      final r = await config.setApiKey('alchemy', '   ');
      expect(r, isA<Err<void>>());
      expect(store.data, isEmpty);
    });

    test('清除_之后读取为null', () async {
      await config.setApiKey('coingecko', 'k');
      await config.clearApiKey('coingecko');
      expect(await config.apiKey('coingecko'), isNull);
      expect(store.data, isEmpty);
    });

    test('不同服务商互不影响', () async {
      await config.setApiKey('alchemy', 'a');
      await config.setApiKey('coingecko', 'c');
      expect(await config.apiKey('alchemy'), 'a');
      expect(await config.apiKey('coingecko'), 'c');
    });
  });

  group('自定义端点', () {
    test('https地址_保存并读取_键名符合约定', () async {
      final r = await config.setCustomEndpoint(
        'ethereum',
        'https://rpc.example.org/v1/abc',
      );
      expect(r, isA<Ok<void>>());
      expect(store.data.keys, ['ow.datasource.ethereum.endpoint']);
      expect(
        await config.customEndpoint('ethereum'),
        Uri.parse('https://rpc.example.org/v1/abc'),
      );
    });

    test('拒绝非https_http_ftp_无协议_带用户名密码_空主机', () async {
      for (final bad in [
        'http://rpc.example.org',
        'ftp://rpc.example.org',
        'rpc.example.org',
        'https://user:pw@rpc.example.org',
        'https://',
        'ws://rpc.example.org',
        '',
      ]) {
        final r = await config.setCustomEndpoint('ethereum', bad);
        expect(r, isA<Err<void>>(), reason: bad);
      }
      expect(store.data, isEmpty);
    });

    test('存储内容被改成非https_读取按未配置处理', () async {
      store.data['ow.datasource.ethereum.endpoint'] = 'http://evil.example';
      expect(await config.customEndpoint('ethereum'), isNull);
    });

    test('清除', () async {
      await config.setCustomEndpoint('base', 'https://rpc.example.org');
      await config.clearCustomEndpoint('base');
      expect(await config.customEndpoint('base'), isNull);
    });
  });

  test('标识含非法字符_抛参数错误_避免拼出任意键名', () async {
    await expectLater(config.apiKey('a.b'), throwsArgumentError);
    await expectLater(
      config.setCustomEndpoint('../x', 'https://a.example'),
      throwsArgumentError,
    );
  });

  test('toString不含任何配置内容', () async {
    await config.setApiKey('alchemy', 'SECRET-KEY');
    expect('$config', isNot(contains('SECRET-KEY')));
  });
}
