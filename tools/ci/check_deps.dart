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
const vaultAllowed = {'ow_domain', 'blockchain_utils'};

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

void _checkVaultDependencySources() {
  final configFile = File('.dart_tool/package_config.json');
  if (!configFile.existsSync()) {
    errors.add('缺少 .dart_tool/package_config.json，请先运行 flutter pub get');
    return;
  }
  final config = jsonDecode(configFile.readAsStringSync()) as Map;
  final packages = (config['packages'] as List).cast<Map<Object?, Object?>>();
  for (final dep in vaultAllowed.where((d) => !d.startsWith('ow_'))) {
    final entry = packages.where((p) => p['name'] == dep).firstOrNull;
    if (entry == null) {
      errors.add('在 package_config.json 中找不到 $dep');
      continue;
    }
    final root = Uri.parse(entry['rootUri']! as String);
    final dir = root.isAbsolute
        ? root.toFilePath()
        : configFile.parent.uri.resolveUri(root).toFilePath();
    for (final file in _dartFiles('$dir/lib')) {
      _scan(file, networkSigns, '保险库的依赖 $dep 含有联网代码');
    }
  }
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
