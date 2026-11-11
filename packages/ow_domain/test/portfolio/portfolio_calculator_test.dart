import 'package:decimal/decimal.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

Decimal d(String s) => Decimal.parse(s);

final t0 = DateTime.utc(2026, 1, 1);

Account wallet(String id, [String? name]) => Account(
  id: id,
  type: AccountType.wallet,
  name: name ?? id,
  colorIndex: 0,
  createdAt: t0,
);

Account exch(String id, [String? name]) => Account(
  id: id,
  type: AccountType.exchange,
  name: name ?? id,
  colorIndex: 1,
  createdAt: t0,
  exchange: ExchangeId.binance,
);

Holding onChain(
  String account,
  String chain,
  String amount, {
  String? assetId,
  String? symbol,
  TokenRef? token,
  String address = 'addr1',
}) => Holding(
  accountId: account,
  location: OnChainLocation(chainId: chain, addressId: address),
  token: token ?? NativeToken(chain),
  assetId: assetId,
  displaySymbol: symbol ?? assetId ?? '?',
  amount: d(amount),
  updatedAt: t0,
);

Holding onExchange(
  String account,
  String symbol,
  String amount, {
  ExchangeSubAccount sub = ExchangeSubAccount.spot,
}) => Holding(
  accountId: account,
  location: ExchangeLocation(sub),
  token: ExchangeToken(ExchangeId.binance, symbol),
  assetId: symbol,
  displaySymbol: symbol,
  amount: d(amount),
  updatedAt: t0,
);

Price price(String assetId, String p, {String? pct}) => Price(
  assetId: assetId,
  quote: Quote.usd,
  price: d(p),
  change24hPercent: pct == null ? null : d(pct),
  updatedAt: t0,
);

PortfolioSummary run({
  List<Account>? accounts,
  List<Holding> holdings = const [],
  Map<String, Price> prices = const {},
  bool hideSmall = false,
  String threshold = '1',
  Set<String> hidden = const {},
}) => PortfolioCalculator.summarize(
  accounts: accounts ?? [wallet('w1'), exch('e1')],
  holdings: holdings,
  prices: prices,
  hideSmall: hideSmall,
  smallThreshold: d(threshold),
  hiddenTokens: hidden,
);

