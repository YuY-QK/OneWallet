import 'package:decimal/decimal.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

RawHolding raw({
  TokenRef token = const NativeToken('ethereum'),
  String amount = '1.5',
  String? symbolHint = 'ETH',
  String? nameHint = 'Ether',
}) => RawHolding(
  token: token,
  amount: Decimal.parse(amount),
  symbolHint: symbolHint,
  nameHint: nameHint,
);

Holding holding({
  String accountId = 'acc-1',
  HoldingLocation location = const OnChainLocation(
    chainId: 'ethereum',
    addressId: 'addr-1',
  ),
  TokenRef token = const NativeToken('ethereum'),
  String? assetId = 'ETH',
  String displaySymbol = 'ETH',
  String amount = '1.5',
  DateTime? updatedAt,
}) => Holding(
  accountId: accountId,
  location: location,
  token: token,
  assetId: assetId,
  displaySymbol: displaySymbol,
  amount: Decimal.parse(amount),
  updatedAt: updatedAt ?? DateTime.utc(2026, 1, 2),
);

void main() {
  group('RawHolding', () {
    test('RawHolding_构造后_字段可读', () {
      const contract = '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      final r = raw(token: const ContractToken('bsc', contract));
      expect(r.token, const ContractToken('bsc', contract));
      expect(r.amount, Decimal.parse('1.5'));
      expect(r.symbolHint, 'ETH');
      expect(r.nameHint, 'Ether');
    });

    test('RawHolding_提示字段可省略_为null', () {
      final r = RawHolding(
        token: const NativeToken('base'),
        amount: Decimal.one,
      );
      expect(r.symbolHint, isNull);
      expect(r.nameHint, isNull);
    });

    test('RawHolding_字段相同_相等且哈希相同', () {
      expect(raw(), raw());
      expect(raw().hashCode, raw().hashCode);
    });

    test('RawHolding_金额换算精度不同但数值相同_相等', () {
      expect(raw(amount: '1.50'), raw(amount: '1.5'));
    });

    test('RawHolding_任一字段不同_不相等', () {
      final base = raw();
      expect(raw(token: const NativeToken('base')), isNot(base));
      expect(raw(amount: '2'), isNot(base));
      expect(raw(symbolHint: 'WETH'), isNot(base));
      expect(raw(symbolHint: null), isNot(base));
      expect(raw(nameHint: 'Wrapped'), isNot(base));
      expect(raw(nameHint: null), isNot(base));
    });

    test('RawHolding_toString_含代币与数量', () {
      expect(raw().toString(), 'RawHolding(NativeToken(ethereum), 1.5)');
    });
  });

  group('Holding', () {
    test('Holding_构造后_字段可读', () {
      final h = holding();
      expect(h.accountId, 'acc-1');
      expect(
        h.location,
        const OnChainLocation(chainId: 'ethereum', addressId: 'addr-1'),
      );
      expect(h.token, const NativeToken('ethereum'));
      expect(h.assetId, 'ETH');
      expect(h.displaySymbol, 'ETH');
      expect(h.amount, Decimal.parse('1.5'));
      expect(h.updatedAt, DateTime.utc(2026, 1, 2));
    });

    test('Holding_未识别代币_assetId为null', () {
      expect(holding(assetId: null).assetId, isNull);
    });

    test('Holding_字段相同_相等且哈希相同', () {
      final a = holding();
      final b = holding();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('Holding_交易所位置_可与链上位置区分', () {
      final onChain = holding();
      final exchange = holding(
        location: const ExchangeLocation(ExchangeSubAccount.spot),
      );
      expect(exchange, isNot(onChain));
    });

    test('Holding_任一字段不同_不相等', () {
      final base = holding();
      expect(holding(accountId: 'acc-2'), isNot(base));
      expect(
        holding(
          location: const OnChainLocation(chainId: 'base', addressId: 'addr-1'),
        ),
        isNot(base),
      );
      expect(
        holding(token: const ContractToken('ethereum', '0xabc')),
        isNot(base),
      );
      expect(holding(assetId: 'WETH'), isNot(base));
      expect(holding(assetId: null), isNot(base));
      expect(holding(displaySymbol: 'WETH'), isNot(base));
      expect(holding(amount: '2'), isNot(base));
      expect(holding(updatedAt: DateTime.utc(2026, 1, 3)), isNot(base));
    });

    test('Holding_toString_含账户位置代币与数量', () {
      expect(
        holding().toString(),
        'Holding(acc-1, OnChainLocation(ethereum, addr-1), '
        'NativeToken(ethereum), 1.5)',
      );
    });
  });
}
