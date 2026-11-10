import 'dart:convert';
import 'dart:io';

import 'package:ow_domain/ow_domain.dart';
import 'package:ow_vault/ow_vault.dart';
import 'package:test/test.dart';

/// 与另一套独立实现（Python bip_utils）逐地址对照。
///
/// 样本由 test/fixtures/generate_vectors.py 生成，只包含公开的测试助记词。
void main() {
  final file = File('test/fixtures/derivation_vectors.json');
  final data = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  final cases = (data['cases']! as List<Object?>).cast<Map<String, Object?>>();

  for (final c in cases) {
    final seed = AddressDeriver.seedFromMnemonic(
      c['mnemonic']! as String,
      passphrase: c['passphrase']! as String,
    ).valueOrNull!;
    final addresses = c['addresses']! as Map<String, Object?>;

    for (final scheme in DerivationScheme.values) {
      test('${c['name']}_${scheme.name}_前5个地址与独立实现一致', () {
        final expected = (addresses[scheme.name]! as List<Object?>)
            .cast<String>();
        final actual = [
          for (var i = 0; i < expected.length; i++)
            AddressDeriver.deriveAddress(seed: seed, scheme: scheme, index: i),
        ];
        expect(actual, expected);
      });
    }
  }

  test('样本覆盖了全部派生方案', () {
    final addresses = cases.first['addresses']! as Map<String, Object?>;
    expect(
      addresses.keys.toSet(),
      DerivationScheme.values.map((s) => s.name).toSet(),
    );
  });
}
