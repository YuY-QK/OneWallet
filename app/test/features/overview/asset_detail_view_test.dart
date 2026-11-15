import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/features/overview/controllers/asset_detail_view.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:ow_pricing/ow_pricing.dart';

Decimal d(String s) => Decimal.parse(s);

void main() {
  final catalog = BuiltInAssetCatalog();
  final now = DateTime.utc(2026, 11, 15);

  final wallet1 = Account.wallet(
    id: 'w1',
    name: '小狐狸主号',
    colorIndex: 0,
    createdAt: now,
  );
  final wallet2 = Account.wallet(
    id: 'w2',
    name: 'Uni 钱包',
    colorIndex: 1,
    createdAt: now,
  );
  final exchange1 = Account.exchange(
    id: 'e1',
    name: 'Binance 主账户',
    colorIndex: 2,
    createdAt: now,
    exchange: ExchangeId.binance,
  );

  final accounts = <Account>[wallet1, wallet2, exchange1];

  group('buildAssetDetail', () {
    test('正常计算：跨钱包与交易所汇总总量、估值、占比与合约', () {
      final holdings = [
        Holding(
          accountId: 'e1',
          location: const ExchangeLocation(ExchangeSubAccount.spot),
          token: const ExchangeToken(ExchangeId.binance, 'USDT'),
          assetId: 'USDT',
          displaySymbol: 'USDT',
          amount: d('8000'),
          updatedAt: now,
        ),
        Holding(
          accountId: 'w1',
          location: const OnChainLocation(
            addressId: 'addr1',
            chainId: 'ethereum',
          ),
          token: const ContractToken(
            'ethereum',
            '0xdac17f958d2ee523a2206206994597c13d831ec7',
          ),
          assetId: 'USDT',
          displaySymbol: 'USDT',
          amount: d('2000'),
          updatedAt: now,
        ),
        Holding(
          accountId: 'w2',
          location: const OnChainLocation(
            addressId: 'addr2',
            chainId: 'arbitrum',
          ),
          token: const ContractToken(
            'arbitrum',
            '0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9',
          ),
          assetId: 'USDT',
          displaySymbol: 'USDT',
          amount: d('2000'),
          updatedAt: now,
        ),
      ];

      final prices = <String, Price>{
        'USDT': Price(
          assetId: 'USDT',
          quote: Quote.usd,
          price: d('1.0002'),
          change24hPercent: d('0.01'),
          updatedAt: now,
        ),
      };

      final view = buildAssetDetail(
        assetId: 'USDT',
        catalog: catalog,
        accounts: accounts,
        holdings: holdings,
        prices: prices,
        builtInContracts: catalog.contracts,
      );

      expect(view.assetId, 'USDT');
      expect(view.symbol, 'USDT');
      expect(view.name, 'Tether USD');
      expect(view.price?.price, d('1.0002'));
      expect(view.price?.change24hPercent, d('0.01'));
      expect(view.totalAmount, d('12000'));
      expect(view.totalValue, d('12002.40')); // 12000 * 1.0002

      expect(view.distributions.length, 3);
      // 第一行：Binance 现货 8000 (66.67%)
      expect(view.distributions[0].account.name, 'Binance 主账户');
      expect(view.distributions[0].amount, d('8000'));
      expect(view.distributions[0].value, d('8001.60'));
      expect(
        view.distributions[0].share.toStringAsFixed(1),
        '66.7',
      ); // 8001.60 / 12002.40 * 100

      // 合约列表包含 Ethereum, Arbitrum 等
      expect(view.contracts, isNotEmpty);
      expect(view.contracts.any((c) => c.chainId == 'ethereum'), isTrue);
      expect(view.contracts.any((c) => c.chainId == 'tron'), isTrue);
    });

    test('未定价币种：估值为 null，分布项估值也为 null', () {
      final holdings = [
        Holding(
          accountId: 'w1',
          location: const OnChainLocation(
            addressId: 'addr1',
            chainId: 'ethereum',
          ),
          token: const ContractToken(
            'ethereum',
            '0x1111111111111111111111111111111111111111',
          ),
          assetId: 'MYTOKEN',
          displaySymbol: 'MYT',
          amount: d('500'),
          updatedAt: now,
        ),
      ];

      final view = buildAssetDetail(
        assetId: 'MYTOKEN',
        catalog: catalog,
        accounts: accounts,
        holdings: holdings,
        prices: const {},
      );

      expect(view.assetId, 'MYTOKEN');
      expect(view.symbol, 'MYT');
      expect(view.price, isNull);
      expect(view.totalAmount, d('500'));
      expect(view.totalValue, isNull);
      expect(view.distributions.length, 1);
      expect(view.distributions[0].value, isNull);
      expect(view.distributions[0].share, Decimal.zero);
      expect(view.contracts.length, 1);
      expect(view.contracts[0].chainId, 'ethereum');
    });

    test('隐藏代币被过滤', () {
      final token = const ContractToken(
        'ethereum',
        '0xdac17f958d2ee523a2206206994597c13d831ec7',
      );
      final holdings = [
        Holding(
          accountId: 'w1',
          location: const OnChainLocation(
            addressId: 'addr1',
            chainId: 'ethereum',
          ),
          token: token,
          assetId: 'USDT',
          displaySymbol: 'USDT',
          amount: d('100'),
          updatedAt: now,
        ),
      ];

      final view = buildAssetDetail(
        assetId: 'USDT',
        catalog: catalog,
        accounts: accounts,
        holdings: holdings,
        prices: const {},
        hiddenTokens: {token.tokenKey},
      );

      expect(view.totalAmount, Decimal.zero);
      expect(view.distributions, isEmpty);
    });
  });
}
