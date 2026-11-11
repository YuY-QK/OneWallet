// 手动冒烟脚本：用真实 Alchemy Key 查询一个 EVM 地址的持仓。不进 CI。
//
// 用法（在 packages/ow_chains 目录）：
//   OW_ALCHEMY_KEY=<你的 Key> dart run tool/smoke_evm.dart <地址> [链id，默认 ethereum]
//
// Key 只从环境变量读取，不写文件、不打印。
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:ow_chains/ow_chains.dart';
import 'package:ow_domain/ow_domain.dart';

final class _EnvConfig implements DataSourceConfig {
  _EnvConfig(this._key);
  final String? _key;

  @override
  Future<String?> apiKey(String providerId) async => _key;

  @override
  Future<Uri?> customEndpoint(String chainId) async => null;
}

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('用法：dart run tool/smoke_evm.dart <地址> [链id]');
    exitCode = 64;
    return;
  }
  final address = AddressCodec.normalize(args[0], ChainFamily.evm);
  const codec = AddressCodec(checksum: ChainAddressChecksum());
  if (!codec.isValid(address, ChainFamily.evm)) {
    stderr.writeln('不是合法的 EVM 地址');
    exitCode = 64;
    return;
  }
  final chain = Chains.tryById(args.length > 1 ? args[1] : 'ethereum');
  if (chain == null || chain.family != ChainFamily.evm) {
    stderr.writeln(
      '未知的 EVM 链，可选：'
      '${Chains.ofFamily(ChainFamily.evm).map((c) => c.id).join('、')}',
    );
    exitCode = 64;
    return;
  }
  final key = Platform.environment['OW_ALCHEMY_KEY'];
  if (key == null || key.isEmpty) {
    stderr.writeln('请先设置环境变量 OW_ALCHEMY_KEY');
    exitCode = 64;
    return;
  }

  final adapter = EvmChainAdapter(config: _EnvConfig(key));
  print('链：${chain.name}  地址：${AddressCodec.shorten(address)}');

  final result = await adapter.fetchHoldings(address, chain);
  switch (result) {
    case Ok(:final value):
      if (value.isEmpty) print('无持仓');
      for (final h in value) {
        final label = h.symbolHint ?? '(无符号)';
        final contract = switch (h.token) {
          ContractToken(:final contract) =>
            '  ${AddressCodec.shorten(contract)}',
          _ => '',
        };
        print('$label  ${h.amount}$contract');
      }
    case Err(:final failure):
      print('失败：$failure');
      exitCode = 1;
      return;
  }

  final active = await adapter.hasActivity(address, chain);
  print('有过交易：${active.valueOrNull ?? '查询失败'}');
}
