import 'package:ow_domain/ow_domain.dart';

/// 更新地址备注（PRD P10）。
///
/// 校验备注长度（首尾去除空白后不超过 100 字符）与地址存在性，
/// 通过 [AddressRepository.upsert] 更新地址备注并返回更新后的 [WatchAddress]。
final class UpdateAddressNote {
  const UpdateAddressNote({required this.addresses});

  final AddressRepository addresses;

  Future<Result<WatchAddress>> call({
    required String addressId,
    required String note,
  }) async {
    final trimmed = note.trim();
    if (trimmed.runes.length > 100) {
      return const Err(ValidationFailure('备注长度不能超过 100 个字符'));
    }

    final current = await addresses.byId(addressId);
    if (current == null) {
      return const Err(ValidationFailure('地址不存在'));
    }

    final updated = current.copyWith(note: trimmed);
    await addresses.upsert(updated);
    return Ok(updated);
  }
}
