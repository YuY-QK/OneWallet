// 交易所只读适配器的冒烟脚本（需要真实网络与只读 Key，由用户在自己的机器上运行）。
//
// 用法（在 packages/ow_exchanges 目录）：
//   OW_BINANCE_KEY=<Key> OW_BINANCE_SECRET=<Secret> dart run tool/smoke_exchange.dart binance
//
// 环境变量：OW_<交易所大写>_KEY、OW_<交易所大写>_SECRET；OKX、Bitget 另需
// OW_<交易所大写>_PASSPHRASE。脚本只打印权限判断与各子账户按币种的数量，
// 不打印任何凭据。目前已实现 binance、okx。
//
//   OW_OKX_KEY=<Key> OW_OKX_SECRET=<Secret> OW_OKX_PASSPHRASE=<Passphrase> \
//     dart run tool/smoke_exchange.dart okx
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ow_domain/ow_domain.dart';
import 'package:ow_exchanges/ow_exchanges.dart';

class _SystemClock implements Clock {
  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}

Sensitive? _env(String name) {
  final v = Platform.environment[name];
  if (v == null || v.isEmpty) return null;
  return Sensitive(Uint8List.fromList(utf8.encode(v)));
}

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('用法：dart run tool/smoke_exchange.dart <binance|okx>');
    exitCode = 64;
    return;
  }
  final name = args.single.toLowerCase();
  final prefix = 'OW_${name.toUpperCase()}';
  final ExchangeAdapter adapter;
  switch (name) {
    case 'binance':
      adapter = BinanceAdapter(clock: _SystemClock());
    case 'okx':
      adapter = OkxAdapter(clock: _SystemClock());
    default:
      stderr.writeln('尚未实现的交易所：$name');
      exitCode = 64;
      return;
  }

  final key = _env('${prefix}_KEY');
  final secret = _env('${prefix}_SECRET');
  if (key == null || secret == null) {
    stderr.writeln('请设置环境变量 ${prefix}_KEY 与 ${prefix}_SECRET');
    exitCode = 64;
    return;
  }
  final credentials = ExchangeCredentials(
    apiKey: key,
    apiSecret: secret,
    passphrase: _env('${prefix}_PASSPHRASE'),
  );

  final check = await adapter.verify(credentials);
  switch (check) {
    case Err<CredentialCheck>(:final failure):
      stdout.writeln('verify 失败：$failure');
      exitCode = 1;
      return;
    case Ok<CredentialCheck>(:final value):
      stdout.writeln('权限判断：${value.permission.name}');
  }

  final holdings = await adapter.fetchHoldings(credentials);
  switch (holdings) {
    case Err<List<(ExchangeSubAccount, RawHolding)>>(:final failure):
      stdout.writeln('fetchHoldings 失败：$failure');
      exitCode = 1;
    case Ok<List<(ExchangeSubAccount, RawHolding)>>(:final value):
      for (final (sub, h) in value) {
        final symbol = (h.token as ExchangeToken).symbol;
        stdout.writeln(
          '${sub.name.padRight(8)} ${symbol.padRight(10)} ${h.amount}',
        );
      }
      stdout.writeln('共 ${value.length} 条');
      if (adapter is BinanceAdapter) {
        stdout.writeln('因无权限被跳过：${adapter.lastSkipped}');
      }
      if (adapter is OkxAdapter) {
        stdout.writeln('因无权限被跳过：${adapter.lastSkipped}');
      }
  }

  final addresses = await adapter.fetchDepositAddresses(credentials);
  stdout.writeln('充值地址：${addresses.valueOrNull?.length ?? '失败'} 条（只打印数量）');
}
