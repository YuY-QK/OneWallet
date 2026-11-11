import 'package:ow_domain/ow_domain.dart';

/// 界面传入的一个待添加地址（P05）。
final class AddressInput {
  /// [chainIds] 会被复制为不可修改的集合。
  AddressInput({required this.raw, this.family, Set<String>? chainIds})
    : chainIds = chainIds == null ? null : Set.unmodifiable(chainIds);

  /// 用户输入的原始字符串，可含首尾空白。
  final String raw;

  /// 用户选定的链家族；为 null 时由 [AddressCodec.detectFamily] 识别。
  final ChainFamily? family;

  /// 要启用的链 id；为 null 时取默认：EVM 为全部六条 EVM 链（R3），
  /// 其他家族为该家族唯一的一条链。
  final Set<String>? chainIds;
}
