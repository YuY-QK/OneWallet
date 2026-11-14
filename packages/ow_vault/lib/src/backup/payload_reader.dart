import 'dart:typed_data';

import 'package:ow_domain/ow_domain.dart';

import '../vault/item_codec.dart';
import '../vault/vault_file.dart';
import '../vault/vault_item_secret.dart';
import 'backup_format.dart';
import 'backup_names.dart';
import 'backup_payload.dart';
import 'json_bytes.dart';

/// 把解密后的载荷 JSON 字节解码为 [BackupPayload]（FORMAT.md 第 5 节）。
///
/// - 未知的字段一律忽略（向前兼容）；
/// - `payload_version` 高于 [payloadVersion] → `BackupVersionUnsupportedFailure`；
/// - 不是 JSON、`format` 不对、缺少必需字段或类型不对 → `BackupCorruptedFailure`；
/// - 条目里的枚举写法不认识（如更新版本才有的链家族、派生方案、链 id）→ 跳过
///   该条目并记入 [BackupPayload.skipped]；设置项不认识时取默认值并记入。
///
/// 解析在字节上进行：密钥字段从字节直接复制进 [Sensitive]，不产生 `String`；
/// 解析树在返回前清零。失败时已创建的 [Sensitive] 全部清零，不返回任何部分内容。
abstract final class PayloadReader {
  /// [plaintext] 不被修改，由调用方清零。
  static Result<BackupPayload> decode(Uint8List plaintext) {
    final root = JsonBytes.parse(plaintext);
    if (root is! JsonObject) {
      root?.wipe();
      return const Err(BackupCorruptedFailure('payload_json'));
    }
    final ctx = _Reader();
    try {
      return _root(ctx, root);
    } on _Corrupt catch (e) {
      ctx.wipeSecrets();
      return Err(BackupCorruptedFailure(e.reason));
    } finally {
      root.wipe();
    }
  }

  static Result<BackupPayload> _root(_Reader r, JsonObject json) {
    if (r.strOrNull(json['format']) != payloadFormatId) {
      throw const _Corrupt('payload_format');
    }
    final version = r.integer(json['payload_version'], 'payload_version');
    if (version < 1) throw const _Corrupt('payload_version');
    if (version > payloadVersion) {
      return Err(BackupVersionUnsupportedFailure('payload_$version'));
    }
    final accounts = [
      for (final n in r.array(json['accounts'], 'accounts'))
        ?_account(r, r.object(n, 'account')),
    ];
    final addresses = [
      for (final n in r.array(json['addresses'], 'addresses'))
        ?_address(r, r.object(n, 'address')),
    ];
    final items = [
      for (final n in r.array(json['vault_items'], 'vault_items'))
        ?_vaultItem(r, r.object(n, 'vault_item')),
    ];
    final settings = _settings(r, r.object(json['settings'], 'settings'));
    final rawCredentials = json['exchange_credentials'];
    final credentials = rawCredentials == null || rawCredentials is JsonNull
        ? null
        : [
            for (final n in r.array(rawCredentials, 'exchange_credentials'))
              _credential(r, r.object(n, 'exchange_credential')),
          ];
    return Ok(
      BackupPayload(
        exportedAt: r.time(json['exported_at'], 'exported_at'),
        accounts: accounts,
        addresses: addresses,
        vaultItems: items,
        settings: settings,
        exchangeCredentials: credentials,
        skipped: r.skipped,
      ),
    );
  }

  static Account? _account(_Reader r, JsonObject j) {
    final id = r.str(j['id'], 'account.id');
    final type = r.enumOf(AccountType.values, accountTypeName, j['type']);
    final source = r.enumOrNull(
      WalletSource.values,
      walletSourceName,
      j['wallet_source'],
    );
    final exchange = r.enumOrNull(
      ExchangeId.values,
      exchangeIdName,
      j['exchange'],
    );
    final backup = r.object(j['backup'], 'account.backup');
    final account = Account(
      id: id,
      type: type ?? AccountType.wallet,
      name: r.str(j['name'], 'account.name'),
      colorIndex: r.integer(j['color_index'], 'account.color_index'),
      note: r.str(j['note'], 'account.note'),
      walletSource: source?.value,
      exchange: exchange?.value,
      vaultItemId: r.strOrNull(j['vault_item_id']),
      backup: BackupStatus(
        offlineBackedUp: r.boolean(backup['offline_backed_up'], 'backup'),
        offlineVerifiedAt: r.timeOrNull(backup['offline_verified_at']),
        keyless: r.boolean(backup['keyless'], 'backup'),
      ),
      createdAt: r.time(j['created_at'], 'account.created_at'),
    );
    if (type == null || source == null || exchange == null) {
      return r.skip(BackupSection.account, id);
    }
    return account;
  }

