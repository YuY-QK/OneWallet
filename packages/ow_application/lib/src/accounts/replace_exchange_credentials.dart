import 'package:ow_domain/ow_domain.dart';

/// 更换现有交易所账户的 API 凭据（P08、P06 更换模式）。
final class ReplaceExchangeCredentials {
  ReplaceExchangeCredentials({
    required this._accounts,
    required this._credentials,
    required this._adapters,
  });

  final AccountRepository _accounts;
  final CredentialRepository _credentials;
  final AdapterRegistry _adapters;

  /// 验证交易所 API Key 是否有效并返回权限检查结果。
  Future<Result<CredentialCheck>> verify({
    required ExchangeId exchange,
    required ExchangeCredentials credentials,
  }) async {
    final adapter = _adapters.exchange(exchange);
    return adapter.verify(credentials);
  }

  /// 为现有账户 [accountId] 替换新凭据 [credentials]。
  Future<Result<void>> call({
    required String accountId,
    required ExchangeCredentials credentials,
    bool verifyCredentials = true,
  }) async {
    final account = await _accounts.byId(accountId);
    if (account == null) {
      return const Err(ValidationFailure('账户不存在'));
    }
    if (account.type != AccountType.exchange || account.exchange == null) {
      return const Err(ValidationFailure('该账户不是交易所账户'));
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

    final adapter = _adapters.exchange(account.exchange!);
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

    await _credentials.save(accountId, credentials);
    return const Ok(null);
  }
}
