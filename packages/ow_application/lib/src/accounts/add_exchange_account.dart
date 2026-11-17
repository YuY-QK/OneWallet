import 'package:ow_domain/ow_domain.dart';

import 'add_wallet_account.dart';

/// 通过只读 API Key 添加交易所账户（P06、R6）。
///
/// 验证凭据有效性、写入账户与凭据存储，**不触发同步**：
/// 是否以及何时同步由调用方决定（P06 保存后由控制器调用 `SyncAccount`）。
final class AddExchangeAccount {
  AddExchangeAccount({
    required this._accounts,
    required this._credentials,
    required this._adapters,
    required this._ids,
    required this._clock,
  });

  final AccountRepository _accounts;
  final CredentialRepository _credentials;
  final AdapterRegistry _adapters;
  final IdGenerator _ids;
  final Clock _clock;

  /// 验证交易所 API Key 是否有效并返回权限检查结果。
  Future<Result<CredentialCheck>> verify({
    required ExchangeId exchange,
    required ExchangeCredentials credentials,
  }) async {
    final adapter = _adapters.exchange(exchange);
    return adapter.verify(credentials);
  }

  /// 创建名为 [name] 的交易所账户，保存凭据并返回新账户。
  ///
  /// [name] 去首尾空白后须为 1–30 字；[colorIndex] 为 null 时按已有账户数轮换。
  /// 校验 API Key 与 Secret 是否为空；需要 Passphrase 的交易所校验 Passphrase。
  /// [verifyCredentials] 为 true 时，先调用适配器的 [verify] 进行连通性与权限校验。
  Future<Result<Account>> call({
    required String name,
    required ExchangeId exchange,
    required ExchangeCredentials credentials,
    int? colorIndex,
    String note = '',
    bool verifyCredentials = true,
  }) async {
    final trimmed = name.trim();
    final length = trimmed.runes.length;
    if (length == 0 || length > maxAccountNameLength) {
      return const Err(ValidationFailure('名称须为 1–30 字'));
    }
    if (colorIndex != null &&
        (colorIndex < 0 || colorIndex >= accountColorCount)) {
      return const Err(ValidationFailure('颜色序号须为 0–7'));
    }

    final keyEmpty = credentials.apiKey.useString((s) => s.trim().isEmpty);
    if (keyEmpty) {
      return const Err(ValidationFailure('API Key 不能为空'));
    }

    final secretEmpty = credentials.apiSecret.useString(
      (s) => s.trim().isEmpty,
    );
    if (secretEmpty) {
      return const Err(ValidationFailure('API Secret 不能为空'));
    }

    final adapter = _adapters.exchange(exchange);
    if (adapter.needsPassphrase) {
      final pass = credentials.passphrase;
      final passEmpty = pass == null || pass.useString((s) => s.trim().isEmpty);
      if (passEmpty) {
        return const Err(ValidationFailure('Passphrase 不能为空'));
      }
    }

    if (verifyCredentials) {
      final checkResult = await adapter.verify(credentials);
      if (checkResult is Err<CredentialCheck>) {
        return Err(checkResult.failure);
      }
    }

    final account = Account.exchange(
      id: _ids.newId(),
      name: trimmed,
      colorIndex: colorIndex ?? await _nextColor(),
      createdAt: _clock.nowUtc(),
      exchange: exchange,
      note: note,
    );

    try {
      await _credentials.save(account.id, credentials);
      await _accounts.upsert(account);
      return Ok(account);
    } catch (e) {
      await _credentials.delete(account.id);
      rethrow;
    }
  }

  Future<int> _nextColor() async {
    final all = await _accounts.watchAll().first;
    return all.length % accountColorCount;
  }
}