  static WatchAddress? _address(_Reader r, JsonObject j) {
    final id = r.str(j['id'], 'address.id');
    final family = r.enumOf(ChainFamily.values, chainFamilyName, j['family']);
    final scheme = r.enumOrNull(
      DerivationScheme.values,
      derivationSchemeName,
      j['scheme'],
    );
    final chains = [
      for (final n in r.array(j['enabled_chains'], 'address.enabled_chains'))
        r.str(n, 'address.enabled_chains'),
    ];
    final address = WatchAddress(
      id: id,
      accountId: r.str(j['account_id'], 'address.account_id'),
      family: family ?? ChainFamily.evm,
      address: r.str(j['address'], 'address.address'),
      enabledChainIds: chains.toSet(),
      scheme: scheme?.value,
      derivationIndex: r.intOrNull(j['derivation_index']),
      note: r.str(j['note'], 'address.note'),
    );
    if (family == null ||
        scheme == null ||
        chains.any((c) => Chains.tryById(c) == null)) {
      return r.skip(BackupSection.address, id);
    }
    return address;
  }

  static BackupVaultItem? _vaultItem(_Reader r, JsonObject j) {
    final id = r.str(j['id'], 'vault_item.id');
    if (!VaultFile.itemIdPattern.hasMatch(id)) {
      throw const _Corrupt('vault_item.id');
    }
    final name = r.str(j['name'], 'vault_item.name');
    final createdAt = r.time(j['created_at'], 'vault_item.created_at');
    final kind = r.enumOf(VaultItemKind.values, itemKindName, j['kind']);
    final hex = r.isHex(j);
    final VaultItemSecret secret;
    switch (kind) {
      case null:
        return r.skip(BackupSection.vaultItem, id);
      case VaultItemKind.mnemonic:
        secret = MnemonicSecret(
          mnemonic: r.secret(j['mnemonic'], hex, 'mnemonic'),
          passphrase: r.secretOrNull(j['passphrase'], hex),
        );
      case VaultItemKind.privateKey:
        final family = r.enumOf(
          ChainFamily.values,
          chainFamilyName,
          j['family'],
        );
        if (family == null) return r.skip(BackupSection.vaultItem, id);
        secret = PrivateKeySecret(
          family: family,
          key: r.secret(j['private_key'], hex, 'private_key'),
        );
    }
    if (ItemCodec.invalidReason(secret) != null) {
      throw const _Corrupt('vault_item.secret');
    }
    return BackupVaultItem(
      id: id,
      name: name,
      createdAt: createdAt,
      secret: secret,
    );
  }

  static BackupSettings _settings(_Reader r, JsonObject j) {
    const d = BackupSettings();
    T pick<T>(List<T> values, String Function(T) nameOf, String key, T def) {
      final v = r.enumOf(values, nameOf, j[key]);
      if (v == null) r.skip(BackupSection.setting, key);
      return v ?? def;
    }

    return BackupSettings(
      quote: pick(Quote.values, quoteName, 'quote', d.quote),
      hideSmall: r.boolean(j['hide_small'], 'settings.hide_small'),
      theme: pick(ThemePreference.values, themeName, 'theme', d.theme),
      autoLock: pick(AutoLock.values, autoLockName, 'auto_lock', d.autoLock),
    );
  }

  static BackupExchangeCredential _credential(_Reader r, JsonObject j) {
    final accountId = r.str(j['account_id'], 'exchange_credential.account_id');
    final hex = r.isHex(j);
    return BackupExchangeCredential(
      accountId: accountId,
      credentials: ExchangeCredentials(
        apiKey: r.secret(j['api_key'], hex, 'api_key'),
        apiSecret: r.secret(j['api_secret'], hex, 'api_secret'),
        passphrase: r.secretOrNull(j['passphrase'], hex),
      ),
    );
  }
}

