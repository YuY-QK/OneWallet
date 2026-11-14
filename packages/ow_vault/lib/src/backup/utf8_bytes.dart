import 'dart:typed_data';

// UTF-8 合法性的字节级判断，不产生 `String`（密钥内容用）。

/// [bytes] 是否为合法的 UTF-8（拒绝过长编码、代理区码点与超过 U+10FFFF 的值）。
///
/// 在字节上判断，不产生 `String`。
bool isValidUtf8(Uint8List bytes) {
  var i = 0;
  while (i < bytes.length) {
    final n = utf8SequenceLength(bytes, i);
    if (n == 0) return false;
    i += n;
  }
  return true;
}

/// 从 [i] 开始的一个 UTF-8 字符占几个字节；不合法返回 0。
int utf8SequenceLength(Uint8List b, int i) {
  final c = b[i];
  if (c < 0x80) return 1;
  final int n;
  final int min;
  if (c >= 0xc2 && c <= 0xdf) {
    (n, min) = (2, 0x80);
  } else if (c >= 0xe0 && c <= 0xef) {
    (n, min) = (3, 0x800);
  } else if (c >= 0xf0 && c <= 0xf4) {
    (n, min) = (4, 0x10000);
  } else {
    return 0;
  }
  if (i + n > b.length) return 0;
  var cp = c & (0xff >> (n + 1));
  for (var k = 1; k < n; k++) {
    final cc = b[i + k];
    if (cc & 0xc0 != 0x80) return 0;
    cp = cp << 6 | (cc & 0x3f);
  }
  if (cp < min || cp > 0x10ffff || (cp >= 0xd800 && cp <= 0xdfff)) return 0;
  return n;
}
