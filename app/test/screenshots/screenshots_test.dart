@Tags(['screenshots'])
library;

// 页面截图测试：用假数据把主要页面渲染成 PNG，供没有手机的人目视检查。
//
// 所有数据都是示例数据，地址与交易哈希均为公开的占位或众所周知的地址，
// 不包含任何真实助记词、私钥或 API Key。
//
// 仅手动运行，不进入常规检查（不同机器的字形渲染有细微差异）：
//   cd app && flutter test --update-goldens --run-skipped -t screenshots test/screenshots/
// 只比对、不更新：
//   cd app && flutter test --run-skipped -t screenshots test/screenshots/

import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/l10n/app_localizations.dart';
import 'package:onewallet/router/app_router.dart';
import 'package:onewallet/theme/ow_text_styles.dart';
import 'package:onewallet/theme/ow_theme.dart';
import 'package:ow_domain/ow_domain.dart';

import '../support/fakes.dart';

// ---------------------------------------------------------------------------
// 字体
// ---------------------------------------------------------------------------

/// 中文后备字体候选（本机或 CI 上第一个存在的会被注册为 `PingFang SC`，
/// 即 [OwFonts.fallback] 的第一个名字）。都没有时测试直接失败：
/// 中文显示为方块的截图不能提交。
const _cjkFontCandidates = <String>[
  // macOS
  '/System/Library/Fonts/PingFang.ttc',
  '/System/Library/Fonts/STHeiti Medium.ttc',
  '/System/Library/Fonts/Hiragino Sans GB.ttc',
  // Windows
  r'C:\Windows\Fonts\msyh.ttc',
  // Linux
  '/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc',
  '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
  '/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc',
];

/// Material 图标字体在 Flutter SDK 缓存里。从 PATH 上的 flutter 推出 SDK 根目录。
String? _materialIconsPath() {
  const rel = 'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  final roots = <String>[];
  final envRoot = Platform.environment['FLUTTER_ROOT'];
  if (envRoot != null) roots.add(envRoot);
  for (final dir in (Platform.environment['PATH'] ?? '').split(':')) {
    if (dir.isNotEmpty && File('$dir/flutter').existsSync()) {
      roots.add(Directory(dir).parent.path);
    }
  }
  for (final r in roots) {
    final p = '$r/$rel';
    if (File(p).existsSync()) return p;
  }
  return null;
}

Future<ByteData> _readFont(String path) async {
  final bytes = await File(path).readAsBytes();
  return ByteData.view(bytes.buffer);
}

/// 把 IBM Plex、中文后备字体、Material 图标字体注册到测试环境。
Future<void> _loadFonts() async {
  Future<void> register(String family, List<Future<ByteData>> fonts) async {
    final loader = FontLoader(family);
    for (final f in fonts) {
      loader.addFont(f);
    }
    await loader.load();
  }

  await register(OwFonts.sans, [
    _readFont('assets/fonts/IBMPlexSans-Regular.ttf'),
    _readFont('assets/fonts/IBMPlexSans-Medium.ttf'),
    _readFont('assets/fonts/IBMPlexSans-SemiBold.ttf'),
  ]);
  await register(OwFonts.mono, [
    _readFont('assets/fonts/IBMPlexMono-Regular.ttf'),
    _readFont('assets/fonts/IBMPlexMono-Medium.ttf'),
    _readFont('assets/fonts/IBMPlexMono-SemiBold.ttf'),
  ]);

  String? cjk;
  for (final p in _cjkFontCandidates) {
    if (File(p).existsSync()) {
      cjk = p;
      break;
    }
  }
  if (cjk == null) {
    // 没有中文字体时截图里的中文全是方块，这样的图不能提交。
    fail(
      '找不到中文字体，无法生成可读的截图。请安装一个中文字体，'
      '或把它的路径加入 _cjkFontCandidates。',
    );
  }
  await register(OwFonts.fallback.first, [_readFont(cjk)]);

  final icons = _materialIconsPath();
  if (icons != null) {
    await register('MaterialIcons', [_readFont(icons)]);
  }
}

// ---------------------------------------------------------------------------
// 示例数据（全部为示例）
// ---------------------------------------------------------------------------

const _evmUni = '0x1111111111111111111111111111111111111111';
const _evmMetaMask = '0x2222222222222222222222222222222222222222';
const _evmCold = '0x3333333333333333333333333333333333333333';
// 只用于"添加钱包"页面的输入演示，不在任何示例账户中。
const _evmNew = '0x4444444444444444444444444444444444444444';
// 比特币创世区块相关的公开地址；Solana 系统程序地址，均为众所周知的公开地址。
const _btcCold = '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa';
const _solSystem = '11111111111111111111111111111111';