void main() {
  group('summarize 基础', () {
    test('空输入_全零摘要', () {
      final s = run(accounts: const []);
      expect(s.total, Decimal.zero);
      expect(s.change24h, isNull);
      expect(s.change24hPercent, isNull);
      expect(s.unpricedCount, 0);
      expect(s.hiddenSmallCount, 0);
      expect(s.byAsset, isEmpty);
      expect(s.byAccount, isEmpty);
      expect(s.onChainTotal, Decimal.zero);
      expect(s.exchangeTotal, Decimal.zero);
    });

    test('有账户无持仓_账户以零值列出', () {
      final s = run();
      expect(s.total, Decimal.zero);
      expect(s.byAccount.map((a) => a.accountId), ['e1', 'w1']);
      expect(s.byAccount.every((a) => a.value == Decimal.zero), isTrue);
    });

    test('估值_数量乘价格', () {
      final s = run(
        holdings: [onChain('w1', 'ethereum', '2.5', assetId: 'ETH')],
        prices: {'ETH': price('ETH', '2000.5')},
      );
      expect(s.total, d('5001.25'));
      expect(s.byAsset.single.value, d('5001.25'));
      expect(s.byAsset.single.amount, d('2.5'));
    });

    test('多链同币_合并数量与估值', () {
      const eth = ContractToken('ethereum', '0xusdt');
      const bsc = ContractToken('bsc', '0xusdt2');
      final s = run(
        holdings: [
          onChain('w1', 'ethereum', '100', assetId: 'USDT', token: eth),
          onChain('w1', 'bsc', '50.5', assetId: 'USDT', token: bsc),
          onChain('w2', 'ethereum', '10', assetId: 'USDT', token: eth),
          onExchange('e1', 'USDT', '39.5'),
        ],
        accounts: [wallet('w1'), wallet('w2'), exch('e1')],
        prices: {'USDT': price('USDT', '1')},
      );
      expect(s.byAsset, hasLength(1));
      expect(s.byAsset.single.assetId, 'USDT');
      expect(s.byAsset.single.amount, d('200'));
      expect(s.byAsset.single.value, d('200'));
      expect(s.total, d('200'));
    });

    test('displaySymbol_取第一条持仓的符号', () {
      final s = run(
        holdings: [
          onChain('w1', 'ethereum', '1', assetId: 'USDT', symbol: 'USDT'),
          onChain('w1', 'bsc', '1', assetId: 'USDT', symbol: 'USDT.e'),
        ],
        prices: {'USDT': price('USDT', '1')},
      );
      expect(s.byAsset.single.displaySymbol, 'USDT');
    });
  });

  group('summarize 无价格（R9）', () {
    test('无价格的币_不计入总额并计数', () {
      final s = run(
        holdings: [
          onChain('w1', 'ethereum', '1', assetId: 'ETH'),
          onChain('w1', 'bsc', '5', assetId: 'FOO'),
        ],
        prices: {'ETH': price('ETH', '100')},
      );
      expect(s.total, d('100'));
      expect(s.unpricedCount, 1);
      expect(s.byAsset.map((a) => a.assetId), ['ETH']);
      expect(s.byAccount.first.value, d('100'));
    });

    test('同一无价格币种多笔_只计一个', () {
      final s = run(
        holdings: [
          onChain('w1', 'ethereum', '1', assetId: 'FOO'),
          onChain('w1', 'bsc', '2', assetId: 'FOO'),
          onExchange('e1', 'FOO', '3'),
        ],
      );
      expect(s.unpricedCount, 1);
      expect(s.total, Decimal.zero);
    });

    test('assetId为空的未识别代币_以tokenKey区分计数', () {
      final s = run(
        holdings: [
          onChain(
            'w1',
            'ethereum',
            '1',
            token: const ContractToken('ethereum', '0xa'),
          ),
          onChain(
            'w1',
            'ethereum',
            '1',
            token: const ContractToken('ethereum', '0xa'),
            address: 'addr2',
          ),
          onChain(
            'w2',
            'ethereum',
            '1',
            token: const ContractToken('ethereum', '0xb'),
          ),
        ],
        accounts: [wallet('w1'), wallet('w2')],
      );
      expect(s.unpricedCount, 2);
      expect(s.byAsset, isEmpty);
      expect(s.total, Decimal.zero);
    });

    test('assetId为空_即使prices里有同名键也不估值', () {
      final s = run(
        holdings: [onChain('w1', 'ethereum', '1')],
        prices: {'?': price('?', '9')},
      );
      expect(s.total, Decimal.zero);
      expect(s.unpricedCount, 1);
    });

    test('assetId与tokenKey同名_不会被误合并', () {
      final s = run(
        holdings: [
          onChain('w1', 'ethereum', '1', assetId: 'ethereum:native'),
          onChain('w1', 'ethereum', '1'),
        ],
      );
      expect(s.unpricedCount, 2);
    });

    test('被手动隐藏的无价格币_不计入未估值数', () {
      final s = run(
        holdings: [
          onChain(
            'w1',
            'ethereum',
            '1',
            token: const ContractToken('ethereum', '0xspam'),
          ),
        ],
        hidden: {'ethereum:0xspam'},
      );
      expect(s.unpricedCount, 0);
    });
  });

  group('summarize 隐藏（R10、R11）', () {
    final holdings = [
      onChain('w1', 'ethereum', '1', assetId: 'ETH'),
      onChain('w1', 'bsc', '5', assetId: 'DUST'),
      onChain('w1', 'ethereum', '0.4', assetId: 'DUST'),
      onChain('w1', 'base', '1', assetId: 'TINY'),
    ];
    final prices = {
      'ETH': price('ETH', '100'),
      'DUST': price('DUST', '0.1'),
      'TINY': price('TINY', '0.5'),
    };

    test('小额隐藏关_全部列出', () {
      final s = run(holdings: holdings, prices: prices);
      expect(s.byAsset.map((a) => a.assetId), ['ETH', 'DUST', 'TINY']);
      expect(s.hiddenSmallCount, 0);
    });

    test('小额隐藏开_合并后低于阈值的币种被隐藏且仍计入总额', () {
      final s = run(holdings: holdings, prices: prices, hideSmall: true);
      // DUST 合并后 5.4 × 0.1 = 0.54 < 1；TINY 0.5 < 1。
      expect(s.byAsset.map((a) => a.assetId), ['ETH']);
      expect(s.hiddenSmallCount, 2);
      expect(s.total, d('101.04'));
      expect(s.byAccount.first.value, d('101.04'));
    });

    test('小额隐藏_合并前各自低于阈值但合并后达标_不隐藏', () {
      final s = run(
        holdings: [
          onChain('w1', 'ethereum', '0.6', assetId: 'X'),
          onChain('w1', 'bsc', '0.6', assetId: 'X'),
        ],
        prices: {'X': price('X', '1')},
        hideSmall: true,
      );
      expect(s.byAsset.single.value, d('1.2'));
      expect(s.hiddenSmallCount, 0);
    });

    test('小额隐藏_恰好等于阈值不隐藏', () {
      final s = run(
        holdings: [onChain('w1', 'ethereum', '1', assetId: 'X')],
        prices: {'X': price('X', '1')},
        hideSmall: true,
      );
      expect(s.byAsset, hasLength(1));
      expect(s.hiddenSmallCount, 0);
    });

    test('小额隐藏_阈值按调用方折算的计价货币', () {
      // 1 USD = 7.2 CNY：估值 5 CNY 低于阈值被隐藏，10 CNY 保留。
      final s = run(
        holdings: [
          onChain('w1', 'ethereum', '5', assetId: 'A'),
          onChain('w1', 'bsc', '10', assetId: 'B'),
        ],
        prices: {'A': price('A', '1'), 'B': price('B', '1')},
        hideSmall: true,
        threshold: '7.2',
      );
      expect(s.byAsset.map((a) => a.assetId), ['B']);
      expect(s.hiddenSmallCount, 1);
    });

    test('小额隐藏_无价格的币不算小额', () {
      final s = run(
        holdings: [onChain('w1', 'ethereum', '1', assetId: 'NOPRICE')],
        hideSmall: true,
      );
      expect(s.hiddenSmallCount, 0);
      expect(s.unpricedCount, 1);
    });

    test('手动隐藏_完全排除_不计总额切片与计数', () {
      final s = run(
        holdings: [
          onChain('w1', 'ethereum', '1', assetId: 'ETH'),
          onChain(
            'w1',
            'ethereum',
            '1000',
            assetId: 'SCAM',
            token: const ContractToken('ethereum', '0xscam'),
          ),
          onChain('w1', 'base', '0.001', assetId: 'DUST'),
        ],
        prices: {
          'ETH': price('ETH', '100'),
          'SCAM': price('SCAM', '5'),
          'DUST': price('DUST', '1'),
        },
        hideSmall: true,
        hidden: {'ethereum:0xscam', 'base:native'},
      );
      expect(s.total, d('100'));
      expect(s.byAsset.map((a) => a.assetId), ['ETH']);
      expect(s.hiddenSmallCount, 0);
      expect(s.unpricedCount, 0);
    });

    test('手动隐藏_只排除该tokenKey_同币种其他代币保留', () {
      final s = run(
        holdings: [
          onChain(
            'w1',
            'ethereum',
            '10',
            assetId: 'USDT',
            token: const ContractToken('ethereum', '0xa'),
          ),
          onChain(
            'w1',
            'bsc',
            '5',
            assetId: 'USDT',
            token: const ContractToken('bsc', '0xb'),
          ),
        ],
        prices: {'USDT': price('USDT', '1')},
        hidden: {'ethereum:0xa'},
      );
      expect(s.byAsset.single.amount, d('5'));
      expect(s.total, d('5'));
    });
  });

  group('summarize 汇总一致性', () {
    final accounts = [wallet('w1', 'B钱包'), wallet('w2', 'A钱包'), exch('e1')];
    final holdings = [
      onChain('w1', 'ethereum', '1', assetId: 'ETH'),
      onChain('w2', 'ethereum', '2', assetId: 'ETH'),
      onExchange('e1', 'ETH', '3'),
      onExchange('e1', 'BTC', '0.1', sub: ExchangeSubAccount.funding),
      onChain('w1', 'ethereum', '7', assetId: 'FOO'),
    ];
    final prices = {'ETH': price('ETH', '2000'), 'BTC': price('BTC', '60000')};

    test('按账户之和等于总额', () {
      final s = run(accounts: accounts, holdings: holdings, prices: prices);
      final sum = s.byAccount.fold(Decimal.zero, (a, e) => a + e.value);
      expect(s.total, d('18000'));
      expect(sum, s.total);
    });

    test('链上加交易所等于总额', () {
      final s = run(accounts: accounts, holdings: holdings, prices: prices);
      expect(s.onChainTotal, d('6000'));
      expect(s.exchangeTotal, d('12000'));
      expect(s.onChainTotal + s.exchangeTotal, s.total);
    });

    test('byAsset之和等于总额', () {
      final s = run(accounts: accounts, holdings: holdings, prices: prices);
      final sum = s.byAsset.fold(Decimal.zero, (a, e) => a + e.value);
      expect(sum, s.total);
    });

    test('账户不在列表中的持仓_整体忽略', () {
      final s = run(
        accounts: [wallet('w1')],
        holdings: [
          onChain('w1', 'ethereum', '1', assetId: 'ETH'),
          onChain('ghost', 'ethereum', '5', assetId: 'ETH'),
          onChain('ghost', 'ethereum', '5', assetId: 'FOO'),
        ],
        prices: {'ETH': price('ETH', '100')},
      );
      expect(s.total, d('100'));
      expect(s.byAccount.single.value, d('100'));
      expect(s.byAsset.single.amount, d('1'));
      expect(s.unpricedCount, 0);
    });

    test('byAccount_含零值账户_估值降序_相同按名称升序', () {
      final s = run(
        accounts: [
          wallet('w1', 'B钱包'),
          wallet('w2', 'A钱包'),
          wallet('w3', 'C钱包'),
          wallet('w4', 'Z钱包'),
        ],
        holdings: [
          onChain('w1', 'ethereum', '1', assetId: 'ETH'),
          onChain('w2', 'ethereum', '1', assetId: 'ETH'),
          onChain('w3', 'ethereum', '2', assetId: 'ETH'),
        ],
        prices: {'ETH': price('ETH', '100')},
      );
      expect(s.byAccount.map((a) => a.accountId), ['w3', 'w2', 'w1', 'w4']);
      expect(s.byAccount.last.value, Decimal.zero);
    });

    test('byAccount_名称也相同_按id升序', () {
      final s = run(accounts: [wallet('b', '同名'), wallet('a', '同名')]);
      expect(s.byAccount.map((a) => a.accountId), ['a', 'b']);
    });

    test('byAsset_估值降序_相同按assetId升序_与输入顺序无关', () {
      final hs = [
        onChain('w1', 'ethereum', '1', assetId: 'ZZZ'),
        onChain('w1', 'ethereum', '1', assetId: 'AAA'),
        onChain('w1', 'ethereum', '1', assetId: 'MMM'),
        onChain('w1', 'ethereum', '9', assetId: 'BIG'),
      ];
      final ps = {
        for (final id in ['ZZZ', 'AAA', 'MMM']) id: price(id, '5'),
        'BIG': price('BIG', '5'),
      };
      final a = run(holdings: hs, prices: ps);
      final b = run(holdings: hs.reversed.toList(), prices: ps);
      expect(a.byAsset.map((e) => e.assetId), ['BIG', 'AAA', 'MMM', 'ZZZ']);
      expect(b.byAsset.map((e) => e.assetId), ['BIG', 'AAA', 'MMM', 'ZZZ']);
    });

    test('极小数量与极大数量_不丢精度', () {
      final s = run(
        holdings: [
          onChain('w1', 'ethereum', '0.000000000000000001', assetId: 'WEI'),
          onChain(
            'w1',
            'ethereum',
            '123456789012345678901234567890',
            assetId: 'HUGE',
          ),
        ],
        prices: {
          'WEI': price('WEI', '3000.123456789'),
          'HUGE': price('HUGE', '0.000000000001'),
        },
      );
      expect(
        s.byAsset.firstWhere((e) => e.assetId == 'WEI').value,
        d('0.000000000000003000123456789'),
      );
      expect(
        s.byAsset.firstWhere((e) => e.assetId == 'HUGE').value,
        d('123456789012345678.901234567890'),
      );
      expect(s.total, d('123456789012345678.901234567890003000123456789'));
    });

    test('零数量持仓_有价格_计入估值为零的币种', () {
      final s = run(
        holdings: [onChain('w1', 'ethereum', '0', assetId: 'ETH')],
        prices: {'ETH': price('ETH', '100')},
      );
      expect(s.byAsset.single.value, Decimal.zero);
      expect(s.unpricedCount, 0);
    });
  });

  group('summarize 24 小时变化', () {
    test('全部有百分比_按前价反推', () {
      // A：100 现值，+25% → 前值 80；B：200 现值，-50% → 前值 400。
      final s = run(
        holdings: [
          onChain('w1', 'ethereum', '1', assetId: 'A'),
          onChain('w1', 'bsc', '2', assetId: 'B'),
        ],
        prices: {
          'A': price('A', '100', pct: '25'),
          'B': price('B', '100', pct: '-50'),
        },
      );
      // 现值 300，前值 480，变化 -180，-37.5%。
      expect(s.change24h, d('-180'));
      expect(s.change24hPercent, d('-37.5'));
    });

    test('部分缺百分比_缺的按无变化计入', () {
      final s = run(
        holdings: [
          onChain('w1', 'ethereum', '1', assetId: 'A'),
          onChain('w1', 'bsc', '1', assetId: 'B'),
        ],
        prices: {
          'A': price('A', '110', pct: '10'),
          'B': price('B', '100'),
        },
      );
      // A 前值 100，B 前值 100；现值 210，前值 200。
      expect(s.change24h, d('10'));
      expect(s.change24hPercent, d('5'));
    });

    test('全部缺百分比_两个字段为null', () {
      final s = run(
        holdings: [onChain('w1', 'ethereum', '1', assetId: 'A')],
        prices: {'A': price('A', '100')},
      );
      expect(s.change24h, isNull);
      expect(s.change24hPercent, isNull);
    });

    test('百分比为负100_按无变化计入_不除以零', () {
      final s = run(
        holdings: [
          onChain('w1', 'ethereum', '1', assetId: 'A'),
          onChain('w1', 'bsc', '1', assetId: 'B'),
        ],
        prices: {
          'A': price('A', '100', pct: '-100'),
          'B': price('B', '100', pct: '100'),
        },
      );
      // A 视为无变化：前值 100；B 前值 50；现值 200，前值 150。
      expect(s.change24h, d('50'));
      expect(s.change24hPercent, d('33.333333333333333333'));
    });

    test('只有负100的持仓_视为全部缺失_返回null', () {
      final s = run(
        holdings: [onChain('w1', 'ethereum', '1', assetId: 'A')],
        prices: {'A': price('A', '100', pct: '-100')},
      );
      expect(s.change24h, isNull);
      expect(s.change24hPercent, isNull);
    });

    test('百分比低于负100_同样按无变化', () {
      final s = run(
        holdings: [onChain('w1', 'ethereum', '1', assetId: 'A')],
        prices: {'A': price('A', '100', pct: '-150')},
      );
      expect(s.change24h, isNull);
    });

    test('前值合计为零_返回null', () {
      final s = run(
        holdings: [onChain('w1', 'ethereum', '0', assetId: 'A')],
        prices: {'A': price('A', '100', pct: '10')},
      );
      expect(s.change24h, isNull);
      expect(s.change24hPercent, isNull);
    });

    test('无任何估值_为null', () {
      final s = run(holdings: [onChain('w1', 'ethereum', '1', assetId: 'A')]);
      expect(s.change24h, isNull);
    });

    test('无限小数_保留18位', () {
      final s = run(
        holdings: [onChain('w1', 'ethereum', '1', assetId: 'A')],
        prices: {'A': price('A', '100', pct: '200')},
      );
      // 前值 100/3；变化 = 100 - 100/3 = 200/3。
      expect(s.change24h, d('66.666666666666666667'));
      expect(s.change24hPercent, d('200'));
    });

    test('小额隐藏的币种仍计入24小时变化', () {
      final s = run(
        holdings: [onChain('w1', 'ethereum', '1', assetId: 'A')],
        prices: {'A': price('A', '0.5', pct: '100')},
        hideSmall: true,
      );
      expect(s.byAsset, isEmpty);
      expect(s.change24h, d('0.25'));
      expect(s.change24hPercent, d('100'));
    });
  });

  group('distributionOf', () {
    const usdtEth = ContractToken('ethereum', '0xa');
    final holdings = [
      onChain('w1', 'ethereum', '60', assetId: 'USDT', token: usdtEth),
      onChain(
        'w1',
        'ethereum',
        '15',
        assetId: 'USDT',
        token: usdtEth,
        address: 'addr1',
      ),
      onChain(
        'w1',
        'bsc',
        '5',
        assetId: 'USDT',
        token: const ContractToken('bsc', '0xb'),
      ),
      onExchange('e1', 'USDT', '20'),
      onChain('w1', 'ethereum', '1', assetId: 'ETH'),
    ];
    final prices = {'USDT': price('USDT', '1'), 'ETH': price('ETH', '2000')};

    test('按账户与位置分布_同位置合并_估值降序_占比', () {
      final r = PortfolioCalculator.distributionOf(
        assetId: 'USDT',
        holdings: holdings,
        prices: prices,
      );
      expect(r.map((e) => e.amount), [d('75'), d('20'), d('5')]);
      expect(r.map((e) => e.share), [d('75'), d('20'), d('5')]);
      expect(r.first.accountId, 'w1');
      expect(
        r.first.location,
        const OnChainLocation(chainId: 'ethereum', addressId: 'addr1'),
      );
      expect(r[1].location, const ExchangeLocation(ExchangeSubAccount.spot));
      expect(r.first.value, d('75'));
    });

    test('占比之和为100', () {
      final r = PortfolioCalculator.distributionOf(
        assetId: 'USDT',
        holdings: [
          onChain('a', 'ethereum', '1', assetId: 'USDT'),
          onChain('b', 'ethereum', '1', assetId: 'USDT'),
          onChain('c', 'ethereum', '1', assetId: 'USDT'),
        ],
        prices: prices,
      );
      final sum = r.fold(Decimal.zero, (a, e) => a + e.share);
      expect(sum, d('99.999999999999999999'));
      expect(r.map((e) => e.accountId), ['a', 'b', 'c']);
    });

    test('总估值为0_占比为0', () {
      final r = PortfolioCalculator.distributionOf(
        assetId: 'USDT',
        holdings: [onChain('w1', 'ethereum', '0', assetId: 'USDT')],
        prices: prices,
      );
      expect(r.single.share, Decimal.zero);
      expect(r.single.value, Decimal.zero);
    });

    test('币种无价格_估值为null_占比为0_按数量降序', () {
      final r = PortfolioCalculator.distributionOf(
        assetId: 'FOO',
        holdings: [
          onChain('w1', 'ethereum', '1', assetId: 'FOO'),
          onChain('w2', 'ethereum', '3', assetId: 'FOO'),
        ],
        prices: prices,
      );
      expect(r.map((e) => e.accountId), ['w2', 'w1']);
      expect(r.every((e) => e.value == null), isTrue);
      expect(r.every((e) => e.share == Decimal.zero), isTrue);
    });

    test('同账户不同位置_数量相同_排序稳定', () {
      final r = PortfolioCalculator.distributionOf(
        assetId: 'USDT',
        holdings: [
          onChain('w1', 'bsc', '1', assetId: 'USDT'),
          onChain('w1', 'ethereum', '1', assetId: 'USDT'),
        ],
        prices: prices,
      );
      final r2 = PortfolioCalculator.distributionOf(
        assetId: 'USDT',
        holdings: [
          onChain('w1', 'ethereum', '1', assetId: 'USDT'),
          onChain('w1', 'bsc', '1', assetId: 'USDT'),
        ],
        prices: prices,
      );
      expect(r, r2);
    });

    test('手动隐藏的代币_不出现在分布中', () {
      final r = PortfolioCalculator.distributionOf(
        assetId: 'USDT',
        holdings: holdings,
        prices: prices,
        hiddenTokens: {'ethereum:0xa'},
      );
      expect(r.map((e) => e.amount), [d('20'), d('5')]);
      expect(r.first.share, d('80'));
    });

    test('没有该币种的持仓_返回空', () {
      final r = PortfolioCalculator.distributionOf(
        assetId: 'NONE',
        holdings: holdings,
        prices: prices,
      );
      expect(r, isEmpty);
    });

    test('DistributionEntry_值相等', () {
      const loc = ExchangeLocation(ExchangeSubAccount.spot);
      final a = DistributionEntry(
        accountId: 'a',
        location: loc,
        amount: d('1'),
        value: d('1'),
        share: d('100'),
      );
      final b = DistributionEntry(
        accountId: 'a',
        location: loc,
        amount: d('1.0'),
        value: d('1'),
        share: d('100'),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.toString(), contains('a'));
    });
  });
}
