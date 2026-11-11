// 由 asset_mappings.json 生成内嵌数据文件 lib/src/catalog/asset_mappings_data.dart。
//
// 用法（在 packages/ow_pricing 目录下）：dart run tool/generate_mappings.dart
// 修改 asset_mappings.json 后必须重新运行；测试会检查两者一致。
import 'dart:io';

void main() {
  final json = File('asset_mappings.json').readAsStringSync();
  if (json.contains("'''")) {
    stderr.writeln("asset_mappings.json 不得包含 '''");
    exitCode = 1;
    return;
  }
  File('lib/src/catalog/asset_mappings_data.dart').writeAsStringSync(
    '// 由 tool/generate_mappings.dart 从 asset_mappings.json 生成，请勿手改。\n'
    '\n'
    '/// asset_mappings.json 的原文。\n'
    "const String builtInAssetMappingsJson = r'''$json''';\n",
  );
  stdout.writeln('已生成 lib/src/catalog/asset_mappings_data.dart');
}
