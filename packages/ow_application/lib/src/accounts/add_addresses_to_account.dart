import 'package:ow_domain/ow_domain.dart';

import 'address_input.dart';
import 'address_validation.dart';

/// 向已有钱包账户添加地址（从 P07 进入 P05，R1–R4）。
///
/// 只写入地址，**不触发同步**：由调用方决定是否随后调用 `SyncAccount`。
final class AddAddressesToAccount {
  AddAddressesToAccount({
    required this._accounts,
    required this._addresses,
    required this._codec,
    required this._ids,
  });

  final AccountRepository _accounts;
  final AddressRepository _addresses;
  final IdGenerator _ids;
  final AddressCodec _codec;
  late final AddressValidation _validation = AddressValidation(
    codec: _codec,
    addresses: _addresses,
    accounts: _accounts,
  );

  /// 把 [addresses] 加到 [accountId]，返回新写入的地址。
  ///
  /// 失败时：账户不存在或不是钱包账户、地址不合法返回 [ValidationFailure]；
  /// 地址重复（含已在本账户中）返回 [DuplicateAddressFailure]。
  /// 失败时不写入任何数据。
  Future<Result<List<WatchAddress>>> call({
    required String accountId,
    required List<AddressInput> addresses,
  }) async {
    final account = await _accounts.byId(accountId);
    if (account == null) {
      return const Err(ValidationFailure('账户不存在'));
    }
    if (account.type != AccountType.wallet) {
      return const Err(ValidationFailure('只有钱包账户可以添加地址'));
    }
    switch (await _validation(addresses)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final written = [
          for (final v in value)
            WatchAddress(
              id: _ids.newId(),
              accountId: accountId,
              family: v.family,
              address: v.address,
              enabledChainIds: v.chainIds,
            ),
        ];
        for (final a in written) {
          await _addresses.upsert(a);
        }
        return Ok(written);
    }
  }
}
