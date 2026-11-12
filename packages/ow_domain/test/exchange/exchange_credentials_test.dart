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

  test('ExchangeCredentials_未提供passphrase_为null', () {
    final c = ExchangeCredentials(apiKey: fake('k'), apiSecret: fake('s'));
    expect(c.passphrase, isNull);
    expect(c.apiKey.use((b) => b.length), 1);
    expect(c.apiSecret.isWiped, isFalse);
  });

  group('DepositAddress', () {
    // 充值地址为明显的构造样例。
    const base = DepositAddress(
      symbol: 'USDT',
      network: 'TRC20',
      address: 'T-fake-address',
    );

    test('DepositAddress_字段相同_相等且哈希相同', () {
      const same = DepositAddress(
        symbol: 'USDT',
        network: 'TRC20',
        address: 'T-fake-address',
      );
      expect(same, base);
      expect(same.hashCode, base.hashCode);
    });

    test('DepositAddress_任一字段不同_不相等', () {
      expect(
        const DepositAddress(
          symbol: 'USDC',
          network: 'TRC20',
          address: 'T-fake-address',
        ),
        isNot(base),
      );
      expect(
        const DepositAddress(
          symbol: 'USDT',
          network: 'ERC20',
          address: 'T-fake-address',
        ),
        isNot(base),
      );
      expect(
        const DepositAddress(
          symbol: 'USDT',
          network: 'TRC20',
          address: 'T-other-address',
        ),
        isNot(base),
      );
    });

    test('DepositAddress_备注有无_不相等', () {
      const withMemo = DepositAddress(
        symbol: 'USDT',
        network: 'TRC20',
        address: 'T-fake-address',
        memo: '12345',
      );
      expect(withMemo.memo, '12345');
      expect(base.memo, isNull);
      expect(withMemo, isNot(base));
    });

    test('toString_含币种与网络', () {
      expect(base.toString(), 'DepositAddress(USDT, TRC20)');
    });
  });

  group('CredentialCheck 与 KeyPermission', () {
    test('KeyPermission_枚举值_与规格的四种权限一致', () {
      expect(KeyPermission.values, [
        KeyPermission.readOnly,
        KeyPermission.canTrade,
        KeyPermission.canWithdraw,
        KeyPermission.unknown,
      ]);
    });

    test('CredentialCheck_权限相同_相等且哈希相同', () {
      const a = CredentialCheck(permission: KeyPermission.readOnly);
      const b = CredentialCheck(permission: KeyPermission.readOnly);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('CredentialCheck_权限不同_不相等', () {
      const a = CredentialCheck(permission: KeyPermission.readOnly);
      const b = CredentialCheck(permission: KeyPermission.canWithdraw);
      expect(a, isNot(b));
    });

    test('toString_含权限名', () {
      const a = CredentialCheck(permission: KeyPermission.canTrade);
      expect(a.toString(), 'CredentialCheck(canTrade)');
    });
  });
}
