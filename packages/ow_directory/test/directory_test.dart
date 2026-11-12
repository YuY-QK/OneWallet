import 'dart:convert';
import 'dart:io';

import 'package:ow_directory/ow_directory.dart';
import 'package:ow_directory/src/directory_data.g.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

void main() {
  final directory = ThirdPartyDirectory.builtin();

  test('内置数据通过校验器，零问题', () {
    expect(DirectoryValidator.validateJson(directoryJson), isEmpty);
  });

  test('data/directory.json 与内嵌常量一致', () {
    final file = File('data/directory.json');
    expect(
      file.readAsStringSync(),
      directoryJson,
      reason: 'directory.json 改了但没重新生成：cd packages/ow_directory && dart run tool/embed.dart',
    );
  });

  test('已接入的 4 家交易所都能通过 forExchange 找到', () {
    for (final id in ExchangeId.values) {
      final e = directory.forExchange(id);
      expect(e, isNotNull, reason: id.name);
      expect(e!.integration, IntegrationLevel.integrated);
      expect(e.isVerified, isTrue);
      expect(e.link(LinkKind.website), isNotNull);
    }
  });

  test('9 条链都能通过 explorerFor 找到，模板与 ow_domain 一致', () {
    expect(Chains.all, hasLength(9));
    for (final chain in Chains.all) {
      final e = directory.explorerFor(chain.id);
      expect(e, isNotNull, reason: chain.id);
      expect(
        e!.explorer!.addressUrlTemplate,
        chain.explorerAddressUrl,
        reason: chain.id,
      );
    }
  });

  test('5 个来源钱包都在，并带有托管与导出信息', () {
    for (final id in [
      'uniswap-wallet',
      'metamask',
      'okx-web3-wallet',
      'bitget-wallet',
      'trust-wallet',
    ]) {
      final e = directory.byId(id);
      expect(e, isNotNull, reason: id);
      expect(e!.kind, DirectoryKind.wallet);
      expect(e.wallet, isNotNull);
      expect(e.isVerified, isTrue);
    }
  });

  test('数据服务齐全', () {
    for (final id in [
      'alchemy',
      'coingecko',
      'mempool-space',
      'blockstream',
      'solana-rpc',
      'trongrid',
      'helius',
    ]) {
      expect(directory.byId(id)?.kind, DirectoryKind.dataProvider, reason: id);
    }
  });

  test('search 按名称与中文别名查找，不区分大小写', () {
    expect(directory.search('BINANCE').map((e) => e.id), contains('binance'));
    expect(directory.search('币安').map((e) => e.id), contains('binance'));
    expect(directory.search('欧易').map((e) => e.id), contains('okx'));
    expect(directory.search('小狐狸').map((e) => e.id), contains('metamask'));
    expect(directory.search('不存在的名字xyz'), isEmpty);
    expect(directory.search('  '), hasLength(directory.all.length));
  });

  test('byKind 与 verifiedOnly', () {
    expect(directory.byKind(DirectoryKind.exchange), isNotEmpty);
    expect(directory.byKind(DirectoryKind.hardwareWallet), isNotEmpty);
    expect(directory.verifiedOnly.every((e) => e.isVerified), isTrue);
    expect(directory.verifiedOnly.length, lessThan(directory.all.length));
  });

  test('未核对的条目没有链接', () {
    for (final e in directory.all.where((e) => !e.isVerified)) {
      expect(e.links, isEmpty, reason: e.id);
      expect(e.notes, contains('待核对'), reason: e.id);
    }
  });

  group('向前兼容', () {
    String doc(List<Map<String, Object?>> entries) =>
        jsonEncode({'schemaVersion': 1, 'entries': entries});
    Map<String, Object?> entry(String id, Map<String, Object?> extra) => {
      'id': id,
      'kind': 'exchange',
      'name': id,
      'officialDomains': ['example.com'],
      'integration': 'none',
      ...extra,
    };

    test('未知 kind：跳过该条目，其余照常解析', () {
      final d = ThirdPartyDirectory.fromJson(
        doc([
          entry('a', {'kind': 'futureKind'}),
          entry('b', {}),
        ]),
      );
      expect(d.all.map((e) => e.id), ['b']);
    });

    test('未知 link 键：跳过该链接，其余链接保留', () {
      final d = ThirdPartyDirectory.fromJson(
        doc([
          entry('a', {
            'links': {
              'website': 'https://example.com',
              'futureLink': 'https://example.com/x',
            },
          }),
        ]),
      );
      expect(d.byId('a')!.links.keys, [LinkKind.website]);
    });

    test('未知 integration 视为 none；未知 custody 丢弃 wallet 子结构', () {
      final d = ThirdPartyDirectory.fromJson(
        doc([
          entry('a', {
            'kind': 'wallet',
            'integration': 'future',
            'wallet': {'custody': 'future', 'families': <String>[]},
          }),
        ]),
      );
      expect(d.byId('a')!.integration, IntegrationLevel.none);
      expect(d.byId('a')!.wallet, isNull);
    });

    test('重复 id 只保留第一个；坏 JSON 得到空目录', () {
      expect(
        ThirdPartyDirectory.fromJson(doc([entry('a', {}), entry('a', {})])).all,
        hasLength(1),
      );
      expect(ThirdPartyDirectory.fromJson('不是json').all, isEmpty);
      expect(ThirdPartyDirectory.fromJson('{"entries": 1}').all, isEmpty);
    });
  });
}
