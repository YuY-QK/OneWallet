// 把 data/directory.json 生成为 lib/src/directory_data.g.dart。
//
// 用法（在 packages/ow_directory 下）：dart run tool/embed.dart
// 加 --check 只检查是否一致，不一致时以非零状态退出。
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

const _out = 'lib/src/directory_data.g.dart';

void main(List<String> args) {
  final source = File('data/directory.json');
  if (!source.existsSync()) {
    print('找不到 data/directory.json，请在 packages/ow_directory 下运行');
    exit(2);
  }
  final text = source.readAsStringSync();
  try {
    jsonDecode(text);
  } on FormatException catch (e) {
    print('directory.json 不是合法 JSON：$e');
    exit(2);
  }
  if (text.contains("'''")) {
    print("directory.json 不得包含三个连续的单引号（'''）");
    exit(2);
  }
  final generated =
      '''
// 由 tool/embed.dart 从 data/directory.json 生成，不要手工修改。
// 修改数据后运行：cd packages/ow_directory && dart run tool/embed.dart

/// 内嵌的第三方目录 JSON 原文。
const String directoryJson = r\'\'\'
$text\'\'\';
''';
  if (args.contains('--check')) {
    final current = File(_out).existsSync()
        ? File(_out).readAsStringSync()
        : '';
    if (current != generated) {
      print('$_out 与 data/directory.json 不一致，请运行 dart run tool/embed.dart');
      exit(1);
    }
    print('一致');
    return;
  }
  File(_out).writeAsStringSync(generated);
  print('已生成 $_out');
}
