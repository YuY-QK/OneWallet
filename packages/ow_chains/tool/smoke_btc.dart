// 手动冒烟脚本：用 mempool.space 查询一个 Bitcoin 地址的余额。不进 CI。
//
// 用法（在 packages/ow_chains 目录）：
//   dart run tool/smoke_btc.dart <地址> [自定义实例，如 https://my.node/]
//
// 无需 Key。输出的余额应与区块浏览器显示的"已确认余额"一致（不含未确认）。
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:ow_chains/ow_chains.dart';
import 'package:ow_domain/ow_domain.dart';

final class _Config implements DataSourceConfig {
  _Config(this._custom);
  final Uri? _custom;

  @override
  Future<String?> apiKey(String providerId) async => null;

  @override
  Future<Uri?> customEndpoint(String chainId) async => _custom;
}

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('用法：dart run tool/smoke_btc.dart <地址> [自定义实例]');
    exitCode = 64;
    return;
  }
  final address = AddressCodec.normalize(args[0], ChainFamily.bitcoin);
  const codec = AddressCodec(checksum: ChainAddressChecksum());
  if (!codec.isValid(address, ChainFamily.bitcoin)) {
    stderr.writeln('不是合法的 Bitcoin 地址');
    exitCode = 64;
    return;
  }
  final chain = Chains.byId('bitcoin');
  final custom = args.length > 1 ? Uri.tryParse(args[1]) : null;
  final adapter = BitcoinChainAdapter(config: _Config(custom));
  print('链：${chain.name}  地址：${AddressCodec.shorten(address)}');

  final result = await adapter.fetchHoldings(address, chain);
  switch (result) {
    case Ok(:final value):
      if (value.isEmpty) print('已确认余额为 0');
      for (final h in value) {
        print('${h.symbolHint}  ${h.amount}');
      }
    case Err(:final failure):
      print('失败：$failure');
      exitCode = 1;
      return;
  }

  final active = await adapter.hasActivity(address, chain);
  print('有过交易：${active.valueOrNull ?? '查询失败'}');
}
