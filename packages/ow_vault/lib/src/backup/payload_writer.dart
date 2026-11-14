import 'dart:typed_data';

import 'package:ow_domain/ow_domain.dart';

import '../vault/item_codec.dart';
import '../vault/vault_file.dart';
import '../vault/vault_item_secret.dart';
import 'backup_format.dart';
import 'backup_names.dart';
import 'backup_payload.dart';
import 'json_writer.dart';

/// 把 [BackupPayload] 编码为载荷 JSON 的 UTF-8 字节（FORMAT.md 第 5 节）。
///
/// 紧凑、字段顺序固定，同样的输入总得到同样的字节（格式钉死测试依赖这一点）。
/// 密钥内容直接从 [Sensitive] 的字节写入，不产生 `String`。
abstract final class PayloadWriter {
  /// 返回的缓冲含明文，调用方用完必须清零。
  ///
  /// 载荷不合法（保险库条目 id 不符合规则、助记词或私钥为空或过长）时抛出
  /// [ArgumentError]，信息不含内容。
  static Uint8List encode(BackupPayload payload) {
    check(payload);
    return JsonWriter.build((w) => _payload(w, payload));
  }

  /// 检查 [payload] 能否编码，不能时抛出 [ArgumentError]（信息不含内容）。
  static void check(BackupPayload payload) {
    for (final item in payload.vaultItems) {
      if (!VaultFile.itemIdPattern.hasMatch(item.id) ||
          ItemCodec.invalidReason(item.secret) != null) {
        throw ArgumentError('备份中的保险库条目不合法');
      }
    }
  }

  static void _payload(JsonWriter w, BackupPayload p) => w.object(() {
    w.field('format');
    w.string(payloadFormatId);
    w.field('payload_version');
    w.integer(payloadVersion);
    w.field('exported_at');
    w.string(formatTimestamp(p.exportedAt));
    w.field('accounts');
    w.array(p.accounts, (a) => _account(w, a));
    w.field('addresses');
    w.array(p.addresses, (a) => _address(w, a));
    w.field('vault_items');
    w.array(p.vaultItems, (i) => _vaultItem(w, i, p.linkedAccountIds(i.id)));
    w.field('settings');
    _settings(w, p.settings);
    final credentials = p.exchangeCredentials;
    if (credentials != null) {
      w.field('exchange_credentials');
      w.array(credentials, (c) => _credential(w, c));
    }
  });

  static void _account(JsonWriter w, Account a) => w.object(() {
    w.field('id');
    w.string(a.id);
    w.field('type');
    w.string(accountTypeName(a.type));
    w.field('name');
    w.string(a.name);
    w.field('color_index');
    w.integer(a.colorIndex);
    w.field('note');
    w.string(a.note);
    w.field('wallet_source');
    w.stringOrNull(
      a.walletSource == null ? null : walletSourceName(a.walletSource!),
    );
    w.field('exchange');
    w.stringOrNull(a.exchange == null ? null : exchangeIdName(a.exchange!));
    w.field('vault_item_id');
    w.stringOrNull(a.vaultItemId);
    w.field('backup');
    w.object(() {
      w.field('offline_backed_up');
      w.boolean(a.backup.offlineBackedUp);
      w.field('offline_verified_at');
      final verified = a.backup.offlineVerifiedAt;
      w.stringOrNull(verified == null ? null : formatTimestamp(verified));
      w.field('keyless');
      w.boolean(a.backup.keyless);
    });
    w.field('created_at');
    w.string(formatTimestamp(a.createdAt));
  });

  static void _address(JsonWriter w, WatchAddress a) => w.object(() {
    w.field('id');
    w.string(a.id);
    w.field('account_id');
    w.string(a.accountId);
    w.field('family');
    w.string(chainFamilyName(a.family));
    w.field('address');
    w.string(a.address);
    w.field('enabled_chains');
    w.array([...a.enabledChainIds]..sort(), w.string);
    w.field('scheme');
    w.stringOrNull(a.scheme == null ? null : derivationSchemeName(a.scheme!));
    w.field('derivation_index');
    w.integerOrNull(a.derivationIndex);
    w.field('note');
    w.string(a.note);
  });

  static void _vaultItem(
    JsonWriter w,
    BackupVaultItem item,
    List<String> linked,
  ) => w.object(() {
    w.field('id');
    w.string(item.id);
    w.field('name');
    w.string(item.name);
    w.field('kind');
    w.string(itemKindName(item.kind));
    w.field('created_at');
    w.string(formatTimestamp(item.createdAt));
    w.field('linked_account_ids');
    w.array(linked, w.string);
    switch (item.secret) {
      case MnemonicSecret(:final mnemonic, :final passphrase):
        final hex =
            !_isText(mnemonic) || (passphrase != null && !_isText(passphrase));
        _encodingMark(w, hex);
        _secret(w, 'mnemonic', mnemonic, hex);
        if (passphrase != null) _secret(w, 'passphrase', passphrase, hex);
      case PrivateKeySecret(:final family, :final key):
        final hex = !_isText(key, asciiOnly: true);
        _encodingMark(w, hex);
        w.field('family');
        w.string(chainFamilyName(family));
        _secret(w, 'private_key', key, hex);
    }
  });

  static void _settings(JsonWriter w, BackupSettings s) => w.object(() {
    w.field('quote');
    w.string(quoteName(s.quote));
    w.field('hide_small');
    w.boolean(s.hideSmall);
    w.field('theme');
    w.string(themeName(s.theme));
    w.field('auto_lock');
    w.string(autoLockName(s.autoLock));
  });

  static void _credential(JsonWriter w, BackupExchangeCredential c) =>
      w.object(() {
        final ExchangeCredentials(:apiKey, :apiSecret, :passphrase) =
            c.credentials;
        final hex =
            !_isText(apiKey) ||
            !_isText(apiSecret) ||
            (passphrase != null && !_isText(passphrase));
        w.field('account_id');
        w.string(c.accountId);
        _encodingMark(w, hex);
        _secret(w, 'api_key', apiKey, hex);
        _secret(w, 'api_secret', apiSecret, hex);
        if (passphrase != null) _secret(w, 'passphrase', passphrase, hex);
      });

  static bool _isText(Sensitive value, {bool asciiOnly = false}) =>
      value.use((b) => JsonWriter.isPlainText(b, asciiOnly: asciiOnly));

  /// 一个对象的任一密钥字段不能写成文本时，该对象的全部密钥字段都写成十六进制，
  /// 并加 `"encoding":"hex"`。
  static void _encodingMark(JsonWriter w, bool hex) {
    if (!hex) return;
    w.field('encoding');
    w.string(hexEncoding);
  }

  static void _secret(JsonWriter w, String name, Sensitive value, bool hex) {
    w.field(name);
    value.use(hex ? w.secretHex : w.secretText);
  }
}
