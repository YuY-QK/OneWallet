import 'package:ow_domain/ow_domain.dart';

import 'address_input.dart';

/// 通过校验、待写入的一个地址。
typedef ValidatedAddress = ({
  ChainFamily family,
  String address,
  Set<String> chainIds,
});

/// `AddWalletAccount` 与 `AddAddressesToAccount` 共用的地址校验与查重（R1–R4）。
///
/// 包内使用，不导出。
final class AddressValidation {
  const AddressValidation({
    required this._codec,
    required this._addresses,
    required this._accounts,
  });

  final AddressCodec _codec;
  final AddressRepository _addresses;
  final AccountRepository _accounts;

  /// 校验 [inputs]，全部通过时返回规范化后的地址。
  ///
  /// 失败时：列表为空、家族无法识别、地址不合法、链选择无效返回
  /// [ValidationFailure]（detail 注明序号，只用于调试）；与库中已有地址或
  /// 本次输入内部重复返回 [DuplicateAddressFailure]。遇到第一个问题即返回。
  Future<Result<List<ValidatedAddress>>> call(List<AddressInput> inputs) async {
    if (inputs.isEmpty) {
      return const Err(ValidationFailure('至少需要一个地址'));
    }
    final result = <ValidatedAddress>[];
    final seen = <(ChainFamily, String)>{};
    for (var i = 0; i < inputs.length; i++) {
      final ValidatedAddress v;
      switch (_checkFormat(inputs[i], i)) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          v = value;
      }
      if (!seen.add((v.family, v.address))) {
        return Err(
          DuplicateAddressFailure(
            shortAddress: AddressCodec.shorten(v.address),
          ),
        );
      }
      final existing = await _addresses.find(v.family, v.address);
      if (existing != null) {
        final owner = await _accounts.byId(existing.accountId);
        return Err(
          DuplicateAddressFailure(
            shortAddress: AddressCodec.shorten(v.address),
            // 地址存在而账户不存在属于数据异常；仍按"已在库中"提示，账户名留空。
            existingAccountName: owner?.name ?? '',
          ),
        );
      }
      result.add(v);
    }
    return Ok(result);
  }

  Result<ValidatedAddress> _checkFormat(AddressInput input, int index) {
    final family = input.family ?? AddressCodec.detectFamily(input.raw);
    if (family == null) {
      return Err(ValidationFailure('addresses[$index]: 无法识别的地址格式'));
    }
    if (!_codec.isValid(input.raw, family)) {
      return Err(ValidationFailure('addresses[$index]: 地址不合法'));
    }
    final familyChains = {for (final c in Chains.ofFamily(family)) c.id};
    final chainIds = input.chainIds ?? familyChains;
    if (chainIds.isEmpty || !familyChains.containsAll(chainIds)) {
      return Err(ValidationFailure('addresses[$index]: 链选择无效'));
    }
    return Ok((
      family: family,
      address: AddressCodec.normalize(input.raw, family),
      chainIds: chainIds,
    ));
  }
}