/// 结构不合法。[reason] 是固定的原因标记，不含内容。
final class _Corrupt implements Exception {
  const _Corrupt(this.reason);

  final String reason;
}

/// 可空枚举字段的读取结果：外层为 null 表示写法不认识，[value] 为 null 表示字段为空。
typedef _Maybe<T> = ({T? value});

/// 读取各类字段；记录被跳过的条目与已创建的 [Sensitive]（失败时清零）。
final class _Reader {
  final skipped = <BackupSkipped>[];
  final _secrets = <Sensitive>[];

  void wipeSecrets() {
    for (final s in _secrets) {
      s.wipe();
    }
  }

  /// 记一条跳过；返回 null 以便调用方直接 `return r.skip(...)`。
  Null skip(BackupSection section, String id) {
    skipped.add(BackupSkipped(section, id));
  }

  static bool _absent(JsonNode? n) => n == null || n is JsonNull;

  JsonObject object(JsonNode? n, String field) =>
      n is JsonObject ? n : throw _Corrupt(field);

  List<JsonNode> array(JsonNode? n, String field) =>
      n is JsonArray ? n.items : throw _Corrupt(field);

  String str(JsonNode? n, String field) =>
      n is JsonString ? n.text : throw _Corrupt(field);

  String? strOrNull(JsonNode? n) => n is JsonString ? n.text : null;

  int integer(JsonNode? n, String field) =>
      (n is JsonNumber ? n.asInt : null) ?? (throw _Corrupt(field));

  int? intOrNull(JsonNode? n) =>
      _absent(n) ? null : integer(n, 'derivation_index');

  bool boolean(JsonNode? n, String field) =>
      n is JsonBool ? n.value : throw _Corrupt(field);

  DateTime time(JsonNode? n, String field) =>
      (n is JsonString ? parseTimestamp(n.text) : null) ??
      (throw _Corrupt(field));

  DateTime? timeOrNull(JsonNode? n) => _absent(n) ? null : time(n, 'time');

  /// 必需的枚举字段：类型不对 → 损坏；写法不认识 → null。
  T? enumOf<T>(List<T> values, String Function(T) nameOf, JsonNode? n) =>
      enumByName(values, nameOf, str(n, 'enum'));

  /// 可空的枚举字段：缺失或 null → `(value: null)`；写法不认识 → null。
  _Maybe<T>? enumOrNull<T>(
    List<T> values,
    String Function(T) nameOf,
    JsonNode? n,
  ) {
    if (_absent(n)) return (value: null);
    final v = enumOf(values, nameOf, n);
    return v == null ? null : (value: v);
  }

  /// 对象的 `encoding` 字段：缺失为文本形式，`"hex"` 为十六进制，其余视为损坏。
  bool isHex(JsonObject j) {
    final n = j['encoding'];
    if (_absent(n)) return false;
    if (strOrNull(n) == hexEncoding) return true;
    throw const _Corrupt('encoding');
  }

  Sensitive secret(JsonNode? n, bool hex, String field) {
    if (n is! JsonString) throw _Corrupt(field);
    final bytes = hex ? _unhex(n.bytes) : Uint8List.fromList(n.bytes);
    if (bytes == null) throw _Corrupt(field);
    final s = Sensitive(bytes);
    _secrets.add(s);
    return s;
  }

  Sensitive? secretOrNull(JsonNode? n, bool hex) =>
      _absent(n) ? null : secret(n, hex, 'passphrase');

  /// 十六进制（大小写均可）解码；不合法返回 null 并清零已写入的部分。
  static Uint8List? _unhex(Uint8List text) {
    if (text.length.isOdd) return null;
    final out = Uint8List(text.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      final hi = _nibble(text[2 * i]);
      final lo = _nibble(text[2 * i + 1]);
      if (hi < 0 || lo < 0) {
        out.fillRange(0, out.length, 0);
        return null;
      }
      out[i] = hi << 4 | lo;
    }
    return out;
  }

  static int _nibble(int c) => c >= 0x30 && c <= 0x39
      ? c - 0x30
      : c >= 0x61 && c <= 0x66
      ? c - 0x57
      : c >= 0x41 && c <= 0x46
      ? c - 0x37
      : -1;
}
