import 'package:ow_domain/ow_domain.dart';

/// 打开保险库的方式（规格 3.1 节）。
sealed class VaultCredential {
  const VaultCredential();
}

/// 主密码方式。
final class PasswordCredential extends VaultCredential {
  const PasswordCredential(this.password);

  /// 主密码，所有权归调用方，调用方用完负责 wipe。
  final Sensitive password;
}

/// 生物识别方式。
final class BiometricCredential extends VaultCredential {
  const BiometricCredential({required this.reason});

  /// 系统生物识别弹窗上的说明文字。
  final String reason;
}