const _usdcEth = ContractToken(
  'ethereum',
  '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
);
const _usdtEth = ContractToken(
  'ethereum',
  '0xdAC17F958D2ee523a2206206994597C13D831ec7',
);

/// 示例数据：3 个钱包账户、2 个交易所账户，其中 OKX 的同步失败。
TestRig _sampleRig() {
  final rig = TestRig();

  // 钱包一：Uni 钱包，EVM 地址，ETH（以太坊与 Base）和 USDC。
  final uni = rig.addWallet('w1', 'Uni 钱包', source: WalletSource.uniswap);
  final uniAddr = rig.addAddress('d1', uni.id, _evmUni);
  rig.addHolding(uni.id, uniAddr.id, amount: '2.4', price: '3000');
  rig.addHolding(
    uni.id,
    uniAddr.id,
    chainId: 'base',
    amount: '0.3',
    price: '3000',
  );
  rig.addHolding(
    uni.id,
    uniAddr.id,
    symbol: 'USDC',
    assetId: 'USDC',
    amount: '1250.5',
    price: '1',
    token: _usdcEth,
  );

  // 钱包二：小狐狸主号，EVM 地址，ETH 与 USDT。
  final mm = rig.addWallet('w2', '小狐狸主号', source: WalletSource.metamask);
  final mmAddr = rig.addAddress('d2', mm.id, _evmMetaMask);
  rig.addHolding(mm.id, mmAddr.id, amount: '0.8', price: '3000');
  rig.addHolding(
    mm.id,
    mmAddr.id,
    symbol: 'USDT',
    assetId: 'USDT',
    amount: '1500',
    price: '1',
    token: _usdtEth,
  );

  // 钱包三：冷钱包，比特币与 Solana 两条非 EVM 地址。
  final cold = rig.addWallet('w3', '冷钱包', source: WalletSource.other);
  final btcAddr = rig.addAddress(
    'd3',
    cold.id,
    _btcCold,
    family: ChainFamily.bitcoin,
  );
  rig.addHolding(
    cold.id,
    btcAddr.id,
    chainId: 'bitcoin',
    symbol: 'BTC',
    assetId: 'BTC',
    amount: '0.35',
    price: '65000',
    token: const NativeToken('bitcoin'),
  );
  final solAddr = rig.addAddress(
    'd4',
    cold.id,
    _solSystem,
    family: ChainFamily.solana,
  );
  rig.addHolding(
    cold.id,
    solAddr.id,
    chainId: 'solana',
    symbol: 'SOL',
    assetId: 'SOL',
    amount: '42',
    price: '150',
    token: const NativeToken('solana'),
  );
  // 冷钱包另有一个 EVM 地址，只启用以太坊链，暂无持仓（展示"无资产"的地址行）。
  rig.addAddress('d5', cold.id, _evmCold, chains: {'ethereum'});

  // 交易所账户（持仓直接写入，交易所持仓没有链上地址）。
  final binance = rig.addExchange('e1', 'Binance 主账户', ExchangeId.binance);
  _addExchangeHolding(
    rig,
    binance.id,
    ExchangeSubAccount.spot,
    const NativeToken('bitcoin'),
    'BTC',
    'BTC',
    '0.12',
    65000,
  );
  _addExchangeHolding(
    rig,
    binance.id,
    ExchangeSubAccount.spot,
    _usdtEth,
    'USDT',
    'USDT',
    '800',
    1,
  );

  final okx = rig.addExchange('e2', 'OKX 现货', ExchangeId.okx);
  _addExchangeHolding(
    rig,
    okx.id,
    ExchangeSubAccount.earn,
    const NativeToken('ethereum'),
    'ETH',
    'ETH',
    '1.0',
    3000,
  );

  // 同步记录：四个账户成功，OKX 失败（用于展示失败提醒）。
  rig.record(uni.id, at: DateTime.utc(2026, 11, 12, 11, 57));
  rig.record(mm.id, at: DateTime.utc(2026, 11, 12, 11, 56));
  rig.record(cold.id, at: DateTime.utc(2026, 11, 12, 11, 55));
  rig.record(binance.id, at: DateTime.utc(2026, 11, 12, 11, 57));
  rig.record(
    okx.id,
    success: false,
    failureType: 'ServiceDownFailure',
    at: DateTime.utc(2026, 11, 12, 11, 58),
  );
  return rig;
}

