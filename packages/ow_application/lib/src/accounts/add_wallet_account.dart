import 'package:ow_domain/ow_domain.dart';

import 'address_input.dart';
import 'address_validation.dart';

/// 账户名称的最大长度（按 Unicode 码点计，R5、P05）。
const int maxAccountNameLength = 30;

/// 头像色的数量（设计规范中的 8 种）。
const int accountColorCount = 8;

/// 通过观察地址创建钱包账户（P05、R1–R5）。
///
/// 只写入账户与地址，**不触发同步**：是否以及何时同步由调用方决定
/// （P05 保存后由控制器调用 `SyncAccount`）。
final class AddWalletAccount {
  AddWalletAccount({
    required this._accounts,
    required this._addresses,
    required this._codec,
    required this._ids,
    required this._clock,
  });

  final AccountRepository _accounts;
  final AddressRepository _addresses;
  final IdGenerator _ids;
  final Clock _clock;
  final AddressCodec _codec;
  late final AddressValidation _validation = AddressValidation(
    codec: _codec,
    addresses: _addresses,
    accounts: _accounts,
  );

  /// 创建名为 [name] 的钱包账户并添加 [addresses]，返回新账户。
  ///
  /// [name] 去首尾空白后须为 1–30 字；[colorIndex] 为 null 时按已有账户数轮换。
  /// 失败时：名称、颜色、地址不合法返回 [ValidationFailure]；地址重复返回
  /// [DuplicateAddressFailure]（带所属账户名，本次输入内重复时为 null）。
  /// 失败时不写入任何数据。
  Future<Result<Account>> call({
    required String name,
    required List<AddressInput> addresses,
    WalletSource? walletSource,
    BackupStatus backup = const BackupStatus(),
    int? colorIndex,
    String note = '',
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
    final validated = await _validation(addresses);
    switch (validated) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final account = Account(
          id: _ids.newId(),
          type: AccountType.wallet,
          name: trimmed,
          colorIndex: colorIndex ?? await _nextColor(),
          note: note,
          walletSource: walletSource,
          backup: backup,
          createdAt: _clock.nowUtc(),
        );
        await _accounts.upsert(account);
        for (final v in value) {
          await _addresses.upsert(
            WatchAddress(
              id: _ids.newId(),
              accountId: account.id,
              family: v.family,
              address: v.address,
              enabledChainIds: v.chainIds,
            ),
          );
        }
        return Ok(account);
    }
  }

  Future<int> _nextColor() async =>
      (await _accounts.watchAll().first).length % accountColorCount;
}
