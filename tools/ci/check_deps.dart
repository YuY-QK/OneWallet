// 依赖边界与安全红线的静态检查。规则见 docs/DEV_GUIDELINES_v1.0.md 第 1、2 节。
//
// 用法（在仓库根目录）：dart run tools/ci/check_deps.dart
// 先运行 `flutter pub get`，脚本需要 .dart_tool/package_config.json。
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

/// 每个包允许依赖的内部包。
const internalAllowed = <String, Set<String>>{
  'ow_domain': {},
  'ow_application': {'ow_domain'},
  'ow_data': {'ow_domain'},
  'ow_net': {'ow_domain'},
  'ow_directory': {'ow_domain'},
  'ow_chains': {'ow_domain', 'ow_net'},
  'ow_exchanges': {'ow_domain', 'ow_net'},
  'ow_pricing': {'ow_domain', 'ow_net'},
  'ow_vault': {'ow_domain'},
  'ow_platform': {'ow_domain'},
};

/// 允许依赖 Flutter 的包。其余必须是纯 Dart。
const flutterAllowed = {'ow_platform'};

/// ow_vault 的完整依赖白名单。新增需要写 ADR。
///
/// - `blockchain_utils`：地址派生（ADR_004）。
/// - `sodium`：libsodium 的 Dart 绑定（ADR_005）。
const vaultAllowed = {'ow_domain', 'blockchain_utils', 'sodium'};

/// 保险库第三方依赖（含传递依赖）中，被 [networkSigns] 命中、但经逐条审阅确认
/// 不会被编进应用的文件。键为包名，值为"包内相对路径 → 理由"。
///
/// 每加一条都要在 docs/ADR_005_libsodium接入.md 的"check_deps 的例外"中写明理由；
/// 脚本另外检查：这些文件不在 ow_vault 的导入闭包内、并且确实存在（依赖升级后
/// 文件消失或改名时报错，迫使重新审阅）。
const vaultNetworkSignExceptions = <String, Map<String, String>>{
  'sodium': {
    // `dart run sodium:update_web` 命令行工具下载 sodium.js 用的 HttpClient。
    // 只被 bin/update_web.dart 导入；包的公开库（sodium.dart、sodium_sumo.dart）
    // 及其全部条件导入分支都不导入它（下方 _checkVaultImportClosure 逐次验证）。
    'lib/src/js/update_web/js_library_loader.dart':
        'sodium:update_web 命令行工具的下载代码，不在保险库的导入闭包内',
  },
};

/// 保险库自身代码中禁止出现的导入。
final vaultForbiddenImports = RegExp(
  r'''import\s+['"](dart:io|dart:html|dart:js|dart:js_interop|package:http/|package:dio/|package:web_socket)''',
);

/// 保险库的第三方依赖中不得出现的联网迹象。
final networkSigns = RegExp(
  r'''(import\s+['"](dart:html|package:http/|package:dio/|package:web_socket)|\bHttpClient\s*\(|\bSocket\.connect\b|\bWebSocket\.connect\b)''',
);

/// 交易所适配器中不得出现的能动用资金的接口路径。
final fundMovingPaths = RegExp(
  r'''['"][^'"\n]*(/order|/trade/|withdraw|/transfer|/sub-account/transfer|/convert)[^'"\n]*['"]''',
  caseSensitive: false,
);

