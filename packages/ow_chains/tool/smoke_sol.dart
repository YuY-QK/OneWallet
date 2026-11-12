// 手动冒烟脚本：查询一个 Solana 地址的持仓。不进 CI。
//
// 用法（在 packages/ow_chains 目录）：
//   OW_HELIUS_KEY=<你的 Key> dart run tool/smoke_sol.dart <地址>
//   dart run tool/smoke_sol.dart <地址>          # 不设 Key：使用官方公共 RPC
//
// Key 可缺省（缺省时走公共 RPC，限制较严，可能被限频）；Key 只从环境变量读取，
// 不写文件、不打印。
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:ow_chains/ow_chains.dart';
import 'package:ow_domain/ow_domain.dart';

final class _EnvConfig implements DataSourceConfig {
  _EnvConfig(this._key);
  final String? _key;

  @override
  Future<String?> apiKey(String providerId) async =>
      providerId == 'helius' ? _key : null;

  @override
  Future<Uri?> customEndpoint(String chainId) async => null;
}

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('用法：dart run tool/smoke_sol.dart <地址>');
    exitCode = 64;
    return;
  }
  final address = AddressCodec.normalize(args[0], ChainFamily.solana);
  const codec = AddressCodec(checksum: ChainAddressChecksum());
  if (!codec.isValid(address, ChainFamily.solana)) {
    stderr.writeln('不是合法的 Solana 地址');
    exitCode = 64;
    return;
  }
  final chain = Chains.byId('solana');
  final key = Platform.environment['OW_HELIUS_KEY'];
  final adapter = SolanaChainAdapter(config: _EnvConfig(key));
  print(
    '链：${chain.name}  地址：${AddressCodec.shorten(address)}  '
    '端点：${key == null || key.isEmpty ? '官方公共 RPC' : 'Helius'}',
  );

  final result = await adapter.fetchHoldings(address, chain);
  switch (result) {
    case Ok(:final value):
      if (value.isEmpty) print('无持仓');
      for (final h in value) {
        final label = switch (h.token) {
          NativeToken() => h.symbolHint ?? 'SOL',
          ContractToken(:final contract) =>
            'mint ${AddressCodec.shorten(contract)}',
          _ => '?',
        };
        print('$label  ${h.amount}');
      }
    case Err(:final failure):
      print('失败：$failure');
      exitCode = 1;
      return;
  }

  final active = await adapter.hasActivity(address, chain);
  print('有过交易：${active.valueOrNull ?? '查询失败'}');
}
