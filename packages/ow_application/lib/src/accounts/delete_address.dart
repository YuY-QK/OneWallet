import 'package:ow_domain/ow_domain.dart';

/// 删除账户下的一个观察地址（P07）。
///
/// 账户至少保留一个地址：只剩一个时返回 [ValidationFailure]，不删除。
/// 删除地址时由 `AddressRepository.delete` 同一事务内清掉该地址的持仓。
/// 不触发同步：是否重新同步该账户（让汇总立即反映删除）由调用方决定。
final class DeleteAddress {
  const DeleteAddress({required this._addresses});

  final AddressRepository _addresses;

  /// 删除 [addressId]。
  ///
  /// 地址不存在时什么也不做，返回 `Ok`（幂等）。该地址所属账户只有这一个地址时，
  /// 返回 [ValidationFailure] 且不改动任何数据。
  Future<Result<void>> call(String addressId) async {
    final all = await _addresses.watchAll().first;
    final target = all.where((a) => a.id == addressId).firstOrNull;
    if (target == null) return const Ok(null);
    final siblings = await _addresses.byAccount(target.accountId);
    if (siblings.length <= 1) {
      return const Err(ValidationFailure('账户至少保留一个地址'));
    }
    await _addresses.delete(addressId);
    return const Ok(null);
  }
}
