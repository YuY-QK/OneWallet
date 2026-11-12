/// 第三方目录：随应用发布的只读参考数据（交易所、钱包、数据服务、区块浏览器的
/// 官网与文档链接）。纯 Dart，不联网，不读写用户数据。
///
/// 数据源是 `data/directory.json`，由 `tool/embed.dart` 生成内嵌常量。
/// 补充条目的方法见 docs/DIRECTORY_COLLECTION_GUIDE.md。
library;

export 'src/directory.dart';
export 'src/directory_entry.dart';
export 'src/directory_enums.dart';
export 'src/directory_validator.dart';
