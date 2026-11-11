// CoinGecko 价格源冒烟测试：需要真实网络，由用户在自己的机器上手动运行。
//
// 用法（在 packages/ow_pricing 目录下）：
//   dart run tool/smoke_price.dart            打印 BTC、ETH、USDT 的 USD 价格
//   dart run tool/smoke_price.dart --catalog  检查内置映射表中每个 priceId 是否都能查到价格
//
// Key 从环境变量 OW_COINGECKO_KEY 读取，可缺省（免费档无 Key 限频很严）。
// 脚本不打印、不保存 Key。
import 'dart:io';

import 'package:ow_domain/ow_domain.dart';
import 'package:ow_pricing/ow_pricing.dart';

class _SystemClock implements Clock {
  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}

class _EnvConfig implements DataSourceConfig {
  @override
  Future<String?> apiKey(String providerId) async => providerId == 'coingecko'
      ? Platform.environment['OW_COINGECKO_KEY']
      : null;

  @override
  Future<Uri?> customEndpoint(String chainId) async => null;
}

Future<void> main(List<String> args) async {
  final catalog = BuiltInAssetCatalog();
  final source = CoinGeckoPriceSource(
    config: _EnvConfig(),
    clock: _SystemClock(),
    catalog: catalog,
  );
  final hasKey = (Platform.environment['OW_COINGECKO_KEY'] ?? '').isNotEmpty;
  stdout.writeln('CoinGecko 冒烟测试（${hasKey ? '使用 Key' : '无 Key'}）');

  if (args.contains('--catalog')) {
    await _checkCatalog(source, catalog);
    return;
  }

  final assets = {
    for (final id in ['BTC', 'ETH', 'USDT']) catalog.byId(id)!,
  };
  final result = await source.fetchPrices(assets, Quote.usd);
  switch (result) {
    case Err(:final failure):
      stdout.writeln('失败：$failure');
      exitCode = 1;
    case Ok(:final value):
      for (final p in value) {
        final change = p.change24hPercent;
        stdout.writeln(
          '${p.assetId}  \$${p.price}  24h ${change == null ? '—' : '$change%'}',
        );
      }
      if (value.length != assets.length) {
        stdout.writeln('缺少 ${assets.length - value.length} 个币的价格');
        exitCode = 1;
      }
  }
}

/// 逐个核对内置映射表里的 priceId 在 CoinGecko 上是否有 USD 价格。
Future<void> _checkCatalog(
  CoinGeckoPriceSource source,
  BuiltInAssetCatalog catalog,
) async {
  final result = await source.fetchPrices(catalog.assets.toSet(), Quote.usd);
  switch (result) {
    case Err(:final failure):
      stdout.writeln('失败：$failure');
      exitCode = 1;
    case Ok(:final value):
      final got = {for (final p in value) p.assetId};
      final missing = catalog.assets.where((a) => !got.contains(a.id)).toList();
      stdout.writeln('有价格 ${got.length} / ${catalog.assets.length}');
      for (final a in missing) {
        stdout.writeln('无价格：${a.id}（priceId=${a.priceId}），请核对该标识');
      }
      if (missing.isNotEmpty) exitCode = 1;
  }
}
