import 'package:ow_domain/ow_domain.dart';

/// 保险库条目的明文内容。只在保险库会话内短暂存在。
///
/// 内容以 [Sensitive] 字节持有，`toString()` 不输出内容。谁持有谁负责 [wipe]：
/// 传给 `VaultSession.addItem` 的对象仍归调用方；`VaultSession.readItem`
/// 返回的对象归调用方。
sealed class VaultItemSecret {
  const VaultItemSecret();

  /// 条目类型。
  VaultItemKind get kind;

  /// 覆写清零全部内容。可重复调用。
  void wipe();
}

/// 助记词条目。
///
/// [mnemonic] 为助记词原文的字节（应用层约定为规范化后的 UTF-8：小写、单个空格
/// 分隔）；保险库按字节原样保存，不做校验与规范化，查重指纹也按字节计算。
/// [passphrase] 为可选的 BIP39 附加密码（"第 25 个词"），null 表示没有。
final class MnemonicSecret extends VaultItemSecret {
  const MnemonicSecret({required this.mnemonic, this.passphrase});

  final Sensitive mnemonic;
  final Sensitive? passphrase;

  @override
  VaultItemKind get kind => VaultItemKind.mnemonic;

  @override
  void wipe() {
    mnemonic.wipe();
    passphrase?.wipe();
  }

  @override
  String toString() => 'MnemonicSecret(***)';
}

/// 私钥条目：原始私钥字节与所属链家族。
final class PrivateKeySecret extends VaultItemSecret {
  const PrivateKeySecret({required this.family, required this.key});

  final ChainFamily family;
  final Sensitive key;

  @override
  VaultItemKind get kind => VaultItemKind.privateKey;

  @override
  void wipe() => key.wipe();

  @override
  String toString() => 'PrivateKeySecret(${family.name}, ***)';
}
