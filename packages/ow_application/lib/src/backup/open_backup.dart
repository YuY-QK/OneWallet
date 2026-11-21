import 'dart:typed_data';

import 'package:ow_domain/ow_domain.dart';
import 'package:ow_vault/ow_vault.dart';

/// 备份文件的预览信息（不含任何敏感密钥）。
final class BackupPreview {
  const BackupPreview({
    required this.createdAt,
    required this.appVersion,
    required this.accountsCount,
    required this.addressesCount,
    required this.vaultItemsCount,
    required this.hasCredentials,
    required this.skippedCount,
  });

  /// 备份创建时间（UTC）。
  final DateTime createdAt;

  /// 导出备份时的应用版本。
  final String appVersion;

  final int accountsCount;
  final int addressesCount;
  final int vaultItemsCount;
  final bool hasCredentials;
  final int skippedCount;

  @override
  bool operator ==(Object other) =>
      other is BackupPreview &&
      other.createdAt == createdAt &&
      other.appVersion == appVersion &&
      other.accountsCount == accountsCount &&
      other.addressesCount == addressesCount &&
      other.vaultItemsCount == vaultItemsCount &&
      other.hasCredentials == hasCredentials &&
      other.skippedCount == skippedCount;

  @override
  int get hashCode => Object.hash(
    createdAt,
    appVersion,
    accountsCount,
    addressesCount,
    vaultItemsCount,
    hasCredentials,
    skippedCount,
  );

  @override
  String toString() =>
      'BackupPreview(createdAt: $createdAt, version: $appVersion, accounts: $accountsCount, addresses: $addressesCount, items: $vaultItemsCount, hasCredentials: $hasCredentials, skipped: $skippedCount)';
}

/// 待恢复的备份载荷封装（规格 5.3 节）。
///
/// 持有解码出的载荷明文，离开时必须调用 [dispose] 清零。
final class PendingRestore {
  PendingRestore(this._payload, this._header);

  BackupPayload? _payload;
  final BackupHeader _header;

  /// 获取备份预览信息。
  BackupPreview get preview {
    _ensureNotDisposed();
    final p = _payload!;
    return BackupPreview(
      createdAt: _header.createdAt,
      appVersion: _header.appVersion,
      accountsCount: p.accounts.length,
      addressesCount: p.addresses.length,
      vaultItemsCount: p.vaultItems.length,
      hasCredentials: p.exchangeCredentials != null,
      skippedCount: p.skipped.length,
    );
  }

  /// 供恢复用例内部读取载荷。
  BackupPayload get payload {
    _ensureNotDisposed();
    return _payload!;
  }

  /// 清零载荷内容并释放。之后调用任何方法将抛出 [StateError]。
  void dispose() {
    _payload?.wipe();
    _payload = null;
  }

  void _ensureNotDisposed() {
    if (_payload == null) {
      throw StateError('PendingRestore has already been disposed');
    }
  }

  @override
  String toString() => 'PendingRestore(***)';
}

/// 打开并解码备份文件（规格 5.3 节）。
final class OpenBackup {
  OpenBackup({required this.crypto});

  final VaultCrypto crypto;

  /// 打开备份文件。
  ///
  /// 先检查头部结构（不做密码学运算），再通过 Argon2id 派生密钥解密载荷。
  Future<Result<PendingRestore>> call({
    required Uint8List file,
    required Sensitive backupPassword,
  }) async {
    // 1. 结构检查
    final peekRes = BackupCodec.peekHeader(file);
    if (peekRes case Err(:final failure)) {
      return Err(failure);
    }
    final header = peekRes.valueOrNull!;

    // 2. 解码载荷
    final decodeRes = await BackupCodec.decode(
      file: file,
      password: backupPassword,
      crypto: crypto,
    );
    if (decodeRes case Err(:final failure)) {
      return Err(failure);
    }

    return Ok(PendingRestore(decodeRes.valueOrNull!, header));
  }
}
