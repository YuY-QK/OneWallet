import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

void main() {
  group('tokenKey', () {
    test('原生币_链id加native', () {
      expect(const NativeToken('ethereum').tokenKey, 'ethereum:native');
      expect(const NativeToken('bitcoin').tokenKey, 'bitcoin:native');
    });

    test('合约代币_链id加合约原样', () {
      const c = '0xdac17f958d2ee523a2206206994597c13d831ec7';
      expect(const ContractToken('ethereum', c).tokenKey, 'ethereum:$c');
    });

    test('合约代币_不改动大小写_区分大小写的链不被破坏', () {
      expect(
        const ContractToken('solana', 'EPjFWdd5Aufq').tokenKey,
        'solana:EPjFWdd5Aufq',
      );
    });

    test('交易所币种_枚举名加大写符号', () {
      expect(const ExchangeToken(ExchangeId.okx, 'usdt').tokenKey, 'okx:USDT');
      expect(
        const ExchangeToken(ExchangeId.binance, 'BTC').tokenKey,
        'binance:BTC',
      );
    });

    test('不同形态_键互不相同', () {
      final keys = {
        const NativeToken('ethereum').tokenKey,
        const ContractToken('ethereum', '0xabc').tokenKey,
        const ExchangeToken(ExchangeId.bybit, 'ETH').tokenKey,
      };
      expect(keys.length, 3);
    });
  });
}