/// 被 [fundMovingPaths] 误拦、但确属只读的接口路径。
///
/// 每加一条都要在旁边注明用途和官方文档链接，并在 docs/EXTERNAL_APIS.md 中记录。
const readOnlyPathAllowlist = <String>{
  // Binance：资金账户返回字段 `withdrawing`（提现中的数量，只读字段，计入总量）。
  // 出处：Binance Wallet REST API，Funding Wallet（POST /sapi/v1/asset/get-funding-asset）
  // 文档站页面未能直读，字段取自官方 SDK binance-connector-js 的 clients/wallet（官方 OpenAPI 生成）。
  // 记录于 docs/EXTERNAL_APIS.md 的"Binance"一节。带引号匹配，不会放过含该词的路径。
  "'withdrawing'",
  // Binance：API Key 权限查询（GET /sapi/v1/account/apiRestrictions）返回字段
  // `enableWithdrawals`，只用来判断 Key 是否带提现权限（verify），不调用任何提现接口。
  // 同上，见 clients/wallet 的 GetApiKeyPermissionResponse。
  // 记录于 docs/EXTERNAL_APIS.md 的"Binance"一节。
  "'enableWithdrawals'",
  // OKX：链上赚币进行中订单查询（GET /api/v5/finance/staking-defi/orders-active）。
  // 路径中的 "orders" 命中 `/order`，但这是只读查询，返回持有的质押本金（investData）。
  // 出处：https://www.okx.com/docs-v5/en/（Financial Product - On-chain Earn，GET Active orders）
  // 记录于 docs/EXTERNAL_APIS.md 的"OKX"一节。
  "'/api/v5/finance/staking-defi/orders-active'",
  // OKX：API Key 权限字段的取值 `withdraw`（GET /api/v5/account/config 的 perm），
  // 只用来判断 Key 是否带提现权限（verify），不调用任何提现接口。
  // 出处：https://www.okx.com/docs-v5/en/（Trading Account - GET Account configuration）
  // 记录于 docs/EXTERNAL_APIS.md 的"OKX"一节。
  "'withdraw'",
  // Bybit：资金账户余额查询（GET /v5/asset/transfer/query-account-coins-balance，accountType=FUND）。
  // 路径分组名含 "transfer"，但本接口只查询各币种余额，不发起划转。
  // 出处：https://bybit-exchange.github.io/docs/v5/asset/balance/all-balance（Get All Coins Balance）
  // 记录于 docs/EXTERNAL_APIS.md 的"Bybit"一节。
  "'/v5/asset/transfer/query-account-coins-balance'",
  // Bybit：API Key 权限字段值 `Withdraw`（GET /v5/user/query-api 的 permissions.Wallet），
  // 只用来判断 Key 是否带提现权限（verify），不调用任何提现接口。
  // 出处：https://bybit-exchange.github.io/docs/v5/user/apikey-info（Get API Key Information）
  // 记录于 docs/EXTERNAL_APIS.md 的"Bybit"一节。
  "'Withdraw'",
};

/// 平台名称判断只允许出现在 ow_platform 和 app/lib/bootstrap。
final platformChecks = RegExp(
  r'\b(Platform\.is(Android|IOS|MacOS|Windows|Linux|Fuchsia)|defaultTargetPlatform)\b',
);

final errors = <String>[];

void main() {
  for (final entry in internalAllowed.entries) {
    _checkPackage(entry.key, entry.value);
  }
  _checkVaultSources();
  _checkVaultDependencySources();
  _checkExchangeSources();
  _checkPlatformLeaks();

  if (errors.isEmpty) {
    print('check_deps: 通过');
    return;
  }
  print('check_deps: 发现 ${errors.length} 处违规');
  for (final e in errors) {
    print('  - $e');
  }
  exitCode = 1;
}

void _checkPackage(String name, Set<String> allowedInternal) {
  final deps = _dependencies('packages/$name/pubspec.yaml');
  for (final dep in deps) {
    if (dep.startsWith('ow_') && !allowedInternal.contains(dep)) {
      errors.add('$name 不得依赖 $dep');
    }
    if ((dep == 'flutter' || dep.startsWith('flutter_')) &&
        !flutterAllowed.contains(name)) {
      errors.add('$name 必须是纯 Dart 包，不得依赖 $dep');
    }
  }
  if (name == 'ow_vault') {
    for (final dep in deps.difference(vaultAllowed)) {
      errors.add('ow_vault 的依赖 $dep 不在白名单内（新增需写 ADR）');
    }
  }
}

