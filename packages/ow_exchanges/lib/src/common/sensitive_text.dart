import 'dart:convert';

import 'package:ow_domain/ow_domain.dart';

/// 在回调期间把 [Sensitive] 的字节读成文本。
///
/// 请求头必须是字符串，所以 Key、Passphrase 在组装请求的那一刻会短暂变成
/// `String`。约定：
/// - 只在构造单次请求时调用，结果随请求对象一起丢弃，不缓存、不放进日志与异常；
/// - 能直接用字节完成的操作（HMAC 的密钥）一律走 [Sensitive.use]，不经过本函数。
String sensitiveText(Sensitive value) =>
    value.use((bytes) => utf8.decode(bytes, allowMalformed: true));