/// 交易所持仓（示例）。写入后价格沿用钱包持仓已写入的价格。
void _addExchangeHolding(
  TestRig rig,
  String accountId,
  ExchangeSubAccount sub,
  TokenRef token,
  String symbol,
  String assetId,
  String amount,
  num price,
) {
  rig.holdings.feed.value = [
    ...rig.holdings.feed.value,
    Holding(
      accountId: accountId,
      location: ExchangeLocation(sub),
      token: token,
      assetId: assetId,
      displaySymbol: symbol,
      amount: Decimal.parse(amount),
      updatedAt: DateTime.utc(2026, 11, 12, 11, 57),
    ),
  ];
  rig.prices.feed.value = {
    ...rig.prices.feed.value,
    assetId: Price(
      assetId: assetId,
      quote: Quote.usd,
      price: Decimal.parse('$price'),
      updatedAt: DateTime.utc(2026, 11, 12, 11, 57),
    ),
  };
}

// ---------------------------------------------------------------------------
// 渲染
// ---------------------------------------------------------------------------

/// 与 `pumpApp` 相同的渲染方式，但可指定亮暗主题、像素比。
Future<void> _pumpShot(
  WidgetTester tester,
  TestRig rig, {
  required String location,
  required Size logicalSize,
  required double dpr,
  required Brightness brightness,
}) async {
  tester.view.physicalSize = Size(
    logicalSize.width * dpr,
    logicalSize.height * dpr,
  );
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
  final router = buildAppRouter(initialLocation: location);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: rig.overrides,
      child: MaterialApp.router(
        // 截图里不要调试角标。
        debugShowCheckedModeBanner: false,
        theme: buildOwTheme(brightness),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 一个画面的定义。
final class _Shot {
  const _Shot(
    this.name,
    this.location, {
    this.seeded = true,
    this.after,
    this.logicalSize = const Size(390, 844),
    this.dpr = 2,
    this.brightnesses = const [Brightness.light, Brightness.dark],
  });

  final String name;
  final String location;

  /// 为假会使用空的 [TestRig]（没有账户）。
  final bool seeded;

  /// 进入页面后的操作（点击、输入等）。
  final Future<void> Function(WidgetTester tester)? after;
  final Size logicalSize;
  final double dpr;
  final List<Brightness> brightnesses;
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).first);
  await tester.pumpAndSettle();
}

final _shots = <_Shot>[
  const _Shot('overview', '/overview'),
  _Shot('overview_by_account', '/overview', after: (t) => _tapText(t, '按账户')),
  const _Shot('overview_empty', '/overview', seeded: false),
  const _Shot('accounts', '/accounts'), // P03
  const _Shot('wallet_detail_assets', '/accounts/wallet/w1'),
  _Shot(
    'wallet_detail_addresses',
    '/accounts/wallet/w1',
    after: (t) => _tapText(t, '地址'),
  ),
  const _Shot('add_account', '/accounts/add'),
  _Shot(
    'add_wallet',
    '/accounts/add/wallet',
    after: (t) async {
      // 用一个尚未添加过的新地址，避免出现"地址已在其他账户中"的错误。
      await t.enterText(find.byType(TextField).at(1), _evmNew);
      await t.pumpAndSettle();
    },
  ),
  const _Shot('data_sources', '/settings/sources'),
  const _Shot('settings', '/settings'),
  // 宽屏：列表与详情并排（1280×900，像素比 1）。
  const _Shot(
    'accounts_wide',
    '/accounts/wallet/w1',
    logicalSize: Size(1280, 900),
    dpr: 1,
    brightnesses: [Brightness.light],
  ),
];

void main() {
  setUpAll(_loadFonts);

  for (final shot in _shots) {
    for (final brightness in shot.brightnesses) {
      final suffix = brightness == Brightness.light ? 'light' : 'dark';
      final fileName = '${shot.name}_$suffix';
      testWidgets(fileName, (tester) async {
        final rig = shot.seeded ? _sampleRig() : TestRig();
        await _pumpShot(
          tester,
          rig,
          location: shot.location,
          logicalSize: shot.logicalSize,
          dpr: shot.dpr,
          brightness: brightness,
        );
        await shot.after?.call(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/$fileName.png'),
        );
      });
    }
  }
}
