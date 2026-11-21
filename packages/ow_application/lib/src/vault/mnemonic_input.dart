import 'dart:convert';
import 'dart:typed_data';

import 'package:ow_domain/ow_domain.dart';
import 'package:ow_vault/ow_vault.dart';

/// 把用户输入的助记词规范化并校验（规格 3.4 节）。
///
/// 成功时返回规范化后的 UTF-8 字节（新的 [Sensitive]，归调用方负责 wipe）。
Result<Sensitive> normalizeMnemonic(Sensitive raw) {
  final text = raw.use((bytes) {
    try {
      return utf8.decode(bytes).trim();
    } catch (_) {
      return null;
    }
  });

  if (text == null || text.isEmpty) {
    return const Err(ValidationFailure('mnemonic_invalid'));
  }

  // 规范化：任意空白序列合并为单个半角空格，ASCII 字母转小写
  final normalized = text
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .join(' ');

  final words = normalized.split(' ');
  const validCounts = {12, 15, 18, 21, 24};
  if (!validCounts.contains(words.length)) {
    return const Err(ValidationFailure('mnemonic_invalid'));
  }

  if (!AddressDeriver.isValidMnemonic(normalized)) {
    return const Err(ValidationFailure('mnemonic_invalid'));
  }

  return Ok(Sensitive(Uint8List.fromList(utf8.encode(normalized))));
}
