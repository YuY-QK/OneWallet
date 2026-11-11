import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

void main() {
  const usdtEth = '0xdac17f958d2ee523a2206206994597c13d831ec7';

  group('TokenRef 相等与哈希', () {
    test('NativeToken_同链_相等且哈希相同', () {
      const a = NativeToken('ethereum');
      // 非 const 构造，确保比较的是值而不是同一实例。
      final b = NativeToken('ethereum'.toString());
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const NativeToken('base')));
    });

    test('ContractToken_同链同合约_相等且哈希相同', () {
      const a = ContractToken('ethereum', usdtEth);
      final b = ContractToken('ethereum', usdtEth.toString());
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('ContractToken_合约相同链不同_不相等', () {
      expect(
        const ContractToken('ethereum', usdtEth),
        isNot(const ContractToken('arbitrum', usdtEth)),
      );
    });

    test('ContractToken_合约大小写不同_不相等_调用方须先规范化', () {
      expect(
        const ContractToken('ethereum', usdtEth),
        isNot(ContractToken('ethereum', usdtEth.toUpperCase())),
      );
    });

    test('ExchangeToken_同交易所同符号_相等_不同交易所不相等', () {
      const a = ExchangeToken(ExchangeId.binance, 'USDT');
      expect(a, ExchangeToken(ExchangeId.binance, 'USDT'.toString()));
      expect(
        a.hashCode,
        const ExchangeToken(ExchangeId.binance, 'USDT').hashCode,
      );
      expect(a, isNot(const ExchangeToken(ExchangeId.okx, 'USDT')));
    });

    test('TokenRef_不同子类字段相同_不相等', () {
      expect(
        const NativeToken('ethereum'),
        isNot(const ContractToken('ethereum', 'ethereum')),
      );
    });

    test('TokenRef_作为Map键_按值查找与去重', () {
      final map = <TokenRef, int>{
        const NativeToken('ethereum'): 1,
        const ContractToken('ethereum', usdtEth): 2,
        const ExchangeToken(ExchangeId.bybit, 'BTC'): 3,
      };
      expect(map[NativeToken('ethereum'.toString())], 1);
      expect(map[ContractToken('ethereum', usdtEth.toString())], 2);
      expect(map[ExchangeToken(ExchangeId.bybit, 'BTC'.toString())], 3);

      map[ContractToken('ethereum', usdtEth.toString())] = 4;
      expect(map, hasLength(3));
      expect(map[const ContractToken('ethereum', usdtEth)], 4);
    });
  });

  group('HoldingLocation 相等', () {
    test('HoldingLocation_字段相同_相等', () {
      expect(
        const OnChainLocation(chainId: 'base', addressId: 'a1'),
        OnChainLocation(chainId: 'base', addressId: 'a1'.toString()),
      );
      expect(
        const ExchangeLocation(ExchangeSubAccount.spot),
        isNot(const ExchangeLocation(ExchangeSubAccount.funding)),
      );
    });
  });
}