void _checkVaultSources() {
  for (final file in _dartFiles('packages/ow_vault/lib')) {
    _scan(file, vaultForbiddenImports, '保险库代码不得导入');
  }
}

/// 扫描保险库全部第三方依赖（白名单内的包及其**传递依赖**）的 `lib/`，
/// 不得出现联网迹象；[vaultNetworkSignExceptions] 中登记的文件除外，
/// 但这些文件必须存在且不在保险库的导入闭包内。
void _checkVaultDependencySources() {
  final roots = _packageRoots();
  if (roots == null) return;
  final closure = <String>{};
  final pending = [...vaultAllowed.where((d) => !d.startsWith('ow_'))];
  while (pending.isNotEmpty) {
    final dep = pending.removeLast();
    if (!closure.add(dep)) continue;
    final dir = roots[dep];
    if (dir == null) {
      errors.add('在 package_config.json 中找不到保险库的依赖 $dep');
      continue;
    }
    pending.addAll(_dependencies('$dir/pubspec.yaml'));
  }
  for (final dep in closure) {
    final dir = roots[dep];
    if (dir == null) continue;
    final exceptions = vaultNetworkSignExceptions[dep] ?? const {};
    for (final path in exceptions.keys) {
      if (!File('$dir/$path').existsSync()) {
        errors.add('保险库依赖的例外文件已不存在，请重新审阅：$dep/$path');
      }
    }
    for (final file in _dartFiles('$dir/lib')) {
      final relative = File(file.path).absolute.path
          .substring(Directory(dir).absolute.path.length + 1);
      if (exceptions.containsKey(relative.replaceAll(r'\', '/'))) continue;
      _scan(file, networkSigns, '保险库的依赖 $dep 含有联网代码');
    }
  }
  for (final dep in vaultNetworkSignExceptions.keys) {
    if (!closure.contains(dep)) {
      errors.add('vaultNetworkSignExceptions 中的 $dep 已不是保险库的依赖，请删除该例外');
    }
  }
  _checkVaultImportClosure(roots);
}

/// 从 `packages/ow_vault/lib` 出发，沿 import、export、part（含全部条件导入分支）
/// 求出可达的源文件，确认其中没有 [vaultNetworkSignExceptions] 登记的文件，
/// 也没有任何联网迹象。条件分支全部计入，比任一平台实际编译的范围更大，因此偏保守。
void _checkVaultImportClosure(Map<String, String> roots) {
  final exceptionFiles = {
    for (final MapEntry(key: dep, value: files)
        in vaultNetworkSignExceptions.entries)
      if (roots[dep] case final dir?)
        for (final path in files.keys) File('$dir/$path').absolute.path,
  };
  final visited = <String>{};
  final pending = [
    for (final f in _dartFiles('packages/ow_vault/lib')) f.absolute.path,
  ];
  while (pending.isNotEmpty) {
    final path = pending.removeLast();
    if (!visited.add(path)) continue;
    final file = File(path);
    if (!file.existsSync()) continue;
    if (exceptionFiles.contains(path)) {
      errors.add('保险库的导入闭包包含了登记为例外的联网文件：$path');
    }
    _scan(file, networkSigns, '保险库的导入闭包含有联网代码');
    for (final uri in _directiveUris(file.readAsStringSync())) {
      final target = _resolveImport(uri, file, roots);
      if (target != null) pending.add(target);
    }
  }
}

final _directive = RegExp(
  r'''(?:^|[;\s])(?:import|export|part)\s+((?:'[^']*'|"[^"]*")(?:\s*if\s*\([^)]*\)\s*(?:'[^']*'|"[^"]*"))*)''',
  multiLine: true,
);
final _quoted = RegExp(r'''['"]([^'"]*)['"]''');

/// 源码中 import、export、part 指令引用的全部 URI（含条件导入的每个分支）。
Iterable<String> _directiveUris(String source) sync* {
  for (final m in _directive.allMatches(source)) {
    for (final q in _quoted.allMatches(m.group(1)!)) {
      yield q.group(1)!;
    }
  }
}

/// 把 [uri] 解析为文件的绝对路径；`dart:` 库返回 null。
String? _resolveImport(String uri, File from, Map<String, String> roots) {
  if (uri.startsWith('dart:')) return null;
  if (uri.startsWith('package:')) {
    final rest = uri.substring('package:'.length);
    final slash = rest.indexOf('/');
    final dir = roots[rest.substring(0, slash)];
    if (dir == null) return null;
    return File('$dir/lib/${rest.substring(slash + 1)}').absolute.path;
  }
  return File(from.parent.uri.resolve(uri).toFilePath()).absolute.path;
}

/// package_config.json 中每个包的根目录。读不到时记一条错误并返回 null。
Map<String, String>? _packageRoots() {
  final configFile = File('.dart_tool/package_config.json');
  if (!configFile.existsSync()) {
    errors.add('缺少 .dart_tool/package_config.json，请先运行 flutter pub get');
    return null;
  }
  final config = jsonDecode(configFile.readAsStringSync()) as Map;
  final packages = (config['packages'] as List).cast<Map<Object?, Object?>>();
  return {
    for (final entry in packages)
      entry['name']! as String: () {
        final root = Uri.parse(entry['rootUri']! as String);
        final resolved = root.isAbsolute
            ? root
            : configFile.parent.absolute.uri.resolveUri(root);
        final path = resolved.toFilePath();
        return path.endsWith('/') ? path.substring(0, path.length - 1) : path;
      }(),
  };
}

void _checkExchangeSources() {
  for (final file in _dartFiles('packages/ow_exchanges/lib')) {
    _scan(
      file,
      fundMovingPaths,
      '交易所适配器不得包含能动用资金的接口',
      allow: (match) => readOnlyPathAllowlist.any(match.contains),
    );
  }
}

void _checkPlatformLeaks() {
  final roots = [
    'app/lib',
    for (final name in internalAllowed.keys)
      if (name != 'ow_platform') 'packages/$name/lib',
  ];
  for (final root in roots) {
    for (final file in _dartFiles(root)) {
      if (file.path.replaceAll(r'\', '/').contains('app/lib/bootstrap/')) {
        continue;
      }
      _scan(file, platformChecks, '平台名称判断只能出现在 ow_platform 和 bootstrap');
    }
  }
}

void _scan(
  File file,
  RegExp pattern,
  String message, {
  bool Function(String match)? allow,
}) {
  final lines = file.readAsLinesSync();
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.trimLeft().startsWith('//')) continue;
    final match = pattern.firstMatch(line);
    if (match != null && !(allow?.call(match.group(0)!) ?? false)) {
      errors.add('$message：${file.path}:${i + 1}  ${match.group(0)}');
    }
  }
}

Iterable<File> _dartFiles(String dir) {
  final d = Directory(dir);
  if (!d.existsSync()) return const [];
  return d
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));
}

/// 读取 pubspec.yaml 中 `dependencies:` 段的包名（不含 dev_dependencies）。
Set<String> _dependencies(String pubspecPath) {
  final file = File(pubspecPath);
  if (!file.existsSync()) {
    errors.add('找不到 $pubspecPath');
    return {};
  }
  final result = <String>{};
  var inDeps = false;
  for (final line in file.readAsLinesSync()) {
    if (RegExp(r'^\S').hasMatch(line)) {
      inDeps = line.startsWith('dependencies:');
      continue;
    }
    if (!inDeps) continue;
    final m = RegExp(r'^  ([a-zA-Z0-9_]+):').firstMatch(line);
    if (m != null) result.add(m.group(1)!);
  }
  return result;
}
