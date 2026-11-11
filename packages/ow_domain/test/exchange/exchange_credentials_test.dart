import 'dart:typed_data';

import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

Sensitive fake(String s) => Sensitive(Uint8List.fromList(s.codeUnits));

void main() {
  test('ExchangeCredentials_toString_不泄露内容', () {
    // 明显的构造假数据，不是真实凭据。
    final c = ExchangeCredentials(
      apiKey: fake('fake-key'),
      apiSecret: fake('fake-secret'),
      passphrase: fake('fake-pass'),
    );
    expect('$c', isNot(contains('fake')));
  });

  test('ExchangeCredentials_内容相同的两份_不按内容相等', () {
    final a = ExchangeCredentials(apiKey: fake('k'), apiSecret: fake('s'));
    final b = ExchangeCredentials(apiKey: fake('k'), apiSecret: fake('s'));
    expect(a == b, isFalse);
  });
}
