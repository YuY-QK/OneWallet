// 手动冒烟脚本：用 TronGrid 查询一个 Tron 地址的持仓。不进 CI。
//
// 用法（在 packages/ow_chains 目录）：
//   OW_TRONGRID_KEY=<你的 Key> dart run tool/smoke_tron.dart <地址>
//   dart run tool/smoke_tron.dart <地址>          # 不设 Key：可能被严格限频
//
// Key 可缺省；只从环境变量读取，不写文件、不打印。
// 脚本只内置 USDT 的 decimals，其余代币走合约信息接口，用来验证两条路径。
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:ow_chains/ow_chains.dart';
import 'package:ow_domain/ow_domain.dart';

final class _EnvConfig implements DataSourceConfig {
  _EnvConfig(this._key);
  final String? _key;

  @override
  Future<String?> apiKey(String providerId) async =>
      providerId == 'trongrid' ? _key : null;

  @override
  Future<Uri?> customEndpoint(String chainId) async => null;
}

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('用法：dart run tool/smoke_tron.dart <地址>');
    exitCode = 64;
    return;
  }
  final address = AddressCodec.normalize(args[0], ChainFamily.tron);
  const codec = AddressCodec(checksum: ChainAddressChecksum());
  if (!codec.isValid(address, ChainFamily.tron)) {
    stderr.writeln('不是合法的 Tron 地址');
    exitCode = 64;
    return;
  }
  final chain = Chains.byId('tron');
  final key = Platform.environment['OW_TRONGRID_KEY'];
  final adapter = TronChainAdapter(
    config: _EnvConfig(key),
    knownDecimals: const {'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t': 6},
  );
  print(
    '链：${chain.name}  地址：${AddressCodec.shorten(address)}  '
    'Key：${key == null || key.isEmpty ? '未设置' : '已设置'}',
  );

  final result = await adapter.fetchHoldings(address, chain);
  switch (result) {
    case Ok(:final value):
      if (value.isEmpty) print('无持仓（地址可能未激活）');
      for (final h in value) {
        final label = switch (h.token) {
          NativeToken() => h.symbolHint ?? 'TRX',
          ContractToken(:final contract) =>
            '${h.symbolHint ?? '(无符号)'} ${AddressCodec.shorten(contract)}',
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
  print('账户已激活：${active.valueOrNull ?? '查询失败'}');
}
