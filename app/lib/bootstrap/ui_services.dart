import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

// 页面用到的平台服务封装为可 override 的 provider，测试里换成假实现，
// 不依赖平台通道。

/// 读取剪贴板里的文本。没有文本时返回 null。
///
/// 只用于读取**公开地址**；红线禁止的是密钥类数据进剪贴板。
typedef ClipboardReader = Future<String?> Function();

/// 把文本写入剪贴板。只用于**公开地址**。
typedef ClipboardWriter = Future<void> Function(String text);

/// 用系统浏览器打开链接。成功拉起返回 true。
typedef ExternalUrlOpener = Future<bool> Function(Uri url);

final clipboardReaderProvider = Provider<ClipboardReader>(
  (ref) =>
      () async => (await Clipboard.getData(Clipboard.kTextPlain))?.text,
);

final clipboardWriterProvider = Provider<ClipboardWriter>(
  (ref) =>
      (text) => Clipboard.setData(ClipboardData(text: text)),
);

final externalUrlOpenerProvider = Provider<ExternalUrlOpener>(
  (ref) =>
      (url) => launchUrl(url, mode: LaunchMode.externalApplication),
);
